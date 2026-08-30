class_name TaskBroker
extends Node

## Duck-typed contract with NpcTaskRequest (ported by the data foundations
## scripts): id, generation, definition, destination, requested_item,
## required_tool, status, claimant. Status integers must match NpcTaskStatus's
## original C# ordinals (Open=0, Claimed=1, Completed=2, Canceled=3).
const _TASK_STATUS_OPEN := 0
const _TASK_STATUS_CLAIMED := 1
const _TASK_STATUS_COMPLETED := 2
const _TASK_STATUS_CANCELED := 3

signal tasks_changed

var _tasks: Dictionary = {}
var _task_ids_by_key: Dictionary = {}
var _next_task_id: int = 1

var open_task_count: int:
	get:
		return _count_tasks(_TASK_STATUS_OPEN)

var claimed_task_count: int:
	get:
		return _count_tasks(_TASK_STATUS_CLAIMED)


func publish(
	definition,
	destination: Node2D,
	generation: int,
	requested_item: Resource,
	required_tool: Resource
) -> int:
	if definition == null or destination == null:
		push_error("TaskBroker.publish requires a definition and a destination.")
		return -1

	var key: String = _make_task_key(
		destination.get_instance_id(), generation, definition.Kind
	)
	if _task_ids_by_key.has(key):
		var existing_id: int = _task_ids_by_key[key]
		if _tasks.has(existing_id):
			var existing = _tasks[existing_id]
			if existing.status == _TASK_STATUS_OPEN or existing.status == _TASK_STATUS_CLAIMED:
				return existing_id

	var task_id: int = _next_task_id
	_next_task_id += 1
	var task = NpcTaskRequest.new()
	task.id = task_id
	task.generation = generation
	task.definition = definition
	task.destination = destination
	task.requested_item = requested_item
	task.required_tool = required_tool
	task.status = _TASK_STATUS_OPEN
	task.claimant = null
	_tasks[task_id] = task
	_task_ids_by_key[key] = task_id
	tasks_changed.emit()
	return task_id


func try_claim(
	claimant: Node,
	capability_tags: Dictionary,
	origin: Vector2,
	is_ready: Callable
):
	if claimant == null or capability_tags == null or not is_ready.is_valid():
		push_error(
			"TaskBroker.try_claim requires a claimant, capability tags, and a readiness check."
		)
		return null

	var task = null
	for candidate in _tasks.values():
		if (
			candidate.status != _TASK_STATUS_OPEN
			or not _is_eligible(candidate.definition, capability_tags)
			or not is_ready.call(candidate)
			or (task != null and not _is_higher_priority(candidate, task, origin))
		):
			continue

		task = candidate

	if task == null:
		return null

	task.status = _TASK_STATUS_CLAIMED
	task.claimant = claimant
	tasks_changed.emit()
	return task


func release(task_id: int, claimant: Node) -> bool:
	if not _tasks.has(task_id):
		return false
	var task = _tasks[task_id]
	if task.status != _TASK_STATUS_CLAIMED or task.claimant != claimant:
		return false

	task.status = _TASK_STATUS_OPEN
	task.claimant = null
	tasks_changed.emit()
	return true


func complete(task_id: int, claimant: Node) -> bool:
	if not _tasks.has(task_id):
		return false
	var task = _tasks[task_id]
	if task.status != _TASK_STATUS_CLAIMED or task.claimant != claimant:
		return false

	task.status = _TASK_STATUS_COMPLETED
	task.claimant = null
	tasks_changed.emit()
	return true


func cancel(task_id: int) -> bool:
	if not _tasks.has(task_id):
		return false
	var task = _tasks[task_id]
	if task.status == _TASK_STATUS_COMPLETED or task.status == _TASK_STATUS_CANCELED:
		return false

	task.status = _TASK_STATUS_CANCELED
	task.claimant = null
	tasks_changed.emit()
	return true


func get_status(task_id: int):
	return _tasks[task_id].status if _tasks.has(task_id) else null


func _count_tasks(status: int) -> int:
	var count := 0
	for task in _tasks.values():
		if task.status == status:
			count += 1

	return count


func _make_task_key(publisher_id: int, generation: int, kind: int) -> String:
	return "%d:%d:%d" % [publisher_id, generation, kind]


static func _is_eligible(definition, capability_tags: Dictionary) -> bool:
	for required_tag in definition.RequiredTags:
		if not capability_tags.has(required_tag):
			return false

	return true


static func _is_higher_priority(candidate, current, origin: Vector2) -> bool:
	if candidate.definition.Priority != current.definition.Priority:
		return candidate.definition.Priority > current.definition.Priority

	var candidate_distance: float = origin.distance_squared_to(
		candidate.destination.approach_position
	)
	var current_distance: float = origin.distance_squared_to(
		current.destination.approach_position
	)
	if is_equal_approx(candidate_distance, current_distance):
		return candidate.id < current.id
	return candidate_distance < current_distance
