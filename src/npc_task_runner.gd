class_name NpcTaskRunner
extends Node

## Nested to match the original code's local usage; no other reservation
## referenced NpcWorkerState externally, so ordinal placement only needs to
## match within this file. Order mirrors NpcWorkerState.cs exactly:
## Idle=0, NavigatingToSource=1, RetryDelay=2, NavigatingToDestination=3,
## Working=4, ReturningItem=5, Wandering=6.
enum NpcWorkerState {
	IDLE,
	NAVIGATING_TO_SOURCE,
	RETRY_DELAY,
	NAVIGATING_TO_DESTINATION,
	WORKING,
	RETURNING_ITEM,
	WANDERING,
}

const RUNNER_GROUP: StringName = &"npc_task_runners"

## Duck-typed integer mirrors of cross-reservation enums (data foundations'
## NpcTaskKind, NpcTaskStatus, NpcTaskFailureMode; interaction's
## InteractionRunState). Their ordinals are guaranteed stable by contract.
const _TASK_KIND_FETCH := 0
const _TASK_KIND_ACTION := 1
const _TASK_STATUS_CLAIMED := 1
const _FAILURE_MODE_WRONG_FETCHED_ITEM := 0
const _RUN_STATE_RUNNING := 0
const _RUN_STATE_FAILED := 2

signal state_changed(state: int)

var _capability_tags: Dictionary = {}
var _actor: CharacterBody2D
var _motor: NpcMotor
## _carrier, _catalog, _task, _source, _return_source, and _selected_definition
## are left untyped: PickupCarrier, ItemSourceCatalog, NpcTaskRequest,
## IItemSource implementations, and PickupItemDefinition belong to other
## reservations and their duck-typed members (held_item, throw, configure,
## release, id, status, Kind, Id, etc.) are not present on a native
## Node/Node2D/Resource static type. See the port report for this contract.
var _carrier
var _random: RandomNumberGenerator
var _broker: TaskBroker
var _catalog
var _task
var _source
var _return_source
var _selected_definition
var _selected_failure_mode
var _source_reference_position := Vector2.ZERO
var _destination_reference_position := Vector2.ZERO
var _retry_remaining := 0.0
var _wander_wait := 0.0
var _state: int = NpcWorkerState.IDLE

@export var MotorPath: NodePath = NodePath("../NpcMotor")

@export var CarrierPath: NodePath = NodePath("../PickupCarrier")

@export var CapabilityTags: Array[StringName] = [&"kitchen"]

@export var Personality: Resource

@export_range(0.1, 10, 0.1, "or_greater") var RetryDelay: float = 1.0

@export_range(0.1, 10, 0.1, "or_greater") var WanderDelay: float = 1.5

@export var WanderBounds: Rect2 = Rect2(96.0, 96.0, 768.0, 320.0)

@export var RandomSeed: int = 0

var state: int:
	get:
		return _state

var selected_item_id: StringName:
	get:
		return _selected_definition.Id if _selected_definition != null else StringName()

var current_task_id: int:
	get:
		return _task.id if _task != null else 0

var selected_failure_mode: int:
	get:
		return _selected_failure_mode if _selected_failure_mode != null else -1


func _ready() -> void:
	_actor = get_parent() as CharacterBody2D
	if _actor == null:
		push_error("NpcTaskRunner must be a child of CharacterBody2D.")
		return

	_motor = get_node_or_null(MotorPath) as NpcMotor
	if _motor == null:
		push_error("NpcTaskRunner requires an NpcMotor.")
		return

	_carrier = get_node_or_null(CarrierPath) as PickupCarrier
	if _carrier == null:
		push_error("NpcTaskRunner requires a PickupCarrier.")
		return

	_random = RandomNumberGenerator.new()
	if RandomSeed == 0:
		_random.randomize()
	else:
		_random.seed = RandomSeed

	for capability_tag in CapabilityTags:
		_capability_tags[capability_tag] = true

	_wander_wait = WanderDelay
	add_to_group(RUNNER_GROUP)


func _exit_tree() -> void:
	if _broker != null:
		_broker.tasks_changed.disconnect(_on_tasks_changed)
		if _task != null:
			_broker.release(_task.id, self)
	if _catalog != null:
		_catalog.release(_source, self)


func configure(broker: TaskBroker, catalog) -> void:
	if _broker == broker and _catalog == catalog:
		return

	if _broker != null:
		_broker.tasks_changed.disconnect(_on_tasks_changed)
		if _task != null:
			_broker.release(_task.id, self)
	if _catalog != null:
		_catalog.release(_source, self)

	_broker = broker
	_catalog = catalog
	_task = null
	_source = null
	_return_source = null
	_selected_definition = null
	_selected_failure_mode = null
	_broker.tasks_changed.connect(_on_tasks_changed)
	_motor.stop()
	_set_state(NpcWorkerState.IDLE)


