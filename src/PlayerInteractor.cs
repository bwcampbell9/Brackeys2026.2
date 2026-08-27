using System;
using System.Collections.Generic;
using Godot;
using Godot.Collections;

public partial class PlayerInteractor : Node2D
{
    private Area2D _interactionArea = null!;
    private Area2D _closeInteractionArea = null!;
    private Vector2 _facingDirection = Vector2.Up;
    private InteractionTarget? _activeTarget;
    private InteractionAction? _activeAction;
    private InteractionContext _activeContext;

    [Export(PropertyHint.Range, "1,360,1,degrees")]
    public float InteractionConeDegrees { get; set; } = 140.0f;

    [Export(PropertyHint.Range, "0,200,1,or_greater")]
    public float TargetFocusDistance { get; set; } = 48.0f;

    [Export]
    public bool UseTargetPriority { get; set; }

    public Vector2 FacingDirection
    {
        get => _facingDirection;
        set
        {
            if (!value.IsZeroApprox())
            {
                _facingDirection = value.Normalized();
            }
        }
    }

    public bool HasActiveInteraction =>
        GodotObject.IsInstanceValid(_activeTarget)
        && GodotObject.IsInstanceValid(_activeAction);

    public override void _Ready()
    {
        _interactionArea = GetNode<Area2D>("InteractionArea");
        _closeInteractionArea = GetNode<Area2D>("CloseInteractionArea");

        CollisionShape2D interactionCollision =
            _interactionArea.GetNode<CollisionShape2D>("CollisionShape2D");
        if (interactionCollision.Shape is null)
        {
            throw new InvalidOperationException(
                "InteractionArea requires a collision shape."
            );
        }
    }

    public bool TryExecute(
        Array<StringName> actionIds,
        InteractionContext context
    )
    {
        if (HasActiveInteraction)
        {
            return false;
        }

        InteractionAction? action = FindBestAction(
            actionIds,
            InteractionInputTrigger.Tap,
            context,
            out _
        );
        return action is not null && action.Execute(context);
    }

    public bool TryBegin(
        Array<StringName> actionIds,
        InteractionContext context
    )
    {
        if (HasActiveInteraction)
        {
            return false;
        }

        InteractionAction? action = FindBestAction(
            actionIds,
            InteractionInputTrigger.Hold,
            context,
            out InteractionTarget? target
        );
        if (action is null || target is null || !action.Begin(context))
        {
            return false;
        }

        _activeTarget = target;
        _activeAction = action;
        _activeContext = context;
        return true;
    }

    public bool HasTargetWithAction(
        Array<StringName> actionIds,
        InteractionInputTrigger trigger,
        InteractionContext context
    )
    {
        foreach (InteractionTarget target in GetTargetsInRange())
        {
            if (
                target.TargetOwner == context.Carrier.HeldItem
                || !IsTargetSelectable(target)
            )
            {
                continue;
            }

            foreach (StringName actionId in actionIds)
            {
                if (target.HasAction(actionId, trigger))
                {
                    return true;
                }
            }
        }

        return false;
    }

    public void UpdateActiveInteraction(double delta)
    {
        if (
            !HasActiveInteraction
            || _activeTarget is null
            || _activeAction is null
        )
        {
            ClearActiveInteraction();
            return;
        }

        if (
            !IsTargetInRange(_activeTarget)
            || !_activeAction.IsAvailable(_activeContext)
        )
        {
            CancelActiveInteraction();
            return;
        }

        InteractionRunState state = _activeAction.UpdateInteraction(
            _activeContext,
            delta
        );
        if (state == InteractionRunState.Running)
        {
            return;
        }

        if (state == InteractionRunState.Failed)
        {
            _activeAction.Cancel(_activeContext);
        }

        ClearActiveInteraction();
    }

    public void CancelActiveInteraction()
    {
        if (HasActiveInteraction && _activeAction is not null)
        {
            _activeAction.Cancel(_activeContext);
        }

        ClearActiveInteraction();
    }

    public void CompleteActiveInteraction()
    {
        if (HasActiveInteraction && _activeAction is not null)
        {
            _activeAction.Complete(_activeContext);
        }

        ClearActiveInteraction();
    }

