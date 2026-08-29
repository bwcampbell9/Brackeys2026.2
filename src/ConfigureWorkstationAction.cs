using System;
using Godot;

public partial class ConfigureWorkstationAction : InteractionAction
{
    private WorkstationTaskPublisher _publisher = null!;
    private Node2D? _actor;
    private bool _actorWasPhysicsProcessing;

    public ConfigureWorkstationAction()
    {
        ActionId = InteractionActionIds.Configure;
        Trigger = InteractionInputTrigger.Hold;
    }

    [Export]
    public NodePath PublisherPath { get; set; } =
        new("../../WorkstationTaskPublisher");

    public override void _Ready()
    {
        _publisher =
            GetNodeOrNull<WorkstationTaskPublisher>(PublisherPath)
            ?? throw new InvalidOperationException(
                "ConfigureWorkstationAction requires a workstation task publisher."
            );
    }

    public override bool IsAvailable(InteractionContext context)
    {
        return context.Carrier.HeldItem is null
            && _publisher.CanConfigure;
    }

    public override bool Begin(InteractionContext context)
    {
        if (!IsAvailable(context) || !_publisher.BeginConfiguration())
        {
            return false;
        }

        _actor = context.Actor;
        _actorWasPhysicsProcessing = _actor.IsPhysicsProcessing();
        _actor.SetPhysicsProcess(false);
        if (_actor is CharacterBody2D body)
        {
            body.Velocity = Vector2.Zero;
        }
        return true;
    }

    public override InteractionRunState UpdateInteraction(
        InteractionContext context,
        double delta
    )
    {
        return _publisher.IsConfiguring
            ? InteractionRunState.Running
            : InteractionRunState.Failed;
    }

    public override void Cancel(InteractionContext context)
    {
        try
        {
            _publisher.CancelConfiguration();
        }
        finally
        {
            RestoreActorMovement();
        }
    }

    public override void Complete(InteractionContext context)
    {
        try
        {
            _publisher.CompleteConfiguration();
        }
        finally
        {
            RestoreActorMovement();
        }
    }

    public override void _ExitTree()
    {
        RestoreActorMovement();
    }

    private void RestoreActorMovement()
    {
        Node2D? actor = _actor;
        if (GodotObject.IsInstanceValid(actor))
        {
            actor.SetPhysicsProcess(_actorWasPhysicsProcessing);
        }
        _actor = null;
    }
}