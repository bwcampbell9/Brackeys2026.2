using System;
using Godot;

public partial class PickupItem : RigidBody2D
{
    private Node? _worldParent;
    private uint _worldCollisionLayer;
    private uint _worldCollisionMask;
    private bool _isHeld;

    public bool IsAvailable => !_isHeld;

    public bool TryPickUp(Node2D holdPoint)
    {
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
        Reparent(holdPoint, false);
        Position = Vector2.Zero;
        Rotation = 0.0f;
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

        Reparent(worldParent, true);
        CollisionLayer = _worldCollisionLayer;
        CollisionMask = _worldCollisionMask;
        Freeze = false;
        Sleeping = false;
        LinearVelocity = Vector2.Zero;
        AngularVelocity = 0.0f;
        _isHeld = false;
        ApplyCentralImpulse(impulse);
    }
}
