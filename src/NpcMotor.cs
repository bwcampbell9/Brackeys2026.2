using System;
using Godot;

public partial class NpcMotor : Node
{
    private const float WaypointDistance = 6.0f;
    private const int WorkstationApproachSampleCount = 8;
    private const float MaximumApproachProjectionDistance = 24.0f;

    private CharacterBody2D _actor = null!;
    private NavigationAgent2D _navigationAgent = null!;
    private BodyPusher _bodyPusher = null!;
    private PickupCarrier? _facingCarrier;
    private Vector2 _targetPosition;
    private bool _isMoving;

    [Export]
    public NodePath NavigationAgentPath { get; set; } =
        new("../NavigationAgent2D");

    [Export]
    public NodePath BodyPusherPath { get; set; } =
        new("../BodyPusher");

    [Export]
    public NodePath FacingCarrierPath { get; set; } = new();

    [Export(PropertyHint.Range, "10,500,1,or_greater")]
    public float Speed { get; set; } = 110.0f;

    [Export(PropertyHint.Range, "1,100,1,or_greater")]
    public float ArrivalDistance { get; set; } = 18.0f;

    public bool IsAtTarget => !_isMoving;

    public Vector2 TargetPosition => _targetPosition;

    public override void _Ready()
    {
        _actor =
            GetParentOrNull<CharacterBody2D>()
            ?? throw new InvalidOperationException(
                "NpcMotor must be a child of CharacterBody2D."
            );
        _navigationAgent =
            GetNodeOrNull<NavigationAgent2D>(NavigationAgentPath)
            ?? throw new InvalidOperationException(
                "NpcMotor requires a NavigationAgent2D."
            );
        _bodyPusher =
            GetNodeOrNull<BodyPusher>(BodyPusherPath)
            ?? throw new InvalidOperationException(
                "NpcMotor requires a BodyPusher."
            );
        if (!string.IsNullOrEmpty(FacingCarrierPath.ToString()))
        {
            _facingCarrier =
                GetNodeOrNull<PickupCarrier>(FacingCarrierPath)
                ?? throw new InvalidOperationException(
                    "NpcMotor requires the configured PickupCarrier."
                );
        }
        _navigationAgent.PathDesiredDistance = WaypointDistance;
        _navigationAgent.TargetDesiredDistance = ArrivalDistance;
    }

    public override void _PhysicsProcess(double delta)
    {
        if (
            !_isMoving
            || _actor.GlobalPosition.DistanceTo(_targetPosition)
                <= ArrivalDistance
        )
        {
            Stop();
            _bodyPusher.MoveAndPush(
                _actor,
                Vector2.Zero,
                delta
            );
            return;
        }

        Vector2 nextPosition = _navigationAgent.IsNavigationFinished()
            ? _targetPosition
            : _navigationAgent.GetNextPathPosition();
        Vector2 direction = _actor.GlobalPosition.DirectionTo(nextPosition);
        if (direction.IsZeroApprox())
        {
            direction = _actor.GlobalPosition.DirectionTo(_targetPosition);
        }

        Vector2 requestedVelocity = direction * Speed;
        if (!direction.IsZeroApprox() && _facingCarrier is not null)
        {
            _facingCarrier.FacingDirection = direction;
        }
        _bodyPusher.MoveAndPush(
            _actor,
            requestedVelocity,
            delta
        );

        if (
            _actor.GlobalPosition.DistanceTo(_targetPosition)
            <= ArrivalDistance
        )
        {
            Stop();
        }
    }

    public void SetTarget(Vector2 targetPosition)
    {
        if (
            _targetPosition.DistanceSquaredTo(targetPosition) < 16.0f
            && (
                _isMoving
                || _actor.GlobalPosition.DistanceTo(targetPosition)
                    <= ArrivalDistance
            )
        )
        {
            return;
        }

        _targetPosition = targetPosition;
        _navigationAgent.TargetPosition = targetPosition;
        _isMoving = true;
    }

