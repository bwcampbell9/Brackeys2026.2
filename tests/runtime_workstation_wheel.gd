extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PICKUP_ITEM_SCENE := preload("res://scenes/pickup_item.tscn")
const CARROT_DEFINITION := preload("res://resources/items/carrot.tres")
const CHOPPED_POTATOES_DEFINITION := preload("res://resources/items/chopped_potatoes.tres")
const CHOPPED_CARROTS_DEFINITION := preload("res://resources/items/chopped_carrots.tres")
const POTATO_DEFINITION := preload("res://resources/items/potato.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := MAIN_SCENE.instantiate()
	level.get_node("NpcWorker").process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	await process_frame
	await process_frame

	var board: Node = level.get_node("Workstations/CuttingBoard")
	var publisher: Node = board.get_node("WorkstationTaskPublisher")
	var wheel: Control = board.get_node("RequestWheelLayer/RequestWheel")
	var broker: Node = level.get_node("TaskSystem/TaskBroker")
	var initial_open_tasks := int(broker.get("open_task_count"))

	_check(
		board.get_node_or_null("ConfiguredItemIndicator") == null,
		"The workstation must not show a persistent recipe icon.",
	)
	_check(
		InputMap.action_has_event(
			&"configure_workstation",
			_joy_button(JOY_BUTTON_B),
		),
		"East face button must open the request wheel.",
	)
	_check(
		InputMap.action_has_event(
			&"recipe_wheel_previous_page",
			_joy_button(JOY_BUTTON_LEFT_SHOULDER),
		),
		"Left shoulder must select the previous recipe page.",
	)
	_check(
		InputMap.action_has_event(
			&"recipe_wheel_next_page",
			_joy_button(JOY_BUTTON_RIGHT_SHOULDER),
		),
		"Right shoulder must select the next recipe page.",
	)

	_check(
		int(publisher.get("current_task_id")) == 0,
		"The configurable workstation must start without a request.",
	)
	_check(bool(publisher.call("begin_configuration")), "The request wheel must open.")
	_check(
		bool(publisher.get("can_configure")),
		"An active wheel must remain available to its running hold interaction.",
	)
	_check(
		not bool(publisher.call("begin_configuration")),
		"A second actor must not take over an active request wheel.",
	)
	_check(wheel.visible, "The request wheel must be visible while configuring.")
	Input.action_press(&"move_right", 1.0)
	await process_frame
	Input.action_release(&"move_right")
	publisher.call("complete_configuration")
	_check(
		publisher.get("RequestedItem") == CARROT_DEFINITION,
		"Left-stick direction must select the carrot segment.",
	)
	_check(
		int(broker.get("open_task_count")) == initial_open_tasks + 1,
		"Completing selection must immediately publish one request.",
	)
	_check(not wheel.visible, "The request wheel must close after selection.")

	publisher.set("RequestMode", 0)
	var previous_task_id := int(publisher.get("current_task_id"))
	_check(bool(publisher.call("begin_configuration")), "The automatic request wheel must open.")
	Input.action_press(&"move_left", 1.0)
	await process_frame
	Input.action_release(&"move_left")
	publisher.call("complete_configuration")
	_check(
		publisher.get("RequestedItem") == POTATO_DEFINITION,
		"Left-stick direction must select the potato segment.",
	)
	_check(
		int(publisher.get("current_task_id")) != previous_task_id
		and int(publisher.get("current_task_id")) > 0,
		"Changing an automatic request must replace its task immediately.",
	)

	var available_items: Array = publisher.get("AvailableItems")
	_check(
		available_items == [POTATO_DEFINITION, CARROT_DEFINITION],
		"The cutting board wheel must only offer raw items that can be chopped.",
	)
	var many_items: Array = available_items.duplicate()
	for index in 12:
		many_items.append(available_items[index % available_items.size()])
	wheel.call(
		"Open",
		many_items,
		CARROT_DEFINITION,
		Vector2(480.0, 270.0),
	)
	await process_frame
	_check(
		wheel.visible,
		"The wheel must render a larger workstation recipe set.",
	)
	_check(
		int(wheel.get("page_count")) == 2,
		"A larger recipe set must be split into readable pages.",
	)
	Input.action_press(&"recipe_wheel_next_page")
	await process_frame
	Input.action_release(&"recipe_wheel_next_page")
	_check(
		int(wheel.get("current_page_index")) == 1,
		"Right shoulder must advance to the next recipe page.",
	)
	wheel.call("close")

	var stove := level.get_node("Stove") as StaticBody2D
	var stove_publisher := stove.get_node("WorkstationTaskPublisher") as Node
	var stove_wheel := stove.get_node("RequestWheelLayer/RequestWheel") as Control
	var stove_indicator := stove.get_node("TaskRequestIndicator") as Node2D
	_check(
		bool(stove_publisher.call("begin_configuration")),
		"The stove recipe wheel must open.",
	)
	Input.action_press(&"move_left", 1.0)
	await process_frame
	Input.action_release(&"move_left")
	_check(
		int(stove_wheel.get("entry_count")) == 3,
		"The stove wheel must expose one segment per recipe.",
	)
	_check(
		int(stove_wheel.call("get_selected_ingredient_count")) == 2,
		"The combined soup segment must show both ingredients.",
	)
	_check(
		stove_wheel.call("get_selected_ingredient", 0) == CHOPPED_POTATOES_DEFINITION
		and stove_wheel.call("get_selected_ingredient", 1) == CHOPPED_CARROTS_DEFINITION,
		"The combined soup segment must show chopped potatoes and carrots side by side.",
	)
	stove_publisher.call("complete_configuration")
	var primary_icon := stove_indicator.get_node("Icon") as Sprite2D
	var secondary_icon := stove_indicator.get_node("SecondaryIcon") as Sprite2D
	_check(
		stove_publisher.get("RequestedItem") == CHOPPED_POTATOES_DEFINITION,
		"Cooking requests must ask for an input rather than the output soup.",
	)
	_check(
		stove_indicator.visible
		and primary_icon.visible
		and secondary_icon.visible
		and primary_icon.position.x < secondary_icon.position.x,
		"The combined recipe thought bubble must show both ingredients side by side.",
	)
	var first_task_id := int(stove_publisher.get("current_task_id"))
	var potatoes := PICKUP_ITEM_SCENE.instantiate() as RigidBody2D
	potatoes.set("Definition", CHOPPED_POTATOES_DEFINITION)
	level.add_child(potatoes)
	var stove_socket := stove.get_node("ItemSpawnPoint/PickupSocket") as Node2D
	_check(
		bool(stove_socket.try_store(potatoes, 0.0)),
		"The first combined ingredient must fit the stove.",
	)
	await process_frame
	await process_frame
	_check(
		int(stove_publisher.get("current_task_id")) != first_task_id
		and stove_publisher.get("current_requested_item") == CHOPPED_CARROTS_DEFINITION,
		"Depositing the first ingredient must automatically request the second.",
	)
	_check(
		stove_indicator.visible
		and primary_icon.visible
		and secondary_icon.visible,
		"The thought bubble must keep both recipe ingredients visible while one is missing.",
	)

	level.queue_free()
	await process_frame
	print("workstation_wheel_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
