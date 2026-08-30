class_name ContainerItemSource
extends Node2D

## Duck-typed IItemSource that lets NPCs request or return items directly
## through a Container's PickupContainerAction.

const ITEM_SOURCE_GROUP := &"npc_item_sources"

@export var ActionPath: NodePath = NodePath("../InteractionTarget/PickupContainerAction")
@export var ItemDefinition: PickupItemDefinition

var _action: PickupContainerAction

var source_node: Node2D:
	get:
		return self

var available_definition: PickupItemDefinition:
	get:
		return ItemDefinition

var is_source_available: bool:
	get:
		return (
			ItemDefinition != null
			and is_instance_valid(_action)
			and _action.PickupScene != null
		)

var requires_exclusive_reservation: bool:
	get:
		return false

var can_return_item: bool:
	get:
		return true

var approach_position: Vector2:
	get:
		return global_position


func _ready() -> void:
	_action = get_node_or_null(ActionPath)
	if _action == null:
		push_error("ContainerItemSource requires a valid pickup container action.")
		return
	add_to_group(ITEM_SOURCE_GROUP)


func try_acquire(context: InteractionContext) -> bool:
	return (
		context.carrier.held_item == null
		and _action.is_available(context)
		and _action.execute(context)
	)


func try_return(context: InteractionContext) -> bool:
	return (
		context.carrier.held_item != null
		and _action.is_available(context)
		and _action.execute(context)
	)
