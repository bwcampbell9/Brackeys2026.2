class_name WorkstationTaskPublisher
extends Node2D

## Group name mirrors the original C# `WorkstationTaskPublisher.PublisherGroup`
## StringName exactly; other systems look workstations up by this group.
const PUBLISHER_GROUP := &"workstation_task_publishers"

const _REQUEST_INDICATOR_OPEN_ANIMATION := &"open"

# Mirrors NpcTaskKind (see NpcTaskDefinition.Kind) integer values.
const _TASK_KIND_FETCH := 0
const _TASK_KIND_ACTION := 1

# Mirrors NpcTaskStatus (see TaskBroker.GetStatus) integer values.
const _TASK_STATUS_CLAIMED := 1

# Mirrors InteractionInputTrigger (see InteractionAction.Trigger) integer values.
const _INPUT_TRIGGER_TAP := 0

# Mirrors InteractionRunState (see InteractionAction.UpdateInteraction) integer values.
const _RUN_STATE_FAILED := 2

enum WorkstationTaskRequestMode { AUTOMATIC, PLAYER_STARTED, AUTOMATIC_ACTION }

enum CustomerOrderOutcome { CORRECT, WRONG, MISSED }

## Native Godot signal replacing the C# `CustomerOrderResolved` plain event so
## other GDScript systems (e.g. the score controller) can connect to it.
signal customer_order_resolved(outcome: CustomerOrderOutcome)

@export var SocketPath: NodePath = NodePath("../PickupSocket")

@export var InteractionTargetPath: NodePath = NodePath("../InteractionTarget")

@export var ProcessActionPath: NodePath = NodePath(
	"../InteractionTarget/ProcessItemAction"
)

@export var RequestIndicatorPath: NodePath = NodePath("../TaskRequestIndicator")

@export var RequestIndicatorAnimationPath: NodePath = NodePath(
	"../TaskRequestIndicator/Background"
)

@export var RequestIndicatorIconPath: NodePath = NodePath(
	"../TaskRequestIndicator/Icon"
)

@export var RequestIndicatorSecondaryIconPath: NodePath = NodePath(
	"../TaskRequestIndicator/SecondaryIcon"
)

@export_range(1.0, 60.0, 1.0) var RequestIndicatorOpenFramesPerSecond: float = 24.0

@export var RequestWheelPath: NodePath = NodePath(
	"../RequestWheelLayer/RequestWheel"
)

@export var CookingControllerPath: NodePath = NodePath()

@export var RequestMode: WorkstationTaskRequestMode = WorkstationTaskRequestMode.AUTOMATIC:
	set(value):
		if _request_mode == value:
			return
		_request_mode = value
		if is_node_ready():
			_reconcile_task()
	get:
		return _request_mode

@export var FetchTask: NpcTaskDefinition = null

@export var ActionTask: NpcTaskDefinition = null

@export var RequestedItem: PickupItemDefinition = null

@export var AvailableItems: Array[PickupItemDefinition] = []

@export var ConsumeDeliveredItem: bool = false

@export var ConsumerVisualPath: NodePath = NodePath("../Sprite2D")

@export_range(0.1, 3.0, 0.05, "or_greater") var ConsumptionDuration: float = 0.6

@export var OrderTimerBarPath: NodePath = NodePath(
	"../TaskRequestIndicator/TimerBar"
)

@export_range(1.0, 300.0, 1.0, "or_greater") var OrderDurationSeconds: float = 30.0

@export_range(0.0, 60.0, 0.5, "or_greater") var OrderCooldownSeconds: float = 5.0

@export_range(1.0, 100.0, 1.0, "or_greater", "suffix:px") var NpcDeliveryRange: float = 34.0

