class_name PickupSocket
extends Node2D

## Duck-typed IItemSource: exposes source_node, available_definition,
## is_source_available, can_return_item, approach_position, try_acquire,
## and try_return so ItemSourceCatalog can treat a socket like any other
## npc-facing item source.

signal item_changed

const ITEM_SOURCE_GROUP := &"npc_item_sources"

@export var NpcApproachOffset: Vector2 = Vector2.ZERO

var _item: PickupItem
var _is_locked: bool = false
var _is_npc_source_enabled: bool = false

var item: PickupItem:
	get:
		return _item if is_instance_valid(_item) else null

var source_node: Node2D:
	get:
		return self

var available_definition: PickupItemDefinition:
	get:
		var current := item
		return current.Definition if current != null else null

var is_source_available: bool:
	get:
		return _is_npc_source_enabled and not _is_locked and item != null

var can_return_item: bool:
	get:
		return false

var approach_position: Vector2:
	get:
		return to_global(NpcApproachOffset)

var is_locked: bool:
	get:
		return _is_locked


func _ready() -> void:
	add_to_group(ITEM_SOURCE_GROUP)


func try_store(item_to_store: PickupItem, duration: float) -> bool:
	if _is_locked or item != null:
		return false

	var attached := (
		item_to_store.try_pick_up(self, duration)
		if item_to_store.is_available
		else item_to_store.try_move_attachment(self, duration)
	)
	if not attached:
		return false

	_is_npc_source_enabled = false
	_item = item_to_store
	_item.tree_exiting.connect(_on_stored_item_exiting)
	item_changed.emit()
	return true


func try_take(destination: Node2D, duration: float) -> PickupItem:
	var current := item
	if _is_locked or current == null:
		return null

	if current.tree_exiting.is_connected(_on_stored_item_exiting):
		current.tree_exiting.disconnect(_on_stored_item_exiting)

	if not current.try_move_attachment(destination, duration):
		current.tree_exiting.connect(_on_stored_item_exiting)
		return null

	_is_npc_source_enabled = false
	_item = null
	item_changed.emit()
	return current


func take(destination: Node2D, duration: float) -> PickupItem:
	# GDScript has no out parameters: the C# `Take` wrapper and `TryTake`
	# collapse into a single item-or-null return here.
	return try_take(destination, duration)


func try_discard(item_to_discard: PickupItem) -> bool:
	if item != item_to_discard:
		return false

	if item_to_discard.tree_exiting.is_connected(_on_stored_item_exiting):
		item_to_discard.tree_exiting.disconnect(_on_stored_item_exiting)

	_is_locked = false
	_is_npc_source_enabled = false
	_item = null
	item_changed.emit()
	item_to_discard.queue_free()
	return true


func try_lock(item_to_lock: PickupItem) -> bool:
	if _is_locked or item != item_to_lock:
		return false

	_is_locked = true
	return true


func set_npc_source_enabled(enabled: bool) -> void:
	_is_npc_source_enabled = enabled and item != null


func try_acquire(context: InteractionContext) -> bool:
	return is_source_available and context.carrier.try_take(self)


func try_return(_context: InteractionContext) -> bool:
	return false


func _on_stored_item_exiting() -> void:
	var current := _item
	if current != null and current.tree_exiting.is_connected(_on_stored_item_exiting):
		current.tree_exiting.disconnect(_on_stored_item_exiting)

	_is_locked = false
	_is_npc_source_enabled = false
	_item = null
	item_changed.emit()