    private InteractionAction? FindBestAction(
        Array<StringName> actionIds,
        InteractionInputTrigger trigger,
        InteractionContext context,
        out InteractionTarget? bestTarget
    )
    {
        foreach (StringName actionId in actionIds)
        {
            InteractionAction? action = FindBestAction(
                actionId,
                trigger,
                context,
                out bestTarget
            );
            if (action is not null)
            {
                return action;
            }
        }

        bestTarget = null;
        return null;
    }

    private InteractionAction? FindBestAction(
        StringName actionId,
        InteractionInputTrigger trigger,
        InteractionContext context,
        out InteractionTarget? bestTarget
    )
    {
        float minimumAlignment = Mathf.Cos(
            Mathf.DegToRad(InteractionConeDegrees * 0.5f)
        );
        Vector2 focusPosition =
            GlobalPosition + _facingDirection * TargetFocusDistance;
        int bestPriority = int.MinValue;
        float bestFocusDistanceSquared = float.PositiveInfinity;
        float bestDistanceSquared = float.PositiveInfinity;
        InteractionAction? bestAction = null;
        bestTarget = null;

        foreach (InteractionTarget target in GetTargetsInRange())
        {
            InteractionAction? action = target.FindAction(
                actionId,
                trigger,
                context
            );
            if (action is null)
            {
                continue;
            }

            if (!IsTargetSelectable(target, minimumAlignment))
            {
                continue;
            }

            float distanceSquared = target.GlobalPosition.DistanceSquaredTo(
                GlobalPosition
            );
            int priority = UseTargetPriority ? target.Priority : 0;
            float focusDistanceSquared = target.GlobalPosition.DistanceSquaredTo(
                focusPosition
            );
            bool focusDistancesMatch = Mathf.IsEqualApprox(
                focusDistanceSquared,
                bestFocusDistanceSquared
            );
            bool isBetter =
                priority > bestPriority
                || (
                    priority == bestPriority
                    && (
                        (
                            !focusDistancesMatch
                            && focusDistanceSquared < bestFocusDistanceSquared
                        )
                        || (
                            focusDistancesMatch
                            && distanceSquared < bestDistanceSquared
                        )
                    )
                );
            if (!isBetter)
            {
                continue;
            }

            bestPriority = priority;
            bestFocusDistanceSquared = focusDistanceSquared;
            bestDistanceSquared = distanceSquared;
            bestTarget = target;
            bestAction = action;
        }

        return bestAction;
    }

    private bool IsTargetSelectable(InteractionTarget target)
    {
        float minimumAlignment = Mathf.Cos(
            Mathf.DegToRad(InteractionConeDegrees * 0.5f)
        );
        return IsTargetSelectable(target, minimumAlignment);
    }

    private bool IsTargetSelectable(
        InteractionTarget target,
        float minimumAlignment
    )
    {
        if (_closeInteractionArea.OverlapsArea(target))
        {
            return true;
        }

        Vector2 offset = target.GlobalPosition - GlobalPosition;
        float distanceSquared = offset.LengthSquared();
        float alignment = distanceSquared <= Mathf.Epsilon
            ? 1.0f
            : _facingDirection.Dot(offset / Mathf.Sqrt(distanceSquared));
        return alignment >= minimumAlignment;
    }

    private HashSet<InteractionTarget> GetTargetsInRange()
    {
        HashSet<InteractionTarget> targets = new();
        AddTargets(_interactionArea, targets);
        AddTargets(_closeInteractionArea, targets);
        return targets;
    }

    private bool IsTargetInRange(InteractionTarget target)
    {
        return _interactionArea.OverlapsArea(target)
            || _closeInteractionArea.OverlapsArea(target);
    }

    private static void AddTargets(
        Area2D area,
        HashSet<InteractionTarget> targets
    )
    {
        foreach (Area2D overlappingArea in area.GetOverlappingAreas())
        {
            if (overlappingArea is InteractionTarget target)
            {
                targets.Add(target);
            }
        }
    }

    private void ClearActiveInteraction()
    {
        _activeTarget = null;
        _activeAction = null;
        _activeContext = default;
    }
}
