using System;
using Godot;

public partial class RequestWorkstationTaskAction : InteractionAction
{
    private WorkstationTaskPublisher _publisher = null!;

    public RequestWorkstationTaskAction()
    {
        ActionId = InteractionActionIds.Transfer;
        Trigger = InteractionInputTrigger.Tap;
    }

    [Export]
    public NodePath PublisherPath { get; set; } =
        new("../../WorkstationTaskPublisher");

    public override void _Ready()
    {
        _publisher =
            GetNodeOrNull<WorkstationTaskPublisher>(PublisherPath)
            ?? throw new InvalidOperationException(
                "RequestWorkstationTaskAction requires a workstation task publisher."
            );
    }

    public override bool IsAvailable(InteractionContext context)
    {
        return context.Carrier.HeldItem is null && _publisher.CanPublishNextTask;
    }

    public override bool Execute(InteractionContext context)
    {
        return IsAvailable(context) && _publisher.TryPublishNextTask();
    }
}
