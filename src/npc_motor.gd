class_name NpcMotor
extends Node

const _WAYPOINT_DISTANCE := 6.0
const _WORKSTATION_APPROACH_SAMPLE_COUNT := 8
const _MAXIMUM_APPROACH_PROJECTION_DISTANCE := 24.0

## _body_pusher and _facing_carrier are left untyped by design: BodyPusher and
## PickupCarrier belong to other reservations and expose duck-typed members
## (move_and_push, facing_direction) that a native Node/Node2D static type
## would reject at parse time. See the port report for this contract.
var _actor: CharacterBody2D
var _navigation_agent: NavigationAgent2D
var _body_pusher
var _facing_carrier
var _target_position := Vector2.ZERO
var _is_moving := false

@export var NavigationAgentPath: NodePath = NodePath("../NavigationAgent2D")

@export var BodyPusherPath: NodePath = NodePath("../BodyPusher")

@export var FacingCarrierPath: NodePath = NodePath("")

@export_range(10, 500, 1, "or_greater") var Speed: float = 110.0

@export_range(1, 100, 1, "or_greater") var ArrivalDistance: float = 18.0

var is_at_target: bool:
	get:
		return not _is_moving

var target_position: Vector2:
	get:
		return _target_position


func _ready() -> void:
	_actor = get_parent() as CharacterBody2D
	if _actor == null:
		push_error("NpcMotor must be a child of CharacterBody2D.")
		return

	_navigation_agent = get_node_or_null(NavigationAgentPath) as NavigationAgent2D
	if _navigation_agent == null:
		push_error("NpcMotor requires a NavigationAgent2D.")
		return

	_body_pusher = get_node_or_null(BodyPusherPath) as BodyPusher
	if _body_pusher == null:
		push_error("NpcMotor requires a BodyPusher.")
		return

	if String(FacingCarrierPath) != "":
		_facing_carrier = get_node_or_null(FacingCarrierPath) as PickupCarrier
		if _facing_carrier == null:
			push_error("NpcMotor requires the configured PickupCarrier.")
			return

	_navigation_agent.path_desired_distance = _WAYPOINT_DISTANCE
	_navigation_agent.target_desired_distance = ArrivalDistance


func _physics_process(delta: float) -> void:
	if (
		not _is_moving
		or _actor.global_position.distance_to(_target_position) <= ArrivalDistance
	):
		stop()
		_body_pusher.move_and_push(_actor, Vector2.ZERO, delta)
		return

	var next_position: Vector2 = (
		_target_position
		if _navigation_agent.is_navigation_finished()
		else _navigation_agent.get_next_path_position()
	)
	var direction := _actor.global_position.direction_to(next_position)
	if direction.is_zero_approx():
		direction = _actor.global_position.direction_to(_target_position)

	var requested_velocity := direction * Speed
	if not direction.is_zero_approx() and _facing_carrier != null:
		_facing_carrier.facing_direction = direction
	_body_pusher.move_and_push(_actor, requested_velocity, delta)

	if _actor.global_position.distance_to(_target_position) <= ArrivalDistance:
		stop()


func set_target(new_target_position: Vector2) -> void:
	if (
		_target_position.distance_squared_to(new_target_position) < 16.0
		and (
			_is_moving
			or _actor.global_position.distance_to(new_target_position) <= ArrivalDistance
		)
	):
		return

	_target_position = new_target_position
	_navigation_agent.target_position = new_target_position
	_is_moving = true


func try_set_navigable_target(preferred_position: Vector2) -> bool:
	var result := _try_get_reachable_point(preferred_position, INF)
	if not result["success"]:
		return false

	set_target(result["target_position"])
	return true


func try_set_approach_target(target_node: Node2D, preferred_position: Vector2) -> bool:
	var workstation := _find_static_body_ancestor(target_node)
	if workstation == null:
		var direct_result := _try_get_reachable_point(
			preferred_position, _MAXIMUM_APPROACH_PROJECTION_DISTANCE
		)
		if not direct_result["success"]:
			return false

		set_target(direct_result["target_position"])
		return true

	var center: Vector2 = workstation.global_position
	var preferred_direction := center.direction_to(preferred_position)
	if preferred_direction.is_zero_approx():
		preferred_direction = Vector2.DOWN
	var approach_radius: float = maxf(
		center.distance_to(preferred_position), ArrivalDistance * 2.0
	)
	var best_path_length := INF
	var best_target := Vector2.ZERO
	var found_target := false
	for index in range(_WORKSTATION_APPROACH_SAMPLE_COUNT):
		var candidate: Vector2 = (
			center
			+ preferred_direction.rotated(TAU * index / _WORKSTATION_APPROACH_SAMPLE_COUNT)
				* approach_radius
		)
		var result := _try_get_reachable_point(
			candidate, _MAXIMUM_APPROACH_PROJECTION_DISTANCE
		)
		if not result["success"] or result["path_length"] >= best_path_length:
			continue

		found_target = true
		best_target = result["target_position"]
		best_path_length = result["path_length"]

	if not found_target:
		return false

	set_target(best_target)
	return true


func stop() -> void:
	_is_moving = false
	if is_instance_valid(_actor):
		_actor.velocity = Vector2.ZERO


func _try_get_reachable_point(
	preferred_position: Vector2, maximum_projection_distance: float
) -> Dictionary:
	var failure := {
		"success": false,
		"target_position": Vector2.ZERO,
		"path_length": INF,
	}

	var navigation_map: RID = _navigation_agent.get_navigation_map()
	if NavigationServer2D.map_get_iteration_id(navigation_map) == 0:
		return failure

	var navigable_origin: Vector2 = NavigationServer2D.map_get_closest_point(
		navigation_map, _actor.global_position
	)
	var navigable_target: Vector2 = NavigationServer2D.map_get_closest_point(
		navigation_map, preferred_position
	)
	if preferred_position.distance_to(navigable_target) > maximum_projection_distance:
		return failure

	var path: PackedVector2Array = NavigationServer2D.map_get_path(
		navigation_map,
		navigable_origin,
		navigable_target,
		true,
		_navigation_agent.navigation_layers
	)
	if path.is_empty() and navigable_origin.distance_to(navigable_target) > ArrivalDistance:
		return failure

	var path_length: float = navigable_origin.distance_to(
		path[0] if path.size() > 0 else navigable_target
	)
	for index in range(1, path.size()):
		path_length += path[index - 1].distance_to(path[index])

	return {
		"success": true,
		"target_position": navigable_target,
		"path_length": path_length,
	}


static func _find_static_body_ancestor(node: Node) -> StaticBody2D:
	var current: Node = node
	while current != null:
		if current is StaticBody2D:
			return current as StaticBody2D
		current = current.get_parent()
	return null
