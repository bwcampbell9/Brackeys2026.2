using System;
using Godot;

public partial class NpcMotor : Node
{
    private CharacterBody2D _actor = null!;
    private NavigationAgent2D _navigationAgent = null!;
    private CollisionShape2D _bodyCollision = null!;
    private BodyPusher _bodyPusher = null!;
    private Vector2 _uprightCollisionOffset;
    private Vector2 _targetPosition;
    private bool _isMoving;

    [Export]
    public NodePath NavigationAgentPath { get; set; } =
        new("../NavigationAgent2D");

    [Export]
    public NodePath BodyCollisionPath { get; set; } =
        new("../CollisionShape2D");

    [Export]
    public NodePath BodyPusherPath { get; set; } =
        new("../BodyPusher");

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
        _bodyCollision =
            GetNodeOrNull<CollisionShape2D>(BodyCollisionPath)
            ?? throw new InvalidOperationException(
                "NpcMotor requires a body CollisionShape2D."
            );
        _bodyPusher =
            GetNodeOrNull<BodyPusher>(BodyPusherPath)
            ?? throw new InvalidOperationException(
                "NpcMotor requires a BodyPusher."
            );
        _uprightCollisionOffset = _bodyCollision.Position;
        KeepCollisionBelowActor();
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
            _bodyPusher.MoveAndPush(
                _actor,
                Vector2.Zero,
                delta
            );
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

        Vector2 requestedVelocity = direction * Speed;
        if (!direction.IsZeroApprox())
        {
            _actor.Rotation = direction.Angle() + Mathf.Pi / 2.0f;
            KeepCollisionBelowActor();
        }
        _bodyPusher.MoveAndPush(
            _actor,
            requestedVelocity,
            delta
        );

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

    private void KeepCollisionBelowActor()
    {
        _bodyCollision.Position = _uprightCollisionOffset.Rotated(
            -_actor.Rotation
        );
    }
}
