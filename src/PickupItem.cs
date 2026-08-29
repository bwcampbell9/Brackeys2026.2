using System;
using Godot;

public partial class PickupItem : RigidBody2D, IItemSource
{
    private static readonly StringName IdleAnimation = "idle";

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

    public bool IsCarried =>
        _isAttached && GetParent()?.GetParent() is PickupCarrier;

    public bool IsTransferAvailable => IsAvailable || IsCarried;

    [Signal]
    public delegate void AvailabilityChangedEventHandler();

    public Node2D SourceNode => this;

    public PickupItemDefinition? AvailableDefinition => Definition;

    public bool IsSourceAvailable =>
        IsTransferAvailable && Definition is not null;

    public PickupCarrier? CurrentCarrier =>
        IsCarried ? GetParent()?.GetParent() as PickupCarrier : null;

    public bool CanReturnItem => false;

    public Vector2 ApproachPosition => GlobalPosition;

    protected virtual void OnPickedUp() { }

    protected virtual void OnAttachmentMoved() { }

    protected virtual void OnThrown() { }

    public virtual bool TrySecondaryInteract()
    {
        return false;
    }

    public override void _Ready()
    {
        _restScale = Scale;
        ApplyDefinition();
        AddToGroup(ItemSourceCatalog.ItemSourceGroup);
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
        EmitSignal(SignalName.AvailabilityChanged);
        return true;
    }

    public bool TryMoveAttachment(Node2D attachmentPoint, float duration)
    {
        if (!_isAttached)
        {
            return false;
        }

        Reparent(attachmentPoint, true);
        OnAttachmentMoved();
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
        EmitSignal(SignalName.AvailabilityChanged);
        ApplyCentralImpulse(impulse);
    }

    public bool TryAcquire(InteractionContext context)
    {
        PickupCarrier? source = CurrentCarrier;
        return source is not null
            ? source.TryTransferHeldItemTo(this, context.Carrier)
            : context.Carrier.TryHold(this);
    }

    public bool TryReturn(InteractionContext context)
    {
        return false;
    }

    private void ApplyDefinition()
    {
        if (_definition is null)
        {
            OnDefinitionApplied();
            return;
        }

        Sprite2D? staticSprite = GetNodeOrNull<Sprite2D>("Sprite2D");
        AnimatedSprite2D? animatedSprite =
            GetNodeOrNull<AnimatedSprite2D>("AnimatedSprite2D");
        if (_definition.SpriteFrames is not null && animatedSprite is null)
        {
            animatedSprite = new AnimatedSprite2D
            {
                Name = "AnimatedSprite2D",
            };
            AddChild(animatedSprite);
        }

        bool usesDefinitionAnimation = _definition.SpriteFrames is not null
            && animatedSprite is not null;
        bool usesSceneAnimation = staticSprite is null
            && animatedSprite?.SpriteFrames is not null;
        bool usesAnimation = usesDefinitionAnimation || usesSceneAnimation;
        if (staticSprite is not null)
        {
            staticSprite.Visible = !usesAnimation;
        }

        if (animatedSprite is not null)
        {
            animatedSprite.Visible = usesAnimation;
            if (usesDefinitionAnimation)
            {
                animatedSprite.SpriteFrames = _definition.SpriteFrames;
                animatedSprite.Play(IdleAnimation);
            }
            else if (!usesSceneAnimation)
            {
                animatedSprite.Stop();
            }
        }

        CanvasItem? visual = usesAnimation ? animatedSprite : staticSprite;
        if (visual is not null)
        {
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

        OnDefinitionApplied();
    }

    protected virtual void OnDefinitionApplied() { }

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
