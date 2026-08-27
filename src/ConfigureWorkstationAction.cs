using System;
using Godot;

public partial class ConfigureWorkstationAction : InteractionAction
{
    private WorkstationTaskPublisher _publisher = null!;

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
        return IsAvailable(context) && _publisher.BeginConfiguration();
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
        _publisher.CancelConfiguration();
    }

    public override void Complete(InteractionContext context)
    {
        _publisher.CompleteConfiguration();
    }
}