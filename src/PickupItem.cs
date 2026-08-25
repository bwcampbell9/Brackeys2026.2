using System;
using Godot;

public partial class PickupItem : RigidBody2D
{
    private Node? _worldParent;
    private uint _worldCollisionLayer;
    private uint _worldCollisionMask;
    private bool _isHeld;
    private Tween? _pickupTween;

    public bool IsAvailable => !_isHeld;

    protected virtual void OnPickedUp() { }

    protected virtual void OnThrown() { }

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

        if (_isHeld)
        {
            return false;
        }

        _isHeld = true;
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

        _pickupTween = CreateTween()
            .SetParallel()
            .SetTrans(Tween.TransitionType.Quad)
            .SetEase(Tween.EaseType.Out);
        _pickupTween.TweenProperty(this, new NodePath("position"), Vector2.Zero, duration);
        _pickupTween.TweenProperty(this, new NodePath("rotation"), 0.0f, duration);
        return true;
    }

    public void Throw(Vector2 impulse)
    {
        if (!_isHeld)
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
        _isHeld = false;
        OnThrown();
        ApplyCentralImpulse(impulse);
    }
}
