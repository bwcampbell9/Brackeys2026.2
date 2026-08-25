using Godot;

public partial class PickupSocket : Node2D
{
    private PickupItem? _item;

    [Signal]
    public delegate void ItemChangedEventHandler();

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
        item.TreeExiting += OnStoredItemExiting;
        EmitSignal(SignalName.ItemChanged);
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
        )
        {
            return false;
        }

        current.TreeExiting -= OnStoredItemExiting;
        if (!current.TryMoveAttachment(destination, duration))
        {
            current.TreeExiting += OnStoredItemExiting;
            return false;
        }

        _item = null;
        item = current;
        EmitSignal(SignalName.ItemChanged);
        return true;
    }

    public PickupItem? Take(Node2D destination, float duration)
    {
        return TryTake(destination, duration, out PickupItem? item)
            ? item
            : null;
    }

    private void OnStoredItemExiting()
    {
        PickupItem? current = _item;
        if (current is not null)
        {
            current.TreeExiting -= OnStoredItemExiting;
        }

        _item = null;
        EmitSignal(SignalName.ItemChanged);
    }
}
