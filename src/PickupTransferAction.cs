using Godot;

public partial class PickupTransferAction : InteractionAction
{
    public PickupTransferAction()
    {
        ActionId = InteractionActionIds.Transfer;
        Trigger = InteractionInputTrigger.Tap;
    }

    public override bool IsAvailable(InteractionContext context)
    {
        return GetPickup() is { IsAvailable: true }
            && context.Carrier.HeldItem is null;
    }

    public override bool Execute(InteractionContext context)
    {
        PickupItem? item = GetPickup();
        return item is not null && context.Carrier.TryHold(item);
    }

    private PickupItem? GetPickup()
    {
        return GetInteractionTarget().TargetOwner as PickupItem;
    }
}
