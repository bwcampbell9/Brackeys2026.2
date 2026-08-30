class_name CustomerWanderController
extends Node

var _actor: CharacterBody2D
var _motor: NpcMotor
var _upright_visual: Node2D
var _random: RandomNumberGenerator
var _wander_wait := 0.0
var _progress_remaining := 0.0
var _progress_position := Vector2.ZERO

@export var MotorPath: NodePath = NodePath("../NpcMotor")

@export var UprightVisualPath: NodePath = NodePath("../TaskRequestIndicator")

@export var UprightVisualOffset: Vector2 = Vector2(0.0, -52.0)

@export_range(0.1, 10, 0.1, "or_greater") var WanderDelay: float = 1.5

@export var WanderBounds: Rect2 = Rect2(96.0, 96.0, 768.0, 320.0)

@export_range(0.2, 10, 0.1, "or_greater") var StuckTimeout: float = 2.0

@export var RandomSeed: int = 0


func _ready() -> void:
	_actor = get_parent() as CharacterBody2D
	if _actor == null:
		push_error("CustomerWanderController must be a child of CharacterBody2D.")
		return

	_motor = get_node_or_null(MotorPath) as NpcMotor
	if _motor == null:
		push_error("CustomerWanderController requires an NpcMotor.")
		return

	_upright_visual = get_node_or_null(UprightVisualPath) as Node2D
	if _upright_visual == null:
		push_error("CustomerWanderController requires an upright visual.")
		return

	_random = RandomNumberGenerator.new()
	if RandomSeed == 0:
		_random.randomize()
	else:
		_random.seed = RandomSeed

	_wander_wait = WanderDelay
	_reset_progress_check()


func _process(delta: float) -> void:
	_upright_visual.global_position = _actor.global_position + UprightVisualOffset
	_upright_visual.global_rotation = 0.0


func _physics_process(delta: float) -> void:
	if not _motor.is_at_target:
		if _actor.global_position.distance_squared_to(_progress_position) >= 64.0:
			_reset_progress_check()
			return

		_progress_remaining -= delta
		if _progress_remaining <= 0.0:
			_motor.stop()
			_wander_wait = 0.0
		return

	_wander_wait -= delta
	if _wander_wait > 0.0:
		return

	_wander_wait = WanderDelay
	_motor.set_target(
		Vector2(
			_random.randf_range(WanderBounds.position.x, WanderBounds.end.x),
			_random.randf_range(WanderBounds.position.y, WanderBounds.end.y)
		)
	)
	_reset_progress_check()


func _reset_progress_check() -> void:
	_progress_position = _actor.global_position
	_progress_remaining = StuckTimeout
