class_name PickupTransferAction
extends InteractionAction


func _init() -> void:
	ActionId = InteractionActionIds.Transfer
	Trigger = InteractionInputTrigger.TAP


func is_available(context: InteractionContext) -> bool:
	var pickup := _get_pickup()
	return pickup != null and pickup.is_transfer_available and context.carrier.held_item == null


func execute(context: InteractionContext) -> bool:
	var item := _get_pickup()
	return item != null and item.try_acquire(context)


func _get_pickup() -> PickupItem:
	return get_interaction_target().target_owner as PickupItem
