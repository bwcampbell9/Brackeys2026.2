using System;
using System.Collections.Generic;
using Godot;

public partial class PickupCarrier : Node2D
{
    private static readonly StringName ContainerInteraction = "potato_container";
    private static readonly PackedScene PickupItemScene = GD.Load<PackedScene>(
        "res://scenes/pickup_item.tscn"
    );

    private Area2D _pickupArea = null!;
    private Area2D _closePickupArea = null!;
    private Node2D _holdPoint = null!;
    private Vector2 _facingDirection = Vector2.Up;
    private PickupItem? _heldItem;
    private Tween? _shakeTween;

    [Export]
    public NodePath InteractionTileMapPath { get; set; } = new("../../RoomTiles");

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
        _closePickupArea = GetNode<Area2D>("ClosePickupArea");
        _holdPoint = GetNode<Node2D>("HoldPoint");

        CollisionShape2D pickupCollision = _pickupArea.GetNode<CollisionShape2D>(
            "CollisionShape2D"
        );
        if (pickupCollision.Shape is null)
        {
            throw new InvalidOperationException("PickupArea requires a collision shape.");
        }
    }

    public bool Interact()
    {
        if (HeldItem is PickupItem heldItem)
        {
            if (IsFacingInteractionTile(ContainerInteraction))
            {
                ShakeHeldItem(heldItem);
                return false;
            }

            _heldItem = null;
            heldItem.Throw(_facingDirection * ThrowForce);
            return true;
        }

        PickupItem? target = FindBestPickup();
        if (target is not null)
        {
            if (!target.TryPickUp(_holdPoint, PickupDuration))
            {
                return false;
            }

            _heldItem = target;
            return true;
        }

        return TryInteractWithTile();
    }

    private bool TryInteractWithTile()
    {
        if (!TryGetFacingInteractionTile(ContainerInteraction, out TileMapLayer tileMap, out Vector2I cell))
        {
            return false;
        }

        PickupItem potato = PickupItemScene.Instantiate<PickupItem>();
        tileMap.GetParent().AddChild(potato);
        potato.GlobalPosition = tileMap.ToGlobal(tileMap.MapToLocal(cell));
        if (!potato.TryPickUp(_holdPoint, PickupDuration))
        {
            potato.QueueFree();
            return false;
        }

        _heldItem = potato;
        return true;
    }

    private bool IsFacingInteractionTile(StringName interactionType)
    {
        return TryGetFacingInteractionTile(interactionType, out _, out _);
    }

    private bool TryGetFacingInteractionTile(
        StringName interactionType,
        out TileMapLayer tileMap,
        out Vector2I cell
    )
    {
        tileMap = GetNodeOrNull<TileMapLayer>(InteractionTileMapPath);
        cell = default;
        if (tileMap is null)
        {
            return false;
        }

        Vector2 tileSize = tileMap.TileSet.TileSize;
        Vector2 tilePosition = GlobalPosition
            + _facingDirection * Mathf.Max(tileSize.X, tileSize.Y);
        cell = tileMap.LocalToMap(tileMap.ToLocal(tilePosition));
        TileData? tileData = tileMap.GetCellTileData(cell);
        return tileData is not null
            && tileData.GetCustomData("interaction_type").AsString() == interactionType;
    }

    private void ShakeHeldItem(PickupItem heldItem)
    {
        _shakeTween?.Kill();
        _shakeTween = heldItem.CreateTween();
        _shakeTween.SetTrans(Tween.TransitionType.Sine);
        _shakeTween.SetEase(Tween.EaseType.InOut);
        _shakeTween.TweenProperty(heldItem, new NodePath("rotation"), 0.12f, 0.05f);
        _shakeTween.TweenProperty(heldItem, new NodePath("rotation"), -0.12f, 0.1f);
        _shakeTween.TweenProperty(heldItem, new NodePath("rotation"), 0.0f, 0.05f);
    }

    private PickupItem? FindBestPickup()
    {
        float minimumAlignment = Mathf.Cos(Mathf.DegToRad(PickupConeDegrees * 0.5f));
        float bestAlignment = float.NegativeInfinity;
        float bestDistanceSquared = float.PositiveInfinity;
        PickupItem? bestItem = null;
        HashSet<PickupItem> candidates = new();

        AddAvailablePickups(_pickupArea, candidates);
        AddAvailablePickups(_closePickupArea, candidates);

        foreach (PickupItem item in candidates)
        {
            Vector2 offset = item.GlobalPosition - GlobalPosition;
            float distanceSquared = offset.LengthSquared();
            float alignment = distanceSquared <= Mathf.Epsilon
                ? 1.0f
                : _facingDirection.Dot(offset / Mathf.Sqrt(distanceSquared));
            bool isEligible = alignment >= minimumAlignment
                || _closePickupArea.OverlapsBody(item);
            if (!isEligible)
            {
                continue;
            }

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

    private static void AddAvailablePickups(
        Area2D area,
        HashSet<PickupItem> candidates
    )
    {
        foreach (Node2D body in area.GetOverlappingBodies())
        {
            if (body is PickupItem item && item.IsAvailable)
            {
                candidates.Add(item);
            }
        }
    }
}
