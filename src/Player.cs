using Godot;

public partial class Player : CharacterBody2D
{
    private static readonly StringName MoveLeftAction = "move_left";
    private static readonly StringName MoveRightAction = "move_right";
    private static readonly StringName MoveUpAction = "move_up";
    private static readonly StringName MoveDownAction = "move_down";
    private Sprite2D _sprite = null!;
    private PickupCarrier _pickupCarrier = null!;
    private PlayerInteractor _interactor = null!;
    private float _facingRotation;

    [Export(PropertyHint.Range, "1,1000,1,or_greater")]
    public float Speed { get; set; } = 240.0f;

    [Export(PropertyHint.Range, "0.1,30,0.1,or_greater")]
    public float RotationSharpness { get; set; } = 12.0f;

    public override void _Ready()
    {
        _sprite = GetNode<Sprite2D>("Sprite2D");
        _pickupCarrier = GetNode<PickupCarrier>("PickupCarrier");
        _interactor = GetNode<PlayerInteractor>("Interactor");
        _facingRotation = _sprite.Rotation;
        Vector2 facingDirection = Vector2.Up.Rotated(_facingRotation);
        _pickupCarrier.FacingDirection = facingDirection;
        _interactor.FacingDirection = facingDirection;
    }

    public override void _PhysicsProcess(double delta)
    {
        Vector2 direction = Input.GetVector(
            MoveLeftAction,
            MoveRightAction,
            MoveUpAction,
            MoveDownAction
        );

        if (!direction.IsZeroApprox())
        {
            float targetRotation = direction.Angle() + Mathf.Pi / 2.0f;
            float interpolationWeight = 1.0f - Mathf.Exp(-RotationSharpness * (float)delta);
            _facingRotation = Mathf.LerpAngle(
                _facingRotation,
                targetRotation,
                interpolationWeight
            );
            _sprite.Rotation = _facingRotation;
            Vector2 facingDirection = Vector2.Up.Rotated(_facingRotation);
            _pickupCarrier.FacingDirection = facingDirection;
            _interactor.FacingDirection = facingDirection;
        }

        Velocity = direction * Speed;
        MoveAndSlide();
    }
}
