extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := MAIN_SCENE.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	await physics_frame

	var player := level.get_node("Player") as CharacterBody2D
	var hold_point := player.get_node("PickupCarrier/HoldPoint") as Node2D
	var board := level.get_node("Workstations/CuttingBoard") as StaticBody2D
	var board_socket := board.get_node("PickupSocket") as Node2D
	var progress_bar := board.get_node("ProgressBar") as ProgressBar
	_check(
		level.get_node_or_null("Workstations/KnifeContainer") != null,
		"The knife container scene tile must instantiate.",
	)

	player.global_position = Vector2(156, 430)
	await _wait_physics_frames(2)
	await _tap_interact()
	_check(_held_item_id(hold_point) == &"potato", "The potato container must supply a potato.")
	await _tap_interact()
	_check(_held_item_id(hold_point).is_empty(), "The potato container must accept a held potato.")
	await _tap_interact()
	_check(_held_item_id(hold_point) == &"potato", "The potato container must resupply a potato.")

	player.global_position = Vector2(620, 340)
	await _wait_physics_frames(2)
	await _tap_interact()
	_check(_socket_item_id(board_socket) == &"potato", "The board must store raw potato.")

	await _hold_interact(2.1)
	_check(
		_socket_item_id(board_socket) == &"potato",
		"An unavailable no-knife hold must leave the raw potato on the board.",
	)
	_check(_held_item_id(hold_point).is_empty(), "A long hold must not fall through to tap.")
	_check(not progress_bar.visible, "Unavailable processing must not show progress.")

	player.global_position = Vector2(736, 370)
	await _wait_physics_frames(2)
	await _tap_interact()
	_check(_held_item_id(hold_point) == &"knife", "The knife container must supply a knife.")
	var knife := hold_point.get_child(0) as Node2D

	player.global_position = Vector2(620, 340)
	await _wait_physics_frames(2)
	Input.action_press("interact")
	await _wait_physics_frames(35)
	_check(progress_bar.visible, "Cutting must show the progress bar.")
	_check(
		progress_bar.value > 0.0 and progress_bar.value < 100.0,
		"Cutting progress must advance continuously.",
	)
	_check(
		knife.global_position.distance_to(board.global_position) < 50.0,
		"The held knife must animate over the cutting board.",
	)
	Input.action_release("interact")
	await _wait_physics_frames(2)
	_check(_socket_item_id(board_socket) == &"potato", "Canceled cutting must keep raw potato.")
	_check(not progress_bar.visible, "Canceled cutting must hide the progress bar.")
	_check(is_zero_approx(progress_bar.value), "Canceled cutting must reset progress.")
	_check(knife.position.is_zero_approx(), "Canceled cutting must restore the held knife.")

	Input.action_press("interact")
	await _wait_physics_frames(120)
	Input.action_release("interact")
	await _wait_physics_frames(2)
	_check(
		_socket_item_id(board_socket) == &"chopped_potatoes",
		"A complete knife hold must chop the potato.",
	)
	_check(_held_item_id(hold_point) == &"knife", "Cutting must not consume the knife.")
	_check(not progress_bar.visible, "Completed cutting must hide the progress bar.")
	_check(knife.position.is_zero_approx(), "Completed cutting must restore the held knife.")

	player.global_position = Vector2(736, 370)
	await _wait_physics_frames(2)
	await _tap_interact()
	_check(_held_item_id(hold_point).is_empty(), "The knife container must accept a held knife.")

	level.queue_free()
	await process_frame
	print("knife_cutting_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _tap_interact() -> void:
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await _wait_physics_frames(2)


func _hold_interact(seconds: float) -> void:
	Input.action_press("interact")
	await _wait_physics_frames(ceili(seconds * 60.0))
	Input.action_release("interact")
	await _wait_physics_frames(2)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _held_item_id(hold_point: Node2D) -> StringName:
	return _item_id(hold_point.get_child(0)) if hold_point.get_child_count() == 1 else &""


func _socket_item_id(socket: Node2D) -> StringName:
	return _item_id(socket.get_child(0)) if socket.get_child_count() == 1 else &""


func _item_id(item: Node) -> StringName:
	var definition: Resource = item.get("Definition")
	return definition.get("Id") if definition != null else &""


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