var _broker  # TaskBroker (duck-typed; ported under the NPC systems slice)
var _socket  # PickupSocket (duck-typed; ported under the items slice)
var _interaction_target  # InteractionTarget (duck-typed; ported under the interaction slice)
var _process_action  # TimedItemProcessAction (duck-typed; ported under the interaction slice)
var _cooking_controller  # OvenCookingController (duck-typed; ported under the cooking slice)
var _request_indicator: Node2D
var _request_indicator_animation: AnimatedSprite2D
var _request_indicator_icon: Sprite2D
var _request_indicator_secondary_icon: Sprite2D
var _request_wheel  # WorkstationRequestWheel (duck-typed; ported under the cooking slice)
var _consumer_visual: Node2D
var _consumption_tween: Tween
var _consumer_rest_position: Vector2 = Vector2.ZERO
var _consumer_rest_scale: Vector2 = Vector2.ONE
var _generation: int = 0
var _current_task_id: int = 0
var _executing_task_id: int = 0
var _action_finished: bool = false
var _is_consuming: bool = false
var _is_configuring: bool = false
var _current_requested_item: PickupItemDefinition = null
var _selected_cooking_recipe: CookingRecipe = null
var _request_mode: WorkstationTaskRequestMode = WorkstationTaskRequestMode.AUTOMATIC
var _order_timer_bar: Sprite2D
var _order_time_remaining: float = 0.0
var _order_cooldown_remaining: float = 0.0
var _customer_requests: Array[PickupItemDefinition] = []
var _order_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _minimum_order_cooldown_seconds: float = 0.0
var _maximum_order_cooldown_seconds: float = 0.0

var approach_position: Vector2:
	get:
		return global_position

var current_task_id: int:
	get:
		return _current_task_id

var current_requested_item: PickupItemDefinition:
	get:
		return _current_requested_item

var is_consuming: bool:
	get:
		return _is_consuming

var is_configuring: bool:
	get:
		return _is_configuring

var order_cooldown_remaining: float:
	get:
		return _order_cooldown_remaining

var is_accepting_customer_delivery: bool:
	get:
		return (
			ConsumeDeliveredItem
			and not _is_consuming
			and _current_task_id != 0
			and _order_time_remaining > 0.0
		)

var can_configure: bool:
	get:
		if _is_consuming:
			return false
		if _cooking_controller != null:
			return (
				not _cooking_controller.has_any_item
				and _cooking_controller.Recipes.size() > 0
			)
		return _socket.item == null and AvailableItems.size() > 0

var can_publish_next_task: bool:
	get:
		return (
			(
				RequestMode == WorkstationTaskRequestMode.PLAYER_STARTED
				or (
					RequestMode == WorkstationTaskRequestMode.AUTOMATIC_ACTION
					and _socket.item == null
				)
			)
			and _broker != null
			and _current_task_id == 0
			and _try_get_pending_task() != null
		)


func can_receive_npc_delivery_from(global_pos: Vector2) -> bool:
	return (
		is_accepting_customer_delivery
		and _interaction_target.global_position.distance_squared_to(global_pos)
			<= NpcDeliveryRange * NpcDeliveryRange
	)


func _ready() -> void:
	_order_random.randomize()
	_socket = get_node_or_null(SocketPath)
	if _socket == null:
		push_error("WorkstationTaskPublisher requires a valid pickup socket.")
		return
	_interaction_target = get_node_or_null(InteractionTargetPath)
	if _interaction_target == null:
		push_error("WorkstationTaskPublisher requires a valid interaction target.")
		return
	_process_action = get_node_or_null(ProcessActionPath)
	if ActionTask != null and _process_action == null:
		push_error(
			"A workstation with an action task requires a timed process action."
		)
		return
	_request_indicator = get_node_or_null(RequestIndicatorPath)
	if _request_indicator == null:
		push_error("WorkstationTaskPublisher requires a request indicator.")
		return
	_request_indicator_animation = get_node_or_null(RequestIndicatorAnimationPath)
	if _request_indicator_animation == null:
		push_error(
			"WorkstationTaskPublisher requires an animated request indicator background."
		)
		return
	_request_indicator_icon = get_node_or_null(RequestIndicatorIconPath)
	if _request_indicator_icon == null:
		push_error("WorkstationTaskPublisher requires a request indicator icon.")
		return
	_request_indicator_secondary_icon = get_node_or_null(
		RequestIndicatorSecondaryIconPath
	)
	if _request_indicator_secondary_icon == null:
		push_error(
			"WorkstationTaskPublisher requires a secondary request indicator icon."
		)
		return
	_request_wheel = get_node_or_null(RequestWheelPath)
	if not CookingControllerPath.is_empty():
		_cooking_controller = get_node_or_null(CookingControllerPath)
		if _cooking_controller == null:
			push_error("WorkstationTaskPublisher requires a valid cooking controller.")
			return
		_selected_cooking_recipe = _cooking_controller.SelectedCookingRecipe
		if (
			_selected_cooking_recipe != null
			and _selected_cooking_recipe.Ingredients.size() > 0
		):
			RequestedItem = _selected_cooking_recipe.Ingredients[0]

	if ConsumeDeliveredItem:
		_consumer_visual = get_node_or_null(ConsumerVisualPath)
		if _consumer_visual == null:
			push_error("A consuming workstation requires a consumer visual.")
			return
		_consumer_rest_position = _consumer_visual.position
		_consumer_rest_scale = _consumer_visual.scale
		_order_timer_bar = get_node_or_null(OrderTimerBarPath)
		if _order_timer_bar == null:
			push_error("A consuming workstation requires an order timer bar.")
			return
		_order_timer_bar.visible = false

	if _cooking_controller != null:
		_cooking_controller.cooking_state_changed.connect(_on_cooking_state_changed)
	else:
		_socket.item_changed.connect(_on_socket_item_changed)
	if _process_action != null:
		_process_action.processing_completed.connect(_on_processing_completed)
	add_to_group(PUBLISHER_GROUP)
	_clear_request_indicator()


