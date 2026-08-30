class_name Player
extends CharacterBody2D

const MOVE_LEFT_ACTION := &"move_left"
const MOVE_RIGHT_ACTION := &"move_right"
const MOVE_UP_ACTION := &"move_up"
const MOVE_DOWN_ACTION := &"move_down"
const IDLE_ANIMATION := &"idle"
const WALK_ANIMATION := &"walk"

@export_range(1, 1000, 1, "or_greater") var Speed: float = 240.0
@export_range(0.1, 30, 0.1, "or_greater") var RotationSharpness: float = 12.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _inner_arm: Sprite2D = $InnerArm
@onready var _outer_arm: Sprite2D = $OuterArm
@onready var _pickup_carrier: PickupCarrier = $PickupCarrier
@onready var _interactor: PlayerInteractor = $Interactor
@onready var _body_pusher: BodyPusher = $BodyPusher

var _facing_rotation: float = 0.0
var _facing_right: bool = false
var _current_animation: StringName = &""


func _ready() -> void:
	_facing_rotation = 0.0
	_set_horizontal_facing(_sprite.flip_h)
	_set_facing_direction(Vector2.UP)
	_set_animation(IDLE_ANIMATION)


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector(
		MOVE_LEFT_ACTION,
		MOVE_RIGHT_ACTION,
		MOVE_UP_ACTION,
		MOVE_DOWN_ACTION
	)

	if not direction.is_zero_approx():
		if not is_zero_approx(direction.x):
			_set_horizontal_facing(direction.x > 0.0)

		var target_rotation := direction.angle() + PI / 2.0
		var interpolation_weight := 1.0 - exp(-RotationSharpness * delta)
		_facing_rotation = lerp_angle(
			_facing_rotation,
			target_rotation,
			interpolation_weight
		)
		var facing_direction := Vector2.UP.rotated(_facing_rotation)
		_set_facing_direction(facing_direction)

	_set_animation(IDLE_ANIMATION if direction.is_zero_approx() else WALK_ANIMATION)
	var requested_velocity := direction * Speed
	_body_pusher.move_and_push(self, requested_velocity, delta)


func _set_animation(animation: StringName) -> void:
	if _current_animation == animation:
		return

	_current_animation = animation
	_sprite.play(animation)


func _set_horizontal_facing(facing_right: bool) -> void:
	_facing_right = facing_right
	_sprite.flip_h = facing_right
	_inner_arm.flip_h = facing_right
	_outer_arm.flip_h = facing_right


func _set_facing_direction(facing_direction: Vector2) -> void:
	_pickup_carrier.facing_direction = facing_direction
	_interactor.facing_direction = facing_direction

	var arm_rotation := facing_direction.angle()
	if not _facing_right:
		arm_rotation += PI

	_inner_arm.rotation = arm_rotation
	_outer_arm.rotation = arm_rotation