    public bool TrySetNavigableTarget(Vector2 preferredPosition)
    {
        if (
            !TryGetReachablePoint(
                preferredPosition,
                float.PositiveInfinity,
                out Vector2 targetPosition,
                out _
            )
        )
        {
            return false;
        }

        SetTarget(targetPosition);
        return true;
    }

    public bool TrySetApproachTarget(
        Node2D targetNode,
        Vector2 preferredPosition
    )
    {
        StaticBody2D? workstation = FindStaticBodyAncestor(targetNode);
        if (workstation is null)
        {
            if (
                !TryGetReachablePoint(
                    preferredPosition,
                    MaximumApproachProjectionDistance,
                    out Vector2 targetPosition,
                    out _
                )
            )
            {
                return false;
            }

            SetTarget(targetPosition);
            return true;
        }

        Vector2 center = workstation.GlobalPosition;
        Vector2 preferredDirection = center.DirectionTo(preferredPosition);
        if (preferredDirection.IsZeroApprox())
        {
            preferredDirection = Vector2.Down;
        }
        float approachRadius = Mathf.Max(
            center.DistanceTo(preferredPosition),
            ArrivalDistance * 2.0f
        );
        float bestPathLength = float.PositiveInfinity;
        Vector2 bestTarget = default;
        bool foundTarget = false;
        for (int index = 0; index < WorkstationApproachSampleCount; index++)
        {
            Vector2 candidate =
                center
                + preferredDirection.Rotated(
                    Mathf.Tau * index / WorkstationApproachSampleCount
                ) * approachRadius;
            if (
                !TryGetReachablePoint(
                    candidate,
                    MaximumApproachProjectionDistance,
                    out Vector2 navigableCandidate,
                    out float pathLength
                )
                || pathLength >= bestPathLength
            )
            {
                continue;
            }

            foundTarget = true;
            bestTarget = navigableCandidate;
            bestPathLength = pathLength;
        }

        if (!foundTarget)
        {
            return false;
        }

        SetTarget(bestTarget);
        return true;
    }

    public void Stop()
    {
        _isMoving = false;
        if (GodotObject.IsInstanceValid(_actor))
        {
            _actor.Velocity = Vector2.Zero;
        }
    }

    private bool TryGetReachablePoint(
        Vector2 preferredPosition,
        float maximumProjectionDistance,
        out Vector2 targetPosition,
        out float pathLength
    )
    {
        targetPosition = default;
        pathLength = float.PositiveInfinity;
        Rid navigationMap = _navigationAgent.GetNavigationMap();
        if (NavigationServer2D.MapGetIterationId(navigationMap) == 0)
        {
            return false;
        }

        Vector2 navigableOrigin = NavigationServer2D.MapGetClosestPoint(
            navigationMap,
            _actor.GlobalPosition
        );
        Vector2 navigableTarget = NavigationServer2D.MapGetClosestPoint(
            navigationMap,
            preferredPosition
        );
        if (
            preferredPosition.DistanceTo(navigableTarget)
            > maximumProjectionDistance
        )
        {
            return false;
        }

        Vector2[] path = NavigationServer2D.MapGetPath(
            navigationMap,
            navigableOrigin,
            navigableTarget,
            true,
            _navigationAgent.NavigationLayers
        );
        if (
            path.Length == 0
            && navigableOrigin.DistanceTo(navigableTarget) > ArrivalDistance
        )
        {
            return false;
        }

        pathLength = navigableOrigin.DistanceTo(
            path.Length > 0 ? path[0] : navigableTarget
        );
        for (int index = 1; index < path.Length; index++)
        {
            pathLength += path[index - 1].DistanceTo(path[index]);
        }
        targetPosition = navigableTarget;
        return true;
    }

    private static StaticBody2D? FindStaticBodyAncestor(Node node)
    {
        Node? current = node;
        while (current is not null)
        {
            if (current is StaticBody2D staticBody)
            {
                return staticBody;
            }
            current = current.GetParent();
        }
        return null;
    }
}