func _process(delta: float) -> void:
	if not ConsumeDeliveredItem:
		return

	if _order_cooldown_remaining > 0.0:
		_order_cooldown_remaining = maxf(0.0, _order_cooldown_remaining - delta)
		if is_zero_approx(_order_cooldown_remaining) and not _is_consuming:
			_reconcile_task()
		return

	if _is_consuming:
		return

	if _current_task_id == 0 or _order_time_remaining <= 0.0:
		return

	_order_time_remaining = maxf(0.0, _order_time_remaining - delta)
	_update_order_timer_bar()
	if is_zero_approx(_order_time_remaining):
		_resolve_missed_order()


func _exit_tree() -> void:
	if _cooking_controller != null and is_instance_valid(_cooking_controller):
		_cooking_controller.cooking_state_changed.disconnect(_on_cooking_state_changed)
	elif is_instance_valid(_socket):
		_socket.item_changed.disconnect(_on_socket_item_changed)
	if _process_action != null and is_instance_valid(_process_action):
		_process_action.processing_completed.disconnect(_on_processing_completed)
	if _broker != null and _current_task_id != 0:
		_broker.cancel(_current_task_id)


func configure(broker) -> void:
	if _broker == broker:
		return

	var is_initial_configuration := _broker == null
	if _broker != null and _current_task_id != 0:
		_broker.cancel(_current_task_id)
		_current_task_id = 0

	_broker = broker
	if (
		is_initial_configuration
		and ConsumeDeliveredItem
		and _customer_requests.size() > 0
	):
		_start_order_cooldown()
		return

	_reconcile_task()


func configure_customer_orders(
	requests: Array[PickupItemDefinition],
	minimum_cooldown_seconds: float,
	maximum_cooldown_seconds: float,
	order_duration_seconds: float
) -> void:
	if not ConsumeDeliveredItem:
		push_error("Only consuming publishers can configure customer orders.")
		return
	if requests.is_empty():
		push_error("Customer orders require at least one request.")
		return
	if (
		minimum_cooldown_seconds < 0.0
		or maximum_cooldown_seconds < minimum_cooldown_seconds
	):
		push_error("Customer order cooldowns require 0 <= minimum <= maximum.")
		return

	_customer_requests.clear()
	for request in requests:
		if request == null:
			push_error("Customer order requests cannot contain null entries.")
			return
		if _customer_requests.has(request):
			continue
		_customer_requests.append(request)
	_minimum_order_cooldown_seconds = minimum_cooldown_seconds
	_maximum_order_cooldown_seconds = maximum_cooldown_seconds
	OrderDurationSeconds = maxf(0.1, order_duration_seconds)

	if _broker != null:
		_generation += 1
		_cancel_current_task()
		_reconcile_task()


func begin_configuration() -> bool:
	if _is_configuring or not can_configure or _request_wheel == null:
		return false

	_is_configuring = true
	var center: Vector2 = get_parent().get_global_transform_with_canvas().origin
	if _cooking_controller != null:
		_request_wheel.open_recipes(
			_cooking_controller.Recipes, _selected_cooking_recipe, center
		)
	else:
		_request_wheel.open(AvailableItems, RequestedItem, center)
	return true


