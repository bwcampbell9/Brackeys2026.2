## Discovers and drives the best available [InteractionAction] within reach
## of an actor: instant taps via [method try_execute], and held interactions
## that run over multiple frames via [method try_begin] /
## [method update_active_interaction].
class_name PlayerInteractor
extends Node2D

var _interaction_area: Area2D
var _close_interaction_area: Area2D
var _active_target: InteractionTarget
var _active_action: InteractionAction
var _active_context: InteractionContext

@export_range(1.0, 360.0, 1.0, "degrees") var InteractionConeDegrees: float = 140.0
@export_range(0.0, 200.0, 1.0, "or_greater") var TargetFocusDistance: float = 48.0
@export var UseTargetPriority: bool = false

var facing_direction: Vector2 = Vector2.UP:
	set(value):
		if not value.is_zero_approx():
			facing_direction = value.normalized()

var has_active_interaction: bool:
	get:
		return is_instance_valid(_active_target) and is_instance_valid(_active_action)


func _ready() -> void:
	_interaction_area = get_node("InteractionArea")
	_close_interaction_area = get_node("CloseInteractionArea")

	var interaction_collision: CollisionShape2D = _interaction_area.get_node("CollisionShape2D")
	if interaction_collision.shape == null:
		push_error("InteractionArea requires a collision shape.")


func try_execute(action_ids: Array[StringName], context: InteractionContext) -> bool:
	if has_active_interaction:
		return false

	var found := _find_best_action(action_ids, InteractionAction.InteractionInputTrigger.TAP, context)
	var action: InteractionAction = found.action
	return action != null and action.execute(context)


func try_begin(action_ids: Array[StringName], context: InteractionContext) -> bool:
	if has_active_interaction:
		return false

	var found := _find_best_action(action_ids, InteractionAction.InteractionInputTrigger.HOLD, context)
	var action: InteractionAction = found.action
	var target: InteractionTarget = found.target
	if action == null or target == null or not action.begin(context):
		return false

	_active_target = target
	_active_action = action
	_active_context = context
	return true


func has_target_with_action(action_ids: Array[StringName], trigger: int, context: InteractionContext) -> bool:
	for target in _get_targets_in_range():
		if target.target_owner == context.carrier.held_item or not _is_target_selectable(target):
			continue

		for action_id in action_ids:
			if target.has_action(action_id, trigger):
				return true

	return false


func update_active_interaction(delta: float) -> void:
	if not has_active_interaction or _active_target == null or _active_action == null:
		_clear_active_interaction()
		return

	if not _is_target_in_range(_active_target) or not _active_action.is_available(_active_context):
		cancel_active_interaction()
		return

	var state: InteractionAction.RunState = _active_action.update_interaction(_active_context, delta)
	if state == InteractionAction.RunState.RUNNING:
		return

	if state == InteractionAction.RunState.FAILED:
		_active_action.cancel(_active_context)

	_clear_active_interaction()


func cancel_active_interaction() -> void:
	if has_active_interaction and _active_action != null:
		_active_action.cancel(_active_context)

	_clear_active_interaction()


func complete_active_interaction() -> void:
	if has_active_interaction and _active_action != null:
		_active_action.complete(_active_context)

	_clear_active_interaction()


func _find_best_action(action_ids: Array[StringName], trigger: int, context: InteractionContext) -> Dictionary:
	for action_id in action_ids:
		var found := _find_best_action_for_id(action_id, trigger, context)
		if found.action != null:
			return found

	return {"action": null, "target": null}


func _find_best_action_for_id(action_id: StringName, trigger: int, context: InteractionContext) -> Dictionary:
	var minimum_alignment := cos(deg_to_rad(InteractionConeDegrees * 0.5))
	var focus_position := global_position + facing_direction * TargetFocusDistance
	var best_priority := -2147483648
	var best_focus_distance_squared := INF
	var best_distance_squared := INF
	var best_action: InteractionAction = null
	var best_target: InteractionTarget = null

	for target in _get_targets_in_range():
		var action := target.find_action(action_id, trigger, context)
		if action == null:
			continue

		if not _is_target_selectable_with_alignment(target, minimum_alignment):
			continue

		var distance_squared := target.global_position.distance_squared_to(global_position)
		var priority: int = target.priority if UseTargetPriority else 0
		var focus_distance_squared := target.global_position.distance_squared_to(focus_position)
		var focus_distances_match := is_equal_approx(focus_distance_squared, best_focus_distance_squared)
		var is_better := (
			priority > best_priority
			or (
				priority == best_priority
				and (
					(not focus_distances_match and focus_distance_squared < best_focus_distance_squared)
					or (focus_distances_match and distance_squared < best_distance_squared)
				)
			)
		)
		if not is_better:
			continue

		best_priority = priority
		best_focus_distance_squared = focus_distance_squared
		best_distance_squared = distance_squared
		best_target = target
		best_action = action

	return {"action": best_action, "target": best_target}


func _is_target_selectable(target: InteractionTarget) -> bool:
	return _is_target_selectable_with_alignment(target, cos(deg_to_rad(InteractionConeDegrees * 0.5)))


func _is_target_selectable_with_alignment(target: InteractionTarget, minimum_alignment: float) -> bool:
	if _close_interaction_area.overlaps_area(target):
		return true

	var offset := target.global_position - global_position
	var distance_squared := offset.length_squared()
	var alignment := 1.0 if distance_squared <= 0.000001 else facing_direction.dot(offset / sqrt(distance_squared))
	return alignment >= minimum_alignment


func _get_targets_in_range() -> Array[InteractionTarget]:
	var targets: Array[InteractionTarget] = []
	_add_targets(_interaction_area, targets)
	_add_targets(_close_interaction_area, targets)
	return targets


func _is_target_in_range(target: InteractionTarget) -> bool:
	return _interaction_area.overlaps_area(target) or _close_interaction_area.overlaps_area(target)


static func _add_targets(area: Area2D, targets: Array[InteractionTarget]) -> void:
	for overlapping_area in area.get_overlapping_areas():
		if overlapping_area is InteractionTarget and not targets.has(overlapping_area):
			targets.append(overlapping_area)


func _clear_active_interaction() -> void:
	_active_target = null
	_active_action = null
	_active_context = null
