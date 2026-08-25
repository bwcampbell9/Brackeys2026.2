using System;
using Godot;

public partial class PickupContainerAction : InteractionAction
{
    public PickupContainerAction()
    {
        ActionId = InteractionActionIds.Transfer;
        Trigger = InteractionInputTrigger.Tap;
    }

    [Export]
    public PackedScene? PickupScene { get; set; }

    [Export]
    public PickupItemDefinition? AcceptedItem { get; set; }

    [Export(PropertyHint.Range, "0.05,2,0.01,or_greater")]
    public float ReturnDuration { get; set; } = 0.35f;

    [Export(PropertyHint.Range, "0,8,0.25,or_greater")]
    public float ReturnSpinTurns { get; set; } = 1.5f;

    public override bool IsAvailable(InteractionContext context)
    {
        return context.Carrier.HeldItem is not null || PickupScene is not null;
    }

    public override bool Execute(InteractionContext context)
    {
        Node2D container = GetInteractionTarget().TargetOwner;
        if (context.Carrier.HeldItem is PickupItem heldItem)
        {
            if (
                AcceptedItem is not null
                && heldItem.Definition == AcceptedItem
            )
            {
                if (ReturnDuration < 0.0f)
                {
                    throw new InvalidOperationException(
                        $"{Name} requires a non-negative return duration."
                    );
                }

                if (!context.Carrier.TryReleaseHeldItem(heldItem))
                {
                    return false;
                }

                heldItem.AnimateReturnTo(
                    container,
                    ReturnDuration,
                    ReturnSpinTurns
                );
                return true;
            }

            heldItem.PlayShake();
            return true;
        }

        if (PickupScene is null)
        {
            return false;
        }

        PickupItem item = PickupScene.Instantiate<PickupItem>();
        context.WorldItemRoot.AddChild(item);
        item.GlobalPosition = container.GlobalPosition;
        if (context.Carrier.TryHold(item))
        {
            return true;
        }

        item.QueueFree();
        return false;
    }
}
