using System;
using Godot;

public partial class PickupCarrier : Node2D
{
    private Area2D _pickupArea = null!;
    private Node2D _holdPoint = null!;
    private Vector2 _facingDirection = Vector2.Up;
    private PickupItem? _heldItem;

    [Export(PropertyHint.Range, "1,500,1,or_greater")]
    public float PickupRange { get; set; } = 140.0f;

    [Export(PropertyHint.Range, "1,360,1,degrees")]
    public float PickupConeDegrees { get; set; } = 140.0f;

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
        _pickupArea = GetNode<Area2D>("PickupArea");
        _holdPoint = GetNode<Node2D>("HoldPoint");

        CollisionShape2D pickupCollision = _pickupArea.GetNode<CollisionShape2D>(
            "CollisionShape2D"
        );
        CircleShape2D pickupShape = pickupCollision.Shape?.Duplicate() as CircleShape2D
            ?? throw new InvalidOperationException("PickupArea requires a CircleShape2D.");
        pickupShape.Radius = PickupRange;
        pickupCollision.Shape = pickupShape;
    }

    public bool Interact()
    {
        if (HeldItem is PickupItem heldItem)
        {
            _heldItem = null;
            heldItem.Throw(_facingDirection * ThrowForce);
            return true;
        }

        PickupItem? target = FindBestPickup();
        if (target is null || !target.TryPickUp(_holdPoint, PickupDuration))
        {
            return false;
        }

        _heldItem = target;
        return true;
    }

    private PickupItem? FindBestPickup()
    {
        float minimumAlignment = Mathf.Cos(Mathf.DegToRad(PickupConeDegrees * 0.5f));
        float bestAlignment = minimumAlignment;
        float bestDistanceSquared = float.PositiveInfinity;
        PickupItem? bestItem = null;

        foreach (Node2D body in _pickupArea.GetOverlappingBodies())
        {
            if (body is not PickupItem item || !item.IsAvailable)
            {
                continue;
            }

            Vector2 offset = item.GlobalPosition - GlobalPosition;
            float distanceSquared = offset.LengthSquared();
            float alignment = distanceSquared <= Mathf.Epsilon
                ? 1.0f
                : _facingDirection.Dot(offset / Mathf.Sqrt(distanceSquared));

            bool isBetterAligned = alignment > bestAlignment;
            bool isCloserTie = alignment == bestAlignment
                && distanceSquared < bestDistanceSquared;
            if (!isBetterAligned && !isCloserTie)
            {
                continue;
            }

            bestAlignment = alignment;
            bestDistanceSquared = distanceSquared;
            bestItem = item;
        }

        return bestItem;
    }
}
