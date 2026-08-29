using Godot;

public partial class Player : CharacterBody2D
{
	private static readonly StringName MoveLeftAction = "move_left";
	private static readonly StringName MoveRightAction = "move_right";
	private static readonly StringName MoveUpAction = "move_up";
	private static readonly StringName MoveDownAction = "move_down";
	private static readonly StringName IdleAnimation = "idle";
	private static readonly StringName WalkAnimation = "walk";
	private AnimatedSprite2D _sprite = null!;
	private Sprite2D _innerArm = null!;
	private Sprite2D _outerArm = null!;
	private PickupCarrier _pickupCarrier = null!;
	private PlayerInteractor _interactor = null!;
	private BodyPusher _bodyPusher = null!;
	private float _facingRotation;
	private bool _facingRight;
	private StringName _currentAnimation = new();

	[Export(PropertyHint.Range, "1,1000,1,or_greater")]
	public float Speed { get; set; } = 240.0f;

	[Export(PropertyHint.Range, "0.1,30,0.1,or_greater")]
	public float RotationSharpness { get; set; } = 12.0f;

	public override void _Ready()
	{
		_sprite = GetNode<AnimatedSprite2D>("AnimatedSprite2D");
		_innerArm = GetNode<Sprite2D>("InnerArm");
		_outerArm = GetNode<Sprite2D>("OuterArm");
		_pickupCarrier = GetNode<PickupCarrier>("PickupCarrier");
		_interactor = GetNode<PlayerInteractor>("Interactor");
		_bodyPusher = GetNode<BodyPusher>("BodyPusher");
		_facingRotation = 0.0f;
		SetHorizontalFacing(_sprite.FlipH);
		SetFacingDirection(Vector2.Up);
		SetAnimation(IdleAnimation);
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
			if (!Mathf.IsZeroApprox(direction.X))
			{
				SetHorizontalFacing(direction.X > 0.0f);
			}

			float targetRotation = direction.Angle() + Mathf.Pi / 2.0f;
			float interpolationWeight = 1.0f - Mathf.Exp(-RotationSharpness * (float)delta);
			_facingRotation = Mathf.LerpAngle(
				_facingRotation,
				targetRotation,
				interpolationWeight
			);
			Vector2 facingDirection = Vector2.Up.Rotated(_facingRotation);
			SetFacingDirection(facingDirection);
		}

		SetAnimation(direction.IsZeroApprox() ? IdleAnimation : WalkAnimation);
		Vector2 requestedVelocity = direction * Speed;
		_bodyPusher.MoveAndPush(this, requestedVelocity, delta);
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

	private void SetHorizontalFacing(bool facingRight)
	{
		_facingRight = facingRight;
		_sprite.FlipH = facingRight;
		_innerArm.FlipH = facingRight;
		_outerArm.FlipH = facingRight;
	}

	private void SetFacingDirection(Vector2 facingDirection)
	{
		_pickupCarrier.FacingDirection = facingDirection;
		_interactor.FacingDirection = facingDirection;

		float armRotation = facingDirection.Angle();
		if (!_facingRight)
		{
			armRotation += Mathf.Pi;
		}

		_innerArm.Rotation = armRotation;
		_outerArm.Rotation = armRotation;
	}
}
