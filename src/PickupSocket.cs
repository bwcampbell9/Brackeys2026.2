using Godot;

public partial class PickupSocket : Node2D, IItemSource
{
    private PickupItem? _item;
    private bool _isLocked;
    private bool _isNpcSourceEnabled;

    [Signal]
    public delegate void ItemChangedEventHandler();

    [Export]
    public Vector2 NpcApproachOffset { get; set; }

    public PickupItem? Item =>
        GodotObject.IsInstanceValid(_item) ? _item : null;

    public Node2D SourceNode => this;

    public PickupItemDefinition? AvailableDefinition => Item?.Definition;

    public bool IsSourceAvailable =>
        _isNpcSourceEnabled && !_isLocked && Item is not null;

    public bool CanReturnItem => false;

    public Vector2 ApproachPosition => ToGlobal(NpcApproachOffset);

    public bool IsLocked => _isLocked;

    public override void _Ready()
    {
        AddToGroup(ItemSourceCatalog.ItemSourceGroup);
    }

    public bool TryStore(PickupItem item, float duration)
    {
        if (_isLocked || Item is not null)
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

        _isNpcSourceEnabled = false;
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
            _isLocked
            || current is null
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

        _isNpcSourceEnabled = false;
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

    public bool TryDiscard(PickupItem item)
    {
        if (Item != item)
        {
            return false;
        }

        item.TreeExiting -= OnStoredItemExiting;
        _isLocked = false;
        _isNpcSourceEnabled = false;
        _item = null;
        EmitSignal(SignalName.ItemChanged);
        item.QueueFree();
        return true;
    }

    public bool TryLock(PickupItem item)
    {
        if (_isLocked || Item != item)
        {
            return false;
        }

        _isLocked = true;
        return true;
    }

    public void SetNpcSourceEnabled(bool enabled)
    {
        _isNpcSourceEnabled = enabled && Item is not null;
    }

    public bool TryAcquire(InteractionContext context)
    {
        return IsSourceAvailable && context.Carrier.TryTake(this);
    }

    public bool TryReturn(InteractionContext context)
    {
        return false;
    }

    private void OnStoredItemExiting()
    {
        PickupItem? current = _item;
        if (current is not null)
        {
            current.TreeExiting -= OnStoredItemExiting;
        }

        _isLocked = false;
        _isNpcSourceEnabled = false;
        _item = null;
        EmitSignal(SignalName.ItemChanged);
    }
}
