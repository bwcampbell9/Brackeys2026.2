class_name SlotTransferAction
extends InteractionAction

@export var SocketPath: NodePath = NodePath("../../PickupSocket")
@export var AdditionalSocketPaths: Array[NodePath] = []
@export var AcceptedItem: PickupItemDefinition
@export var TaskPublisherPath: NodePath = NodePath()
@export var CookingControllerPath: NodePath = NodePath()

var _socket: PickupSocket
var _sockets: Array[PickupSocket] = []
# Typed as the engine base classes (not WorkstationTaskPublisher /
# OvenCookingController) because those scripts are ported by other agents in
# parallel and may not exist yet when this script is parsed; duck-typed calls
# below still resolve correctly at runtime regardless of static type.
var _task_publisher: Node2D
var _cooking_controller: Node


func _init() -> void:
	ActionId = InteractionActionIds.Transfer
	Trigger = InteractionInputTrigger.TAP


func _ready() -> void:
	_socket = get_node_or_null(SocketPath)
	if _socket == null:
		push_error("SlotTransferAction requires a valid pickup socket path.")
		return
	_sockets.append(_socket)

	for path in AdditionalSocketPaths:
		var socket: PickupSocket = get_node_or_null(path)
		if socket == null:
			push_error("SlotTransferAction requires pickup socket '%s'." % path)
			return
		_sockets.append(socket)

	if not TaskPublisherPath.is_empty():
		_task_publisher = get_node_or_null(TaskPublisherPath)
		if _task_publisher == null:
			push_error("SlotTransferAction requires a valid task publisher path.")
			return

	if not CookingControllerPath.is_empty():
		_cooking_controller = get_node_or_null(CookingControllerPath)
		if _cooking_controller == null:
			push_error("SlotTransferAction requires a valid cooking controller path.")
			return


func is_available(context: InteractionContext) -> bool:
	if _task_publisher != null and not _task_publisher.is_accepting_customer_delivery:
		return false

	var held_item: PickupItem = context.carrier.held_item
	if held_item != null:
		return _find_placement_socket(held_item) != null
	return _find_take_socket() != null


func execute(context: InteractionContext) -> bool:
	var held_item: PickupItem = context.carrier.held_item
	var socket: PickupSocket = (
		_find_placement_socket(held_item) if held_item != null else _find_take_socket()
	)
	if socket == null:
		return false

	if held_item != null:
		return context.carrier.try_place(socket)
	return context.carrier.try_take(socket)


func _find_placement_socket(item: PickupItem) -> PickupSocket:
	if not _is_accepted(item) or (_cooking_controller != null and not _cooking_controller.can_accept(item)):
		return null

	for socket in _sockets:
		if not socket.is_locked and socket.item == null:
			return socket

	return null


func _find_take_socket() -> PickupSocket:
	for socket in _sockets:
		if not socket.is_locked and socket.item != null:
			return socket

	return null


func _is_accepted(item: PickupItem) -> bool:
	return AcceptedItem == null or (item.Definition != null and item.Definition.Id == AcceptedItem.Id)
