class_name RequestWorkstationTaskAction
extends InteractionAction

@export var PublisherPath: NodePath = NodePath("../../WorkstationTaskPublisher")

# Typed as Node2D (WorkstationTaskPublisher's own base class), not
# WorkstationTaskPublisher, since workstation_task_publisher.gd is ported by a
# different agent and may not exist yet when this script is parsed;
# duck-typed calls still resolve correctly at runtime.
var _publisher: Node2D


func _init() -> void:
	ActionId = InteractionActionIds.Transfer
	Trigger = InteractionInputTrigger.TAP


func _ready() -> void:
	_publisher = get_node_or_null(PublisherPath)
	if _publisher == null:
		push_error("RequestWorkstationTaskAction requires a workstation task publisher.")


func is_available(context: InteractionContext) -> bool:
	return context.carrier.held_item == null and _publisher.can_publish_next_task


func execute(context: InteractionContext) -> bool:
	return is_available(context) and _publisher.try_publish_next_task()
