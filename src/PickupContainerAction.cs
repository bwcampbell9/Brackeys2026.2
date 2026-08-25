using Godot;

public partial class PickupContainerAction : InteractionAction
{
    private Tween? _shakeTween;

    public PickupContainerAction()
    {
        ActionId = InteractionActionIds.Transfer;
        Trigger = InteractionInputTrigger.Tap;
    }

    [Export]
    public PackedScene? PickupScene { get; set; }

    [Export]
    public PickupItemDefinition? AcceptedItem { get; set; }

    public override bool IsAvailable(InteractionContext context)
    {
        return context.Carrier.HeldItem is not null || PickupScene is not null;
    }

    public override bool Execute(InteractionContext context)
    {
        if (context.Carrier.HeldItem is PickupItem heldItem)
        {
            if (
                AcceptedItem is not null
                && heldItem.Definition == AcceptedItem
            )
            {
                return context.Carrier.TryRemoveHeldItem(heldItem);
            }

            Shake(heldItem);
            return true;
        }

        if (PickupScene is null)
        {
            return false;
        }

        Node2D container = GetInteractionTarget().TargetOwner;
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

    private void Shake(PickupItem item)
    {
        _shakeTween?.Kill();
        _shakeTween = item.CreateTween();
        _shakeTween.SetTrans(Tween.TransitionType.Sine);
        _shakeTween.SetEase(Tween.EaseType.InOut);
        _shakeTween.TweenProperty(item, new NodePath("rotation"), 0.12f, 0.05f);
        _shakeTween.TweenProperty(item, new NodePath("rotation"), -0.12f, 0.1f);
        _shakeTween.TweenProperty(item, new NodePath("rotation"), 0.0f, 0.05f);
    }
}
