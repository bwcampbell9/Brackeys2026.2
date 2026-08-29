using Godot;

public partial class Executioner : Node2D
{
    private static readonly StringName IdleAnimation = "idle";
    private static readonly StringName WalkAnimation = "walk";
    private static readonly StringName TakeoutAnimation = "takeout";
    private static readonly StringName ChopAnimation = "chop";

    private AnimatedSprite2D _sprite = null!;

    public event System.Action? AnimationFinished;

    public override void _Ready()
    {
        _sprite = GetNode<AnimatedSprite2D>("AnimatedSprite2D");
        _sprite.AnimationFinished += OnAnimationFinished;
        PlayIdle();
    }

    public void PlayIdle() => _sprite.Play(IdleAnimation);

    public void PlayWalk() => _sprite.Play(WalkAnimation);

    public void PlayTakeout() => _sprite.Play(TakeoutAnimation);

    public void PlayChop() => _sprite.Play(ChopAnimation);

    private void OnAnimationFinished()
    {
        AnimationFinished?.Invoke();
    }
}