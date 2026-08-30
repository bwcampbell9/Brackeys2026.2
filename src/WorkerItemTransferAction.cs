using System;
using Godot;

public partial class WorkerItemTransferAction : InteractionAction
{
    private PickupCarrier _workerCarrier = null!;

    public WorkerItemTransferAction()
    {
        ActionId = InteractionActionIds.Transfer;
        Trigger = InteractionInputTrigger.Tap;
    }

    [Export]
    public NodePath WorkerCarrierPath { get; set; } = new("../../PickupCarrier");

    public override void _Ready()
    {
        _workerCarrier = GetNodeOrNull<PickupCarrier>(WorkerCarrierPath)
            ?? throw new InvalidOperationException(
                "WorkerItemTransferAction requires a worker pickup carrier."
            );
    }

    public override bool IsAvailable(InteractionContext context)
    {
        return context.Carrier.HeldItem is null
            && _workerCarrier.HeldItem is not null;
    }

    public override bool Execute(InteractionContext context)
    {
        PickupItem? item = _workerCarrier.HeldItem;
        if (item is null)
        {
            return false;
        }

        bool transferred = _workerCarrier.TryTransferHeldItemTo(item, context.Carrier);
        if (transferred && item.Definition?.Id == "chopped_carrots")
        {
            Node root = GetTree().Root;
            TutorialLevelController? controller = root.GetNodeOrNull<TutorialLevelController>("/root/TutorialKitchen/TutorialLevelController");
            if (controller is not null)
            {
                controller.OnWrongItemTaken();
            }
            else
            {
                NpcTaskRunner? runner = GetNodeOrNull<NpcTaskRunner>("../NpcTaskRunner");
                if (runner is not null)
                {
                    runner.Personality = new NpcPersonality
                    {
                        FailureChance = 0.0f,
                    };
                }
            }
        }

        return transferred;
    }
}