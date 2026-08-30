class_name TimedItemProcessAction
extends InteractionAction

signal processing_started
signal progress_changed(progress: float)
signal processing_canceled
signal processing_completed(item: PickupItem)

@export var SocketPath: NodePath = NodePath("../../PickupSocket")
@export var Recipe: ProcessingRecipe

var _elapsed: float = 0.0
var _socket: PickupSocket
var _active_tool: PickupItem
var _active_actor: Node2D
var _active_carrier: PickupCarrier
var _is_processing: bool = false

var progress: float:
	get:
		if Recipe == null or Recipe.Duration <= 0.0:
			return 0.0
		return clampf(_elapsed / Recipe.Duration, 0.0, 1.0)

var active_tool: PickupItem:
	get:
		return _active_tool if is_instance_valid(_active_tool) else null

var active_item: PickupItem:
	get:
		return _socket.item if _is_processing else null


func _init() -> void:
	ActionId = InteractionActionIds.Process
	Trigger = InteractionInputTrigger.HOLD


func _ready() -> void:
	_socket = get_node_or_null(SocketPath)
	if _socket == null:
		push_error("TimedItemProcessAction requires a valid pickup socket path.")
		return
	_socket.item_changed.connect(_on_socket_item_changed)


func _exit_tree() -> void:
	_clear_owner()
	if is_instance_valid(_socket) and _socket.item_changed.is_connected(_on_socket_item_changed):
		_socket.item_changed.disconnect(_on_socket_item_changed)


func is_available(context: InteractionContext) -> bool:
	var item: PickupItem = _socket.item
	return item != null and Recipe != null and Recipe.matches(item, context.carrier.held_item)


func begin(context: InteractionContext) -> bool:
	if _is_processing or not is_available(context):
		return false

	_active_tool = context.carrier.held_item
	_active_actor = context.actor
	_active_carrier = context.carrier
	_active_actor.tree_exiting.connect(_on_owner_tree_exiting)
	_active_carrier.tree_exiting.connect(_on_owner_tree_exiting)
	_elapsed = 0.0
	_is_processing = true
	processing_started.emit()
	progress_changed.emit(0.0)
	return true


func update_interaction(context: InteractionContext, delta: float) -> RunState:
	var item: PickupItem = _socket.item
	if (
		not _is_processing
		or not _is_owned_by(context)
		or item == null
		or Recipe == null
		or not is_available(context)
	):
		return RunState.FAILED

	_elapsed += delta
	progress_changed.emit(progress)
	if _elapsed < Recipe.Duration:
		return RunState.RUNNING

	if not Recipe.apply(item):
		return RunState.FAILED

	_elapsed = 0.0
	progress_changed.emit(1.0)
	_is_processing = false
	processing_completed.emit(item)
	_active_tool = null
	_clear_owner()
	return RunState.COMPLETED


func cancel(context: InteractionContext) -> void:
	if _is_owned_by(context):
		_cancel_processing()


func _on_socket_item_changed() -> void:
	if _is_processing:
		_cancel_processing()


func _cancel_processing() -> void:
	if not _is_processing:
		return

	_is_processing = false
	_elapsed = 0.0
	progress_changed.emit(0.0)
	processing_canceled.emit()
	_active_tool = null
	_clear_owner()


func _is_owned_by(context: InteractionContext) -> bool:
	return _active_actor == context.actor and _active_carrier == context.carrier


func _on_owner_tree_exiting() -> void:
	_cancel_processing()


func _clear_owner() -> void:
	if is_instance_valid(_active_actor) and _active_actor.tree_exiting.is_connected(_on_owner_tree_exiting):
		_active_actor.tree_exiting.disconnect(_on_owner_tree_exiting)
	if is_instance_valid(_active_carrier) and _active_carrier.tree_exiting.is_connected(_on_owner_tree_exiting):
		_active_carrier.tree_exiting.disconnect(_on_owner_tree_exiting)

	_active_actor = null
	_active_carrier = null