func cancel_configuration() -> void:
	if not _is_configuring:
		return

	_is_configuring = false
	if _request_wheel != null:
		_request_wheel.close()


func complete_configuration() -> void:
	if not _is_configuring:
		return

	var selected_item: PickupItemDefinition = (
		_request_wheel.selected_item if _request_wheel != null else null
	)
	var selected_recipe: CookingRecipe = (
		_request_wheel.selected_recipe if _request_wheel != null else null
	)
	_is_configuring = false
	if _request_wheel != null:
		_request_wheel.close()
	if selected_item == null:
		return

	if _cooking_controller != null:
		var previous_output_id = _output_id(_selected_cooking_recipe)
		var candidate_output_id = _output_id(selected_recipe)
		if (
			selected_recipe == null
			or selected_recipe.Ingredients.is_empty()
			or (
				previous_output_id != candidate_output_id
				and not _cooking_controller.try_select_recipe(selected_recipe)
			)
		):
			return

		if previous_output_id != candidate_output_id:
			_selected_cooking_recipe = selected_recipe
			RequestedItem = selected_recipe.Ingredients[0]
			_generation += 1
			_cancel_current_task()
		_publish_pending_task()
		return

	var current_id = RequestedItem.Id if RequestedItem != null else null
	if current_id != selected_item.Id:
		RequestedItem = selected_item
		_generation += 1
		_cancel_current_task()

	_publish_pending_task()


func try_publish_next_task() -> bool:
	return can_publish_next_task and _publish_pending_task()


func try_deliver(context, task_id: int) -> bool:
	if not _can_execute(task_id, _TASK_KIND_FETCH):
		return false

	var transfer = _interaction_target.find_action(
		InteractionActionIds.Transfer, _INPUT_TRIGGER_TAP, context
	)
	if transfer == null:
		return false

	_executing_task_id = task_id
	var result: bool = transfer.execute(context)
	_executing_task_id = 0
	return result


func try_begin_action(context, task_id: int) -> bool:
	return (
		_process_action != null
		and _can_execute(task_id, _TASK_KIND_ACTION)
		and _process_action.begin(context)
	)


func update_action(context, task_id: int, delta: float) -> int:
	if _process_action == null or not _can_execute(task_id, _TASK_KIND_ACTION):
		return _RUN_STATE_FAILED

	_executing_task_id = task_id
	var result: int = _process_action.update_interaction(context, delta)
	_executing_task_id = 0
	return result


func cancel_action(context) -> void:
	if _process_action != null:
		_process_action.cancel(context)


func _can_execute(task_id: int, kind: int) -> bool:
	if _broker == null or _current_task_id != task_id:
		return false
	if _broker.get_status(task_id) != _TASK_STATUS_CLAIMED:
		return false
	if kind == _TASK_KIND_FETCH:
		if _cooking_controller != null:
			return _cooking_controller.get_first_missing_ingredient() != null
		return _socket.item == null
	return _socket.item != null


func _on_cooking_state_changed() -> void:
	_generation += 1
	_action_finished = false
	_reconcile_task()


func _on_socket_item_changed() -> void:
	_generation += 1
	_action_finished = false
	_socket.set_npc_source_enabled(false)
	if _try_begin_consumption():
		return
	_reconcile_task()


func _on_processing_completed(item) -> void:
	_action_finished = true
	_socket.set_npc_source_enabled(true)
	_reconcile_task()


func _reconcile_task() -> void:
	if _broker == null or _is_consuming:
		return

	var previous_task_id := _current_task_id
	_current_task_id = 0
	_clear_request_indicator()
	if previous_task_id != 0 and (
		previous_task_id != _executing_task_id or _socket.item == null
	):
		_broker.cancel(previous_task_id)

	if (
		RequestMode == WorkstationTaskRequestMode.AUTOMATIC
		or (
			RequestMode == WorkstationTaskRequestMode.AUTOMATIC_ACTION
			and _socket.item != null
		)
		or (
			_cooking_controller != null
			and _cooking_controller.has_any_item
			and _cooking_controller.get_first_missing_ingredient() != null
		)
	):
		_publish_pending_task()


func _cancel_current_task() -> void:
	if _broker != null and _current_task_id != 0:
		_broker.cancel(_current_task_id)

	_current_task_id = 0
	_clear_request_indicator()


