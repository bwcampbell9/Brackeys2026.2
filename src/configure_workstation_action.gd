class_name ConfigureWorkstationAction
extends InteractionAction

@export var PublisherPath: NodePath = NodePath("../../WorkstationTaskPublisher")

# Typed as Node2D (WorkstationTaskPublisher's own base class), not
# WorkstationTaskPublisher, since workstation_task_publisher.gd is ported by a
# different agent and may not exist yet when this script is parsed;
# duck-typed calls still resolve correctly at runtime.
var _publisher: Node2D
var _actor: Node2D
var _actor_was_physics_processing: bool = false


func _init() -> void:
	ActionId = InteractionActionIds.Configure
	Trigger = InteractionInputTrigger.HOLD


func _ready() -> void:
	_publisher = get_node_or_null(PublisherPath)
	if _publisher == null:
		push_error("ConfigureWorkstationAction requires a workstation task publisher.")


func is_available(context: InteractionContext) -> bool:
	return context.carrier.held_item == null and _publisher.can_configure


func begin(context: InteractionContext) -> bool:
	if not is_available(context) or not _publisher.begin_configuration():
		return false

	_actor = context.actor
	_actor_was_physics_processing = _actor.is_physics_processing()
	_actor.set_physics_process(false)
	if _actor is CharacterBody2D:
		(_actor as CharacterBody2D).velocity = Vector2.ZERO
	return true


func update_interaction(context: InteractionContext, delta: float) -> RunState:
	return RunState.RUNNING if _publisher.is_configuring else RunState.FAILED


func cancel(context: InteractionContext) -> void:
	# C#'s try/finally is unnecessary here: GDScript has no exceptions, so the
	# calls below either complete or push_error and return, and movement is
	# always restored immediately after.
	_publisher.cancel_configuration()
	_restore_actor_movement()


func complete(context: InteractionContext) -> void:
	_publisher.complete_configuration()
	_restore_actor_movement()


func _exit_tree() -> void:
	_restore_actor_movement()


func _restore_actor_movement() -> void:
	var actor := _actor
	if is_instance_valid(actor):
		actor.set_physics_process(_actor_was_physics_processing)
	_actor = null
