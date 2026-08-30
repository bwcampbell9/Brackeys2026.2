## Holds, transfers, throws, and stores a single [PickupItem] on behalf of a
## character. Implements the [IItemSource]-adjacent duck-typed
## [code]try_take[/code]/[code]try_store[/code] handshake expected by
## [PickupSocket].
class_name PickupCarrier
extends Node2D

var _hold_point: Node2D
var _pickup_audio: AudioStreamPlayer2D
var _throw_audio: AudioStreamPlayer2D
var _held_item: PickupItem

@export_range(0.01, 2.0, 0.01, "or_greater") var PickupDuration: float = 0.2
@export_range(0.0, 2000.0, 1.0, "or_greater") var ThrowForce: float = 650.0

var facing_direction: Vector2 = Vector2.UP:
	set(value):
		if value.is_zero_approx():
			return

		facing_direction = value.normalized()
		rotation = facing_direction.angle() + PI / 2.0

var held_item: PickupItem:
	get:
		return _held_item if is_instance_valid(_held_item) else null


func _ready() -> void:
	_hold_point = get_node("HoldPoint") as Node2D
	_pickup_audio = get_node_or_null("../PickupAudio") as AudioStreamPlayer2D
	_throw_audio = get_node_or_null("../ThrowAudio") as AudioStreamPlayer2D


func try_hold(item: PickupItem) -> bool:
	if held_item != null or not item.try_pick_up(_hold_point, PickupDuration):
		return false

	_held_item = item
	_play_pickup_audio()
	return true


func try_transfer_held_item_to(item: PickupItem, destination: PickupCarrier) -> bool:
	if held_item != item or destination.held_item != null or not try_release_held_item(item):
		return false

	if not item.try_move_attachment(destination._hold_point, PickupDuration):
		_held_item = item
		return false

	destination._held_item = item
	return true


func try_place(socket: PickupSocket) -> bool:
	var item := held_item
	if item == null or not socket.try_store(item, PickupDuration):
		return false

	_held_item = null
	return true


## [param socket]'s try_take must return the taken [PickupItem], or
## [code]null[/code] on failure; GDScript has no C# "out" parameters, so the
## original bool-plus-out-value handshake collapses to a single nullable
## return value.
func try_take(socket: PickupSocket) -> bool:
	if held_item != null:
		return false

	var item: PickupItem = socket.try_take(_hold_point, PickupDuration)
	if item == null:
		return false

	_held_item = item
	_play_pickup_audio()
	return true


func throw() -> bool:
	var item := held_item
	if item == null:
		return false

	_held_item = null
	item.throw(facing_direction * ThrowForce)
	_play_throw_audio()
	return true


func try_release_held_item(item: PickupItem) -> bool:
	if held_item != item:
		return false
	_held_item = null
	return true


func _play_pickup_audio() -> void:
	if is_instance_valid(_pickup_audio):
		_pickup_audio.play()


func _play_throw_audio() -> void:
	if is_instance_valid(_throw_audio):
		_throw_audio.play()
