using System;
using Godot;

public partial class NpcMotor : Node
{
    private CharacterBody2D _actor = null!;
    private NavigationAgent2D _navigationAgent = null!;
    private PickupCarrier? _facingCarrier;
    private Vector2 _targetPosition;
    private bool _isMoving;

    [Export]
    public NodePath NavigationAgentPath { get; set; } =
        new("../NavigationAgent2D");

    [Export]
    public NodePath FacingCarrierPath { get; set; } = new();

    [Export(PropertyHint.Range, "10,500,1,or_greater")]
    public float Speed { get; set; } = 110.0f;

    [Export(PropertyHint.Range, "1,100,1,or_greater")]
    public float ArrivalDistance { get; set; } = 18.0f;

    public bool IsAtTarget => !_isMoving;

    public Vector2 TargetPosition => _targetPosition;

    public override void _Ready()
    {
        _actor =
            GetParentOrNull<CharacterBody2D>()
            ?? throw new InvalidOperationException(
                "NpcMotor must be a child of CharacterBody2D."
            );
        _navigationAgent =
            GetNodeOrNull<NavigationAgent2D>(NavigationAgentPath)
            ?? throw new InvalidOperationException(
                "NpcMotor requires a NavigationAgent2D."
            );
        if (!string.IsNullOrEmpty(FacingCarrierPath.ToString()))
        {
            _facingCarrier =
                GetNodeOrNull<PickupCarrier>(FacingCarrierPath)
                ?? throw new InvalidOperationException(
                    "NpcMotor requires the configured PickupCarrier."
                );
        }
        _navigationAgent.PathDesiredDistance = ArrivalDistance;
        _navigationAgent.TargetDesiredDistance = ArrivalDistance;
    }

    public override void _PhysicsProcess(double delta)
    {
        if (
            !_isMoving
            || _actor.GlobalPosition.DistanceTo(_targetPosition)
                <= ArrivalDistance
        )
        {
            Stop();
            return;
        }

        Vector2 nextPosition = _navigationAgent.IsNavigationFinished()
            ? _targetPosition
            : _navigationAgent.GetNextPathPosition();
        Vector2 direction = _actor.GlobalPosition.DirectionTo(nextPosition);
        if (direction.IsZeroApprox())
        {
            direction = _actor.GlobalPosition.DirectionTo(_targetPosition);
        }

        _actor.Velocity = direction * Speed;
        if (!direction.IsZeroApprox() && _facingCarrier is not null)
        {
            _facingCarrier.FacingDirection = direction;
        }
        _actor.MoveAndSlide();

        if (
            _actor.GlobalPosition.DistanceTo(_targetPosition)
            <= ArrivalDistance
        )
        {
            Stop();
        }
    }

    public void SetTarget(Vector2 targetPosition)
    {
        if (
            _isMoving
            && _targetPosition.DistanceSquaredTo(targetPosition) < 16.0f
        )
        {
            return;
        }

        _targetPosition = targetPosition;
        _navigationAgent.TargetPosition = targetPosition;
        _isMoving = true;
    }

    public void Stop()
    {
        _isMoving = false;
        if (GodotObject.IsInstanceValid(_actor))
        {
            _actor.Velocity = Vector2.Zero;
        }
    }
}
