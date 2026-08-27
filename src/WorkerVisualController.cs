using System;
using Godot;

public partial class WorkerVisualController : Node
{
    private static readonly StringName IdleAnimation = new("idle");
    private static readonly StringName WalkAnimation = new("walk");
    private AnimatedSprite2D _sprite = null!;
    private CharacterBody2D _actor = null!;
    private NpcMotor _motor = null!;
    private StringName _currentAnimation = new();

    [Export]
    public NodePath SpritePath { get; set; } = new("../AnimatedSprite2D");

    [Export]
    public NodePath MotorPath { get; set; } = new("../NpcMotor");

    public override void _Ready()
    {
        _actor =
            GetParentOrNull<CharacterBody2D>()
            ?? throw new InvalidOperationException(
                "WorkerVisualController must be a child of CharacterBody2D."
            );
        _sprite =
            GetNodeOrNull<AnimatedSprite2D>(SpritePath)
            ?? throw new InvalidOperationException(
                "WorkerVisualController requires an AnimatedSprite2D."
            );
        _motor =
            GetNodeOrNull<NpcMotor>(MotorPath)
            ?? throw new InvalidOperationException(
                "WorkerVisualController requires an NpcMotor."
            );
        SetAnimation(IdleAnimation);
    }

    public override void _Process(double delta)
    {
        _sprite.GlobalRotation = 0.0f;
        if (!Mathf.IsZeroApprox(_actor.Velocity.X))
        {
            _sprite.FlipH = _actor.Velocity.X > 0.0f;
        }
        SetAnimation(_motor.IsAtTarget ? IdleAnimation : WalkAnimation);
    }

    private void SetAnimation(StringName animation)
    {
        if (_currentAnimation == animation)
        {
            return;
        }

        _currentAnimation = animation;
        _sprite.Play(animation);
    }
}