func _publish_pending_task() -> bool:
	if _broker == null or _current_task_id != 0 or _order_cooldown_remaining > 0.0:
		return false

	_choose_customer_request()
	var pending = _try_get_pending_task()
	if pending == null or pending["task"] == null:
		return false

	var current_request: PickupItemDefinition = (
		pending["requested_item"]
		if pending["requested_item"] != null
		else pending["required_tool"]
	)
	if current_request == null:
		return false

	_current_task_id = _broker.publish(
		pending["task"], self, _generation, pending["requested_item"], pending["required_tool"]
	)
	_show_request_indicator(current_request)
	if ConsumeDeliveredItem:
		_order_time_remaining = maxf(0.01, OrderDurationSeconds)
		_update_order_timer_bar()
		if _order_timer_bar != null:
			_order_timer_bar.visible = true
	return true


func _choose_customer_request() -> void:
	if (
		not ConsumeDeliveredItem
		or _customer_requests.is_empty()
		or _socket.item != null
	):
		return

	RequestedItem = _customer_requests[
		_order_random.randi_range(0, _customer_requests.size() - 1)
	]


func _try_get_pending_task():
	if _cooking_controller != null:
		var missing_ingredient = _cooking_controller.get_first_missing_ingredient()
		if FetchTask == null or missing_ingredient == null:
			return null
		return {
			"task": FetchTask,
			"requested_item": missing_ingredient,
			"required_tool": null,
		}

	var item = _socket.item
	if item == null:
		if FetchTask == null or RequestedItem == null:
			return null
		return {
			"task": FetchTask,
			"requested_item": RequestedItem,
			"required_tool": null,
		}

	var recipe = _process_action.Recipe if _process_action != null else null
	if (
		ActionTask == null
		or _action_finished
		or recipe == null
		or not recipe.matches(item)
	):
		return null

	var required_tool = recipe.RequiredTool
	if required_tool == null:
		return null
	return {"task": ActionTask, "requested_item": null, "required_tool": required_tool}


func _show_request_indicator(item: PickupItemDefinition) -> void:
	_current_requested_item = item
	if (
		_selected_cooking_recipe != null
		and _selected_cooking_recipe.Ingredients.size() > 1
	):
		_apply_request_icon(
			_request_indicator_icon,
			_selected_cooking_recipe.Ingredients[0],
			Vector2(-9.0, 0.0),
			0.45
		)
		_apply_request_icon(
			_request_indicator_secondary_icon,
			_selected_cooking_recipe.Ingredients[1],
			Vector2(9.0, 0.0),
			0.45
		)
		_request_indicator_secondary_icon.visible = true
	else:
		_apply_request_icon(_request_indicator_icon, item, Vector2.ZERO, 0.65)
		_request_indicator_secondary_icon.visible = false
	_request_indicator.visible = true
	_request_indicator_animation.stop()
	_request_indicator_animation.frame = 0
	_request_indicator_animation.play(
		_REQUEST_INDICATOR_OPEN_ANIMATION, RequestIndicatorOpenFramesPerSecond
	)


static func _apply_request_icon(
	icon: Sprite2D,
	item: PickupItemDefinition,
	pos: Vector2,
	scale_multiplier: float
) -> void:
	icon.position = pos
	icon.texture = item.Texture
	icon.modulate = item.Modulate
	icon.scale = item.VisualScale * scale_multiplier


func _clear_request_indicator() -> void:
	_current_requested_item = null
	if is_instance_valid(_request_indicator):
		_request_indicator.visible = false
	if is_instance_valid(_request_indicator_icon):
		_request_indicator_icon.texture = null
		_request_indicator_icon.position = Vector2.ZERO
	if is_instance_valid(_request_indicator_secondary_icon):
		_request_indicator_secondary_icon.texture = null
		_request_indicator_secondary_icon.visible = false
	if _order_timer_bar != null and is_instance_valid(_order_timer_bar):
		_order_timer_bar.visible = false
	if is_instance_valid(_request_indicator_animation):
		_request_indicator_animation.stop()
		_request_indicator_animation.frame = 0


