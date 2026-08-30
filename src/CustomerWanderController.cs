using System;
using Godot;

public partial class CustomerWanderController : Node
{
    private CharacterBody2D _actor = null!;
    private NpcMotor _motor = null!;
    private Node2D _uprightVisual = null!;
    private RandomNumberGenerator _random = null!;
    private float _wanderWait;
    private float _progressRemaining;
    private Vector2 _progressPosition;

    [Export]
    public NodePath MotorPath { get; set; } = new("../NpcMotor");

    [Export]
    public NodePath UprightVisualPath { get; set; } =
        new("../TaskRequestIndicator");

    [Export]
    public Vector2 UprightVisualOffset { get; set; } =
        new(0.0f, -52.0f);

    [Export(PropertyHint.Range, "0.1,10,0.1,or_greater")]
    public float WanderDelay { get; set; } = 1.5f;

    [Export]
    public Rect2 WanderBounds { get; set; } =
        new(96.0f, 96.0f, 768.0f, 320.0f);

    [Export(PropertyHint.Range, "0.2,10,0.1,or_greater")]
    public float StuckTimeout { get; set; } = 2.0f;

    [Export]
    public long RandomSeed { get; set; }

    public override void _Ready()
    {
        _actor =
            GetParentOrNull<CharacterBody2D>()
            ?? throw new InvalidOperationException(
                "CustomerWanderController must be a child of CharacterBody2D."
            );
        _motor =
            GetNodeOrNull<NpcMotor>(MotorPath)
            ?? throw new InvalidOperationException(
                "CustomerWanderController requires an NpcMotor."
            );
        _uprightVisual =
            GetNodeOrNull<Node2D>(UprightVisualPath)
            ?? throw new InvalidOperationException(
                "CustomerWanderController requires an upright visual."
            );
        _random = new RandomNumberGenerator();
        if (RandomSeed == 0)
        {
            _random.Randomize();
        }
        else
        {
            _random.Seed = (ulong)RandomSeed;
        }

        _wanderWait = WanderDelay;
        ResetProgressCheck();
    }

    public override void _Process(double delta)
    {
        _uprightVisual.GlobalPosition =
            _actor.GlobalPosition + UprightVisualOffset;
        _uprightVisual.GlobalRotation = 0.0f;
    }

    public override void _PhysicsProcess(double delta)
    {
        if (!_motor.IsAtTarget)
        {
            if (
                _actor.GlobalPosition.DistanceSquaredTo(_progressPosition)
                >= 64.0f
            )
            {
                ResetProgressCheck();
                return;
            }

            _progressRemaining -= (float)delta;
            if (_progressRemaining <= 0.0f)
            {
                _motor.Stop();
                _wanderWait = 0.0f;
            }
            return;
        }

        _wanderWait -= (float)delta;
        if (_wanderWait > 0.0f)
        {
            return;
        }

        _wanderWait = WanderDelay;
        Vector2 preferredTarget = new(
            _random.RandfRange(
                WanderBounds.Position.X,
                WanderBounds.End.X
            ),
            _random.RandfRange(
                WanderBounds.Position.Y,
                WanderBounds.End.Y
            )
        );
        if (_motor.TrySetNavigableTarget(preferredTarget))
        {
            ResetProgressCheck();
        }
    }

    private void ResetProgressCheck()
    {
        _progressPosition = _actor.GlobalPosition;
        _progressRemaining = StuckTimeout;
    }
}
