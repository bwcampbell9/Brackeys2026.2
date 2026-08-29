extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CARROT_DEFINITION := preload("res://resources/items/carrot.tres")
const CHOPPED_POTATOES_DEFINITION := preload("res://resources/items/chopped_potatoes.tres")

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
	var initial_open_tasks := int(broker.get("OpenTaskCount"))

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
		int(publisher.get("CurrentTaskId")) == 0,
		"The configurable workstation must start without a request.",
	)
	_check(bool(publisher.call("BeginConfiguration")), "The request wheel must open.")
	_check(
		bool(publisher.get("CanConfigure")),
		"An active wheel must remain available to its running hold interaction.",
	)
	_check(
		not bool(publisher.call("BeginConfiguration")),
		"A second actor must not take over an active request wheel.",
	)
	_check(wheel.visible, "The request wheel must be visible while configuring.")
	Input.action_press(&"move_right", 1.0)
	await process_frame
	Input.action_release(&"move_right")
	publisher.call("CompleteConfiguration")
	_check(
		publisher.get("RequestedItem") == CARROT_DEFINITION,
		"Left-stick direction must select the carrot segment.",
	)
	_check(
		int(broker.get("OpenTaskCount")) == initial_open_tasks + 1,
		"Completing selection must immediately publish one request.",
	)
	_check(not wheel.visible, "The request wheel must close after selection.")

	publisher.set("RequestMode", 0)
	var previous_task_id := int(publisher.get("CurrentTaskId"))
	_check(bool(publisher.call("BeginConfiguration")), "The automatic request wheel must open.")
	Input.action_press(&"move_left", 1.0)
	await process_frame
	Input.action_release(&"move_left")
	publisher.call("CompleteConfiguration")
	_check(
		publisher.get("RequestedItem") == CHOPPED_POTATOES_DEFINITION,
		"Left-stick direction must select the chopped-potatoes segment.",
	)
	_check(
		int(publisher.get("CurrentTaskId")) != previous_task_id
		and int(publisher.get("CurrentTaskId")) > 0,
		"Changing an automatic request must replace its task immediately.",
	)

	var available_items: Array = publisher.get("AvailableItems")
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
		int(wheel.get("PageCount")) == 2,
		"A larger recipe set must be split into readable pages.",
	)
	Input.action_press(&"recipe_wheel_next_page")
	await process_frame
	Input.action_release(&"recipe_wheel_next_page")
	_check(
		int(wheel.get("CurrentPageIndex")) == 1,
		"Right shoulder must advance to the next recipe page.",
	)
	wheel.call("Close")

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
