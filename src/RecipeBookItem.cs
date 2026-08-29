using System;
using Godot;

public partial class RecipeBookItem : PickupItem
{
    private static readonly StringName OpenAnimation = "open";

    private AnimatedSprite2D _sprite = null!;

    public bool IsOpening { get; private set; }

    public bool IsOpen { get; private set; }

    public override void _Ready()
    {
        base._Ready();
        _sprite = GetNode<AnimatedSprite2D>("AnimatedSprite2D");

        if (
            !_sprite.SpriteFrames.HasAnimation(OpenAnimation)
            || _sprite.SpriteFrames.GetFrameCount(OpenAnimation) != 6
            || _sprite.SpriteFrames.GetAnimationLoopMode(OpenAnimation)
                != SpriteFrames.LoopMode.None
        )
        {
            throw new InvalidOperationException(
                "RecipeBookItem requires a non-looping six-frame 'open' animation."
            );
        }

        _sprite.Animation = OpenAnimation;
        _sprite.Frame = 0;
        _sprite.AnimationFinished += OnAnimationFinished;
    }

    public override bool TrySecondaryInteract()
    {
        if (!IsCarried || IsOpening || IsOpen)
        {
            return false;
        }

        IsOpening = true;
        _sprite.Play(OpenAnimation);
        return true;
    }

    private void OnAnimationFinished()
    {
        if (_sprite.Animation != OpenAnimation)
        {
            return;
        }

        IsOpening = false;
        IsOpen = true;
    }
}