func _try_begin_consumption() -> bool:
	var item = _socket.item
	if (
		not ConsumeDeliveredItem
		or _is_consuming
		or not is_accepting_customer_delivery
		or item == null
		or item.Definition == null
		or RequestedItem == null
		or not _socket.try_lock(item)
	):
		return false

	var previous_task_id := _current_task_id
	_current_task_id = 0
	_clear_request_indicator()
	if _broker != null and previous_task_id != 0 and previous_task_id != _executing_task_id:
		_broker.cancel(previous_task_id)

	var outcome: CustomerOrderOutcome = (
		CustomerOrderOutcome.CORRECT
		if item.Definition.Id == RequestedItem.Id
		else CustomerOrderOutcome.WRONG
	)
	_order_time_remaining = 0.0
	_is_consuming = true
	_start_order_cooldown()
	customer_order_resolved.emit(outcome)
	_play_consumption(item)
	return true


func _play_consumption(item) -> void:
	if _consumer_visual == null:
		push_error("A consuming workstation requires a consumer visual.")
		return

	var visual: Node2D = _consumer_visual
	var phase_duration := ConsumptionDuration * 0.5
	var squashed_scale := Vector2(
		_consumer_rest_scale.x * 1.15, _consumer_rest_scale.y * 0.82
	)
	var bob_position := _consumer_rest_position + Vector2.UP * 6.0

	if _consumption_tween != null:
		_consumption_tween.kill()
	var food_tween: Tween = item.start_motion_tween()
	var food_scale_tweener := food_tween.tween_property(
		item, "scale", Vector2.ZERO, ConsumptionDuration
	)
	food_scale_tweener.set_trans(Tween.TRANS_QUAD)
	food_scale_tweener.set_ease(Tween.EASE_IN)

	var scale_tween := create_tween()
	_consumption_tween = scale_tween
	var squash_tweener := scale_tween.tween_property(
		visual, "scale", squashed_scale, phase_duration
	)
	squash_tweener.set_trans(Tween.TRANS_QUAD)
	squash_tweener.set_ease(Tween.EASE_IN)
	var settle_scale_tweener := scale_tween.tween_property(
		visual, "scale", _consumer_rest_scale, phase_duration
	)
	settle_scale_tweener.set_trans(Tween.TRANS_BACK)
	settle_scale_tweener.set_ease(Tween.EASE_OUT)
	scale_tween.tween_callback(_finish_consumption.bind(item))

	var bob_tween := create_tween()
	var bob_up_tweener := bob_tween.tween_property(
		visual, "position", bob_position, phase_duration
	)
	bob_up_tweener.set_trans(Tween.TRANS_QUAD)
	bob_up_tweener.set_ease(Tween.EASE_IN)
	var bob_settle_tweener := bob_tween.tween_property(
		visual, "position", _consumer_rest_position, phase_duration
	)
	bob_settle_tweener.set_trans(Tween.TRANS_BACK)
	bob_settle_tweener.set_ease(Tween.EASE_OUT)


func _finish_consumption(item) -> void:
	if _consumer_visual != null and is_instance_valid(_consumer_visual):
		_consumer_visual.position = _consumer_rest_position
		_consumer_visual.scale = _consumer_rest_scale

	if not _socket.try_discard(item):
		_is_consuming = false
		_consumption_tween = null
		push_error("A consuming workstation lost its locked delivered item.")
		return

	_is_consuming = false
	_consumption_tween = null
	if is_zero_approx(_order_cooldown_remaining):
		_reconcile_task()


func _resolve_missed_order() -> void:
	_generation += 1
	_cancel_current_task()
	customer_order_resolved.emit(CustomerOrderOutcome.MISSED)
	_start_order_cooldown()


func _start_order_cooldown() -> void:
	_order_cooldown_remaining = (
		_order_random.randf_range(
			_minimum_order_cooldown_seconds, _maximum_order_cooldown_seconds
		)
		if _customer_requests.size() > 0
		else maxf(0.0, OrderCooldownSeconds)
	)
	if is_zero_approx(_order_cooldown_remaining) and not _is_consuming:
		_reconcile_task()


func _update_order_timer_bar() -> void:
	if _order_timer_bar == null:
		return

	var frame_count: int = _order_timer_bar.hframes * _order_timer_bar.vframes
	var duration := maxf(0.01, OrderDurationSeconds)
	var elapsed_ratio := 1.0 - (_order_time_remaining / duration)
	_order_timer_bar.frame = clampi(floori(elapsed_ratio * frame_count), 0, frame_count - 1)


static func _output_id(recipe: CookingRecipe):
	return recipe.Output.Id if recipe != null and recipe.Output != null else null
