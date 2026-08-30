class_name PickupContainerAction
extends InteractionAction

signal item_transferred

@export var PickupScene: PackedScene
@export var AcceptedItem: PickupItemDefinition
@export_range(0.05, 2, 0.01, "or_greater") var ReturnDuration: float = 0.35
@export_range(0, 8, 0.25, "or_greater") var ReturnSpinTurns: float = 1.5


func _init() -> void:
	ActionId = InteractionActionIds.Transfer
	Trigger = InteractionInputTrigger.TAP


func is_available(context: InteractionContext) -> bool:
	return context.carrier.held_item != null or PickupScene != null


func execute(context: InteractionContext) -> bool:
	var container: Node2D = get_interaction_target().target_owner
	var held_item: PickupItem = context.carrier.held_item
	if held_item != null:
		if AcceptedItem != null and held_item.Definition == AcceptedItem:
			if ReturnDuration < 0.0:
				push_error("%s requires a non-negative return duration." % name)
				return false

			if not context.carrier.try_release_held_item(held_item):
				return false

			held_item.animate_return_to(container, ReturnDuration, ReturnSpinTurns)
			item_transferred.emit()
			return true

		held_item.play_shake()
		return true

	if PickupScene == null:
		return false

	var item: PickupItem = PickupScene.instantiate()
	context.world_item_root.add_child(item)
	item.global_position = container.global_position
	if context.carrier.try_hold(item):
		item_transferred.emit()
		return true

	item.queue_free()
	return false
