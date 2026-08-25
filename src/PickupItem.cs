using System;
using Godot;

public partial class PickupItem : RigidBody2D
{
    private Node? _worldParent;
    private uint _worldCollisionLayer;
    private uint _worldCollisionMask;
    private bool _isAttached;
    private Tween? _motionTween;
    private PickupItemDefinition? _definition;
    private Vector2 _restScale;

    [Export]
    public PickupItemDefinition? Definition
    {
        get => _definition;
        set
        {
            _definition = value;
            ApplyDefinition();
        }
    }

    public bool IsAvailable => !_isAttached;

    protected virtual void OnPickedUp() { }

    protected virtual void OnThrown() { }

    public override void _Ready()
    {
        _restScale = Scale;
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
        Tween tween = StartMotionTween()
            .SetParallel()
            .SetTrans(Tween.TransitionType.Quad)
            .SetEase(Tween.EaseType.Out);
        tween.TweenProperty(this, new NodePath("position"), Vector2.Zero, duration);
        tween.TweenProperty(this, new NodePath("rotation"), 0.0f, duration);
        tween.TweenProperty(this, new NodePath("scale"), _restScale, duration);
    }

    public Tween StartMotionTween()
    {
        _motionTween?.Kill();
        _motionTween = CreateTween();
        return _motionTween;
    }

    public void ResetAttachmentPresentation()
    {
        _motionTween?.Kill();
        _motionTween = null;
        Position = Vector2.Zero;
        Rotation = 0.0f;
        Scale = _restScale;
    }

    public void PlayShake()
    {
        Tween tween = StartMotionTween()
            .SetParallel()
            .SetTrans(Tween.TransitionType.Sine)
            .SetEase(Tween.EaseType.InOut);
        tween.TweenProperty(this, new NodePath("position"), Vector2.Zero, 0.2f);
        tween.TweenProperty(this, new NodePath("scale"), _restScale, 0.2f);
        tween.TweenMethod(
            Callable.From<float>(ApplyShakeProgress),
            0.0f,
            1.0f,
            0.2f
        );
        tween.Chain().TweenCallback(Callable.From(FinishShake));
    }

    public void AnimateReturnTo(
        Node2D target,
        float duration,
        float spinTurns
    )
    {
        if (duration < 0.0f)
        {
            throw new ArgumentOutOfRangeException(
                nameof(duration),
                duration,
                "Return duration cannot be negative."
            );
        }

        Reparent(target, true);
        Tween tween = StartMotionTween()
            .SetParallel()
            .SetTrans(Tween.TransitionType.Cubic)
            .SetEase(Tween.EaseType.In);
        tween.TweenProperty(this, new NodePath("position"), Vector2.Zero, duration);
        tween.TweenProperty(
            this,
            new NodePath("rotation"),
            Rotation + Mathf.Tau * spinTurns,
            duration
        );
        tween.TweenProperty(this, new NodePath("scale"), Vector2.Zero, duration);
        tween.Chain().TweenCallback(Callable.From(QueueFree));
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

        _motionTween?.Kill();
        _motionTween = null;
        Reparent(worldParent, true);
        Scale = _restScale;
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
        if (_definition is null)
        {
            return;
        }

        CanvasItem? visual =
            GetNodeOrNull<Sprite2D>("Sprite2D") as CanvasItem
            ?? GetNodeOrNull<AnimatedSprite2D>("AnimatedSprite2D");
        if (visual is null)
        {
            return;
        }

        visual.Material = _definition.VisualMaterial;
        visual.Modulate = _definition.Modulate;
        if (visual is Node2D visualNode)
        {
            visualNode.Scale = _definition.VisualScale;
        }

        if (
            visual is Sprite2D sprite
            && _definition.Texture is not null
        )
        {
            sprite.Texture = _definition.Texture;
        }
    }

    private void ApplyShakeProgress(float progress)
    {
        Rotation =
            Mathf.Sin(progress * Mathf.Tau * 2.0f)
            * 0.12f
            * (1.0f - progress);
    }

    private void FinishShake()
    {
        Rotation = 0.0f;
    }
}
