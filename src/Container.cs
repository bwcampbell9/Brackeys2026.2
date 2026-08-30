using System;
using Godot;

public partial class Container : StaticBody2D
{
    private static readonly StringName IdleAnimation = new("idle");
    private static readonly StringName TakeAnimation = new("take");

    private PickupContainerAction _action = null!;
    private ContainerItemSource _itemSource = null!;
    private Sprite2D _itemIndicator = null!;
    private AnimatedSprite2D _sprite = null!;

    [Export]
    public PackedScene? PickupScene { get; set; }

    [Export]
    public PickupItemDefinition? ItemDefinition { get; set; }

    public override void _Ready()
    {
        if (PickupScene is null || ItemDefinition is null)
        {
            throw new InvalidOperationException(
                "Container requires both a pickup scene and an item definition."
            );
        }

        _action = GetNode<PickupContainerAction>(
            "InteractionTarget/PickupContainerAction"
        );
        _itemSource = GetNode<ContainerItemSource>("NpcItemSource");
        _itemIndicator = GetNode<Sprite2D>("ItemIndicator");
        _sprite = GetNode<AnimatedSprite2D>("AnimatedSprite2D");

        _action.PickupScene = PickupScene;
        _action.AcceptedItem = ItemDefinition;
        _action.ItemTransferred += PlayTakeAnimation;
        _sprite.AnimationFinished += OnAnimationFinished;
        _itemSource.ItemDefinition = ItemDefinition;
        ApplyItemIndicator(ItemDefinition);
    }

    public override void _ExitTree()
    {
        if (GodotObject.IsInstanceValid(_action))
        {
            _action.ItemTransferred -= PlayTakeAnimation;
        }

        if (GodotObject.IsInstanceValid(_sprite))
        {
            _sprite.AnimationFinished -= OnAnimationFinished;
        }
    }

    private void PlayTakeAnimation()
    {
        _sprite.Play(TakeAnimation);
    }

    private void OnAnimationFinished()
    {
        if (_sprite.Animation == TakeAnimation)
        {
            _sprite.Play(IdleAnimation);
        }
    }

    private void ApplyItemIndicator(PickupItemDefinition definition)
    {
        CollisionShape2D collision = GetNode<CollisionShape2D>(
            "CollisionShape2D"
        );
        _itemIndicator.Position = collision.Position;
        _itemIndicator.Texture = definition.Texture
            ?? GetIdleFrameTexture(definition.SpriteFrames);
        _itemIndicator.Material = definition.VisualMaterial;
        _itemIndicator.Modulate = definition.Modulate;
        _itemIndicator.Scale = definition.VisualScale * 0.5f;
        _itemIndicator.Visible = _itemIndicator.Texture is not null;
    }

    private static Texture2D? GetIdleFrameTexture(SpriteFrames? frames)
    {
        if (
            frames is null
            || !frames.HasAnimation(IdleAnimation)
            || frames.GetFrameCount(IdleAnimation) == 0
        )
        {
            return null;
        }

        return frames.GetFrameTexture(IdleAnimation, 0);
    }
}