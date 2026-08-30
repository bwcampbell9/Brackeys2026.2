class_name StoveCookingPresentation
extends Node

var _sockets: Array[PickupSocket] = []
var _presented_items: Array[PickupItem] = []
var _cooking_controller: OvenCookingController
var _front_sprite: AnimatedSprite2D
var _elapsed: float = 0.0

@export var SocketPath: NodePath = NodePath("../PickupSocket")

@export var AdditionalSocketPaths: Array[NodePath] = []

@export var CookingControllerPath: NodePath = NodePath("../OvenCookingController")

@export var FrontSpritePath: NodePath = NodePath("../FrontSprite")

@export var ItemOffset: Vector2 = Vector2(22.0, -78.0)

@export_range(0.0, 32.0, 0.1, "or_greater") var BobAmplitude: float = 4.0

@export_range(0.1, 10.0, 0.1, "or_greater") var BobCyclesPerSecond: float = 2.0

@export_range(0.0, 45.0, 0.1, "or_greater") var RotationAmplitudeDegrees: float = 4.0


func _ready() -> void:
	var socket := get_node_or_null(SocketPath) as PickupSocket
	if socket == null:
		push_error("StoveCookingPresentation requires a valid pickup socket path.")
		return
	_add_socket(socket)
	for path in AdditionalSocketPaths:
		var extra_socket := get_node_or_null(path) as PickupSocket
		if extra_socket == null:
			push_error("StoveCookingPresentation requires pickup socket '%s'." % path)
			return
		_add_socket(extra_socket)

	_cooking_controller = get_node_or_null(CookingControllerPath) as OvenCookingController
	if _cooking_controller == null:
		push_error("StoveCookingPresentation requires a valid cooking controller path.")
		return
	_front_sprite = get_node_or_null(FrontSpritePath) as AnimatedSprite2D
	if _front_sprite == null:
		push_error("StoveCookingPresentation requires a valid front sprite path.")
		return
	_synchronize_presentation()


func _exit_tree() -> void:
	for socket in _sockets:
		if is_instance_valid(socket) and socket.item_changed.is_connected(_on_socket_item_changed):
			socket.item_changed.disconnect(_on_socket_item_changed)


func _process(delta: float) -> void:
	var items := _get_stored_items()
	if not _cooking_controller.is_cooking or items.is_empty():
		_reset_presentation()
		return

	if not _presentation_matches(items):
		_begin_presentation(items)

	_elapsed += delta
	var phase := _elapsed * BobCyclesPerSecond * TAU
	for index in _presented_items.size():
		var item := _presented_items[index]
		var item_phase := phase + index * 0.35
		item.position = ItemOffset + Vector2.DOWN * sin(item_phase) * BobAmplitude
		item.rotation = sin(item_phase) * RotationAmplitudeDegrees * PI / 180.0


func _add_socket(socket: PickupSocket) -> void:
	_sockets.append(socket)
	socket.item_changed.connect(_on_socket_item_changed)


func _get_stored_items() -> Array[PickupItem]:
	var items: Array[PickupItem] = []
	for socket in _sockets:
		var item := socket.item
		if item != null:
			items.append(item)
	return items


func _on_socket_item_changed() -> void:
	_synchronize_presentation()


func _synchronize_presentation() -> void:
	var items := _get_stored_items()
	if _cooking_controller.is_cooking and not items.is_empty():
		_begin_presentation(items)
		return

	_reset_presentation()


func _presentation_matches(items: Array[PickupItem]) -> bool:
	if _presented_items.size() != items.size():
		return false

	for index in items.size():
		if _presented_items[index] != items[index]:
			return false
	return true


func _begin_presentation(items: Array[PickupItem]) -> void:
	_reset_presentation()
	_presented_items.append_array(items)
	_elapsed = 0.0
	for item in _presented_items:
		item.reset_attachment_presentation()
	_front_sprite.play(&"cooking")


func _reset_presentation() -> void:
	for item in _presented_items:
		if not is_instance_valid(item):
			continue
		var parent := item.get_parent()
		if parent == null or not _sockets.has(parent):
			continue

		item.reset_attachment_presentation()
		item.position = ItemOffset

	_presented_items.clear()
	_elapsed = 0.0
	if is_instance_valid(_front_sprite):
		_front_sprite.play(&"idle")
