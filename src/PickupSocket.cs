using Godot;

public partial class PickupSocket : Node2D
{
    private PickupItem? _item;

    public PickupItem? Item =>
        GodotObject.IsInstanceValid(_item) ? _item : null;

    public bool TryStore(PickupItem item, float duration)
    {
        if (Item is not null)
        {
            return false;
        }

        bool attached = item.IsAvailable
            ? item.TryPickUp(this, duration)
            : item.TryMoveAttachment(this, duration);
        if (!attached)
        {
            return false;
        }

        _item = item;
        return true;
    }

    public bool TryTake(
        Node2D destination,
        float duration,
        out PickupItem? item
    )
    {
        PickupItem? current = Item;
        item = null;
        if (
            current is null
            || !current.TryMoveAttachment(destination, duration)
        )
        {
            return false;
        }

        _item = null;
        item = current;
        return true;
    }
}