func _physics_process(delta: float) -> void:
	if _broker == null or _catalog == null:
		return

	if (
		_task != null
		and _state != NpcWorkerState.RETURNING_ITEM
		and _state != NpcWorkerState.IDLE
		and _state != NpcWorkerState.WANDERING
		and (_task.status != _TASK_STATUS_CLAIMED or _task.claimant != self)
	):
		_handle_lost_task()
		return

	if (
		_task != null
		and (_task.definition.Kind == _TASK_KIND_FETCH or _task.required_tool != null)
		and _carrier.held_item == null
		and (
			_state == NpcWorkerState.NAVIGATING_TO_DESTINATION
			or _state == NpcWorkerState.WORKING
		)
	):
		_begin_retry()
		return

	match _state:
		NpcWorkerState.IDLE, NpcWorkerState.WANDERING:
			_update_idle(delta)
		NpcWorkerState.NAVIGATING_TO_SOURCE:
			_update_source_navigation()
		NpcWorkerState.RETRY_DELAY:
			_update_retry(delta)
		NpcWorkerState.NAVIGATING_TO_DESTINATION:
			_update_destination_navigation()
		NpcWorkerState.WORKING:
			_update_work(delta)
		NpcWorkerState.RETURNING_ITEM:
			_update_return()


func _update_idle(delta: float) -> void:
	if _carrier.held_item != null:
		_carrier.throw()

	if _try_claim_work():
		return

	if not _motor.is_at_target:
		_set_state(NpcWorkerState.WANDERING)
		return

	_wander_wait -= delta
	if _wander_wait > 0.0:
		_set_state(NpcWorkerState.IDLE)
		return

	_wander_wait = WanderDelay
	var wander_target := Vector2(
		_random.randf_range(WanderBounds.position.x, WanderBounds.end.x),
		_random.randf_range(WanderBounds.position.y, WanderBounds.end.y)
	)
	if _motor.try_set_navigable_target(wander_target):
		_set_state(NpcWorkerState.WANDERING)


func _try_claim_work() -> bool:
	if _broker == null or _catalog == null:
		return false

	var task = _broker.try_claim(
		self, _capability_tags, _actor.global_position, Callable(self, "_is_task_ready")
	)
	if task == null:
		return false

	_task = task
	_return_source = null
	if task.definition.Kind == _TASK_KIND_FETCH:
		var requested_item = task.requested_item
		if requested_item == null:
			_broker.cancel(task.id)
			_enter_idle()
			return true

		_selected_definition = _roll_fetch_definition(task, requested_item)
	else:
		_selected_failure_mode = null
		_selected_definition = task.required_tool
		if _selected_definition == null:
			_navigate_to_destination()
			return true

	_try_select_source_or_wait()
	return true


func _roll_fetch_definition(task, requested_item: Resource) -> Resource:
	if _catalog == null:
		return requested_item

	var alternatives: Array = _catalog.get_available_definitions_excluding(
		requested_item, self
	)
	_selected_failure_mode = NpcFailurePolicy.select(
		task.definition,
		Personality,
		_random,
		func(mode): return (
			mode == _FAILURE_MODE_WRONG_FETCHED_ITEM and alternatives.size() > 0
		)
	)
	return (
		alternatives[_random.randi_range(0, alternatives.size() - 1)]
		if _selected_failure_mode == _FAILURE_MODE_WRONG_FETCHED_ITEM
		else requested_item
	)


func _is_task_ready(task) -> bool:
	if _catalog == null:
		return false

	var required_item = (
		task.requested_item if task.definition.Kind == _TASK_KIND_FETCH else task.required_tool
	)
	return required_item == null or _catalog.has_available_source(required_item, self)


func _try_select_source_or_wait() -> void:
	if _catalog == null or _selected_definition == null:
		_begin_retry()
		return

	var source = _catalog.try_reserve_source(_selected_definition, self, _random)
	if source == null:
		_begin_retry()
		return

	_source = source
	_source_reference_position = source.approach_position
	if not _motor.try_set_approach_target(source.source_node, _source_reference_position):
		_begin_retry()
		return
	_set_state(NpcWorkerState.NAVIGATING_TO_SOURCE)


func _update_source_navigation() -> void:
	if (
		_source == null
		or not is_instance_valid(_source.source_node)
		or not _source.is_source_available
	):
		_begin_retry()
		return

	if _source_reference_position.distance_squared_to(_source.approach_position) > 576.0:
		_source_reference_position = _source.approach_position
		if not _motor.try_set_approach_target(
			_source.source_node, _source_reference_position
		):
			_begin_retry()
			return

	if not _motor.is_at_target:
		return

	var context = InteractionContext.new(_actor, _carrier)
	var acquired_source = _source
	if not acquired_source.try_acquire(context):
		_begin_retry()
		return

	if _catalog != null:
		_catalog.release(acquired_source, self)
	_source = null
	if _task != null and _task.definition.Kind == _TASK_KIND_ACTION:
		var acquired_definition = acquired_source.available_definition
		if acquired_source.can_return_item:
			_return_source = acquired_source
		elif acquired_definition == null:
			_return_source = null
		else:
			_return_source = (
				_catalog.find_return_source(acquired_definition) if _catalog != null else null
			)
	_navigate_to_destination()


