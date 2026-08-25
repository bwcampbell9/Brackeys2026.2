using System;
using Godot;

public partial class PickupItem : RigidBody2D
{
    private Node? _worldParent;
    private uint _worldCollisionLayer;
    private uint _worldCollisionMask;
    private bool _isAttached;
    private Tween? _pickupTween;
    private PickupItemDefinition? _definition;

    [Export]
    public PickupItemDefinition? Definition
    {
        get => _definition;
        set
        {
            _definition = value;
            if (IsInsideTree())
            {
                ApplyDefinition();
            }
        }
    }

    public bool IsAvailable => !_isAttached;

    protected virtual void OnPickedUp() { }

    protected virtual void OnThrown() { }

    public override void _Ready()
    {
        ApplyDefinition();
    }

    public bool TryPickUp(Node2D holdPoint, float duration)
    {
        if (duration < 0.0f)
        {
            throw new ArgumentOutOfRangeException(
                nameof(duration),
                duration,
                "Pickup duration cannot be negative."
            );
        }

        if (_isAttached)
        {
            return false;
        }

        _isAttached = true;
        _worldParent = GetParent();
        _worldCollisionLayer = CollisionLayer;
        _worldCollisionMask = CollisionMask;

        Freeze = true;
        LinearVelocity = Vector2.Zero;
        AngularVelocity = 0.0f;
        CollisionLayer = 0;
        CollisionMask = 0;
        Reparent(holdPoint, true);
        OnPickedUp();
        TweenToAttachment(duration);
        return true;
    }

    public bool TryMoveAttachment(Node2D attachmentPoint, float duration)
    {
        if (!_isAttached)
        {
            return false;
        }

        Reparent(attachmentPoint, true);
        TweenToAttachment(duration);
        return true;
    }

    public void SetDefinition(PickupItemDefinition definition)
    {
        Definition = definition;
    }

    private void TweenToAttachment(float duration)
    {
        _pickupTween?.Kill();
        _pickupTween = CreateTween()
            .SetParallel()
            .SetTrans(Tween.TransitionType.Quad)
            .SetEase(Tween.EaseType.Out);
        _pickupTween.TweenProperty(this, new NodePath("position"), Vector2.Zero, duration);
        _pickupTween.TweenProperty(this, new NodePath("rotation"), 0.0f, duration);
    }

    public void Throw(Vector2 impulse)
    {
        if (!_isAttached)
        {
            return;
        }

        Node? worldParent = IsInstanceValid(_worldParent)
            ? _worldParent
            : GetTree().CurrentScene;
        if (worldParent is null)
        {
            throw new InvalidOperationException("A pickup item requires a world parent when thrown.");
        }

        _pickupTween?.Kill();
        _pickupTween = null;
        Reparent(worldParent, true);
        CollisionLayer = _worldCollisionLayer;
        CollisionMask = _worldCollisionMask;
        Freeze = false;
        Sleeping = false;
        LinearVelocity = Vector2.Zero;
        AngularVelocity = 0.0f;
        _isAttached = false;
        OnThrown();
        ApplyCentralImpulse(impulse);
    }

    private void ApplyDefinition()
    {
        if (
            _definition is null
            || GetNodeOrNull<Sprite2D>("Sprite2D") is not Sprite2D sprite
        )
        {
            return;
        }

        sprite.Texture = _definition.Texture;
        sprite.Modulate = _definition.Modulate;
        sprite.Scale = _definition.VisualScale;
    }
}
