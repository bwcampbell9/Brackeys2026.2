class_name WorkerVisualController
extends Node

const _IDLE_ANIMATION: StringName = &"idle"
const _WALK_ANIMATION: StringName = &"walk"

var _sprite: AnimatedSprite2D
var _actor: CharacterBody2D
var _motor: NpcMotor
var _current_animation: StringName = &""

@export var SpritePath: NodePath = NodePath("../AnimatedSprite2D")

@export var MotorPath: NodePath = NodePath("../NpcMotor")


func _ready() -> void:
	_actor = get_parent() as CharacterBody2D
	if _actor == null:
		push_error("WorkerVisualController must be a child of CharacterBody2D.")
		return

	_sprite = get_node_or_null(SpritePath) as AnimatedSprite2D
	if _sprite == null:
		push_error("WorkerVisualController requires an AnimatedSprite2D.")
		return

	_motor = get_node_or_null(MotorPath) as NpcMotor
	if _motor == null:
		push_error("WorkerVisualController requires an NpcMotor.")
		return

	_set_animation(_IDLE_ANIMATION)


func _process(delta: float) -> void:
	_sprite.global_rotation = 0.0
	if not is_zero_approx(_actor.velocity.x):
		_sprite.flip_h = _actor.velocity.x > 0.0
	_set_animation(_IDLE_ANIMATION if _motor.is_at_target else _WALK_ANIMATION)


func _set_animation(animation: StringName) -> void:
	if _current_animation == animation:
		return

	_current_animation = animation
	_sprite.play(animation)