func _begin_retry() -> void:
	if _task != null and _state == NpcWorkerState.WORKING:
		_task.destination.cancel_action(InteractionContext.new(_actor, _carrier))

	if _catalog != null:
		_catalog.release(_source, self)
	_source = null
	if _task != null:
		if _broker != null:
			_broker.release(_task.id, self)
		_task = null
	_selected_definition = null
	_selected_failure_mode = null
	_motor.stop()
	_retry_remaining = RetryDelay
	_set_state(NpcWorkerState.RETRY_DELAY)


func _update_retry(delta: float) -> void:
	_retry_remaining -= delta
	if _retry_remaining <= 0.0:
		_enter_idle()


func _navigate_to_destination() -> void:
	if _task == null:
		_handle_lost_task()
		return

	_destination_reference_position = _task.destination.approach_position
	if not _motor.try_set_approach_target(_task.destination, _destination_reference_position):
		_begin_retry()
		return
	_set_state(NpcWorkerState.NAVIGATING_TO_DESTINATION)


func _update_destination_navigation() -> void:
	if _task == null:
		return

	var approach_position: Vector2 = _task.destination.approach_position
	if _destination_reference_position.distance_squared_to(approach_position) > 576.0:
		_destination_reference_position = approach_position
		if not _motor.try_set_approach_target(
			_task.destination, _destination_reference_position
		):
			_begin_retry()
			return

	var can_deliver_to_customer: bool = (
		_task.definition.Kind == _TASK_KIND_FETCH
		and _task.destination.can_receive_npc_delivery_from(_actor.global_position)
	)
	if not _motor.is_at_target and not can_deliver_to_customer:
		return
	if can_deliver_to_customer:
		_motor.stop()

	var context = InteractionContext.new(_actor, _carrier)
	if _task.definition.Kind == _TASK_KIND_FETCH:
		if not _task.destination.try_deliver(context, _task.id):
			_release_task_and_cleanup()
			return

		if _broker != null:
			_broker.complete(_task.id, self)
		_enter_idle()
		return

	if not _task.destination.try_begin_action(context, _task.id):
		_release_task_and_cleanup()
		return

	_set_state(NpcWorkerState.WORKING)


func _update_work(delta: float) -> void:
	if _task == null:
		_handle_lost_task()
		return

	var context = InteractionContext.new(_actor, _carrier)
	var run_state: int = _task.destination.update_action(context, _task.id, delta)
	if run_state == _RUN_STATE_RUNNING:
		return

	if run_state == _RUN_STATE_FAILED:
		_task.destination.cancel_action(context)
		if _broker != null:
			_broker.release(_task.id, self)
	else:
		if _broker != null:
			_broker.complete(_task.id, self)

	_task = null
	_start_returning_item()


func _release_task_and_cleanup() -> void:
	if _task != null:
		if _broker != null:
			_broker.release(_task.id, self)
		_task = null
	_start_returning_item()


func _start_returning_item() -> void:
	if _carrier.held_item == null:
		_enter_idle()
		return

	if (
		_return_source == null
		or not is_instance_valid(_return_source.source_node)
		or not _return_source.can_return_item
	):
		_carrier.throw()
		_enter_idle()
		return

	if not _motor.try_set_approach_target(
		_return_source.source_node, _return_source.approach_position
	):
		_carrier.throw()
		_enter_idle()
		return
	_set_state(NpcWorkerState.RETURNING_ITEM)


func _update_return() -> void:
	if _carrier.held_item == null:
		_return_source = null
		_motor.stop()
		_enter_idle()
		return

	if _return_source == null or not _motor.is_at_target:
		return

	var context = InteractionContext.new(_actor, _carrier)
	if _return_source.try_return(context):
		_return_source = null
		_enter_idle()
		return

	_motor.stop()
	_retry_remaining = RetryDelay


func _handle_lost_task() -> void:
	if _catalog != null:
		_catalog.release(_source, self)
	_source = null
	_task = null
	_motor.stop()
	_start_returning_item()


func _enter_idle() -> void:
	_task = null
	_source = null
	_selected_definition = null
	_selected_failure_mode = null
	_wander_wait = WanderDelay
	_set_state(NpcWorkerState.IDLE)


func _on_tasks_changed() -> void:
	if _state == NpcWorkerState.IDLE or _state == NpcWorkerState.WANDERING:
		_motor.stop()
		_set_state(NpcWorkerState.IDLE)


func _set_state(new_state: int) -> void:
	if _state == new_state:
		return

	_state = new_state
	state_changed.emit(new_state)
