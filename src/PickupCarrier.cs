using Godot;

public partial class PickupCarrier : Node2D
{
    private Node2D _holdPoint = null!;
    private Vector2 _facingDirection = Vector2.Up;
    private PickupItem? _heldItem;

    [Export(PropertyHint.Range, "0.01,2,0.01,or_greater")]
    public float PickupDuration { get; set; } = 0.2f;

    [Export(PropertyHint.Range, "0,2000,1,or_greater")]
    public float ThrowForce { get; set; } = 650.0f;

    public Vector2 FacingDirection
    {
        get => _facingDirection;
        set
        {
            if (value.IsZeroApprox())
            {
                return;
            }

            _facingDirection = value.Normalized();
            Rotation = _facingDirection.Angle() + Mathf.Pi / 2.0f;
        }
    }

    public PickupItem? HeldItem => IsInstanceValid(_heldItem) ? _heldItem : null;

    public override void _Ready()
    {
        _holdPoint = GetNode<Node2D>("HoldPoint");
    }

    public bool TryHold(PickupItem item)
    {
        if (HeldItem is not null || !item.TryPickUp(_holdPoint, PickupDuration))
        {
            return false;
        }

        _heldItem = item;
        return true;
    }

    public bool TryPlace(PickupSocket socket)
    {
        PickupItem? item = HeldItem;
        if (item is null || !socket.TryStore(item, PickupDuration))
        {
            return false;
        }

        _heldItem = null;
        return true;
    }

    public bool TryTake(PickupSocket socket)
    {
        if (
            HeldItem is not null
            || !socket.TryTake(_holdPoint, PickupDuration, out PickupItem? item)
            || item is null
        )
        {
            return false;
        }

        _heldItem = item;
        return true;
    }

    public bool Throw()
    {
        PickupItem? item = HeldItem;
        if (item is null)
        {
            return false;
        }

        _heldItem = null;
        item.Throw(_facingDirection * ThrowForce);
        return true;
    }
}
