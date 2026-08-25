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
	var potato_container := level.get_node("Workstations/PotatoContainer") as StaticBody2D
	var board := level.get_node("Workstations/CuttingBoard") as StaticBody2D
	var board_socket := board.get_node("PickupSocket") as Node2D
	var progress_bar := board.get_node("ProgressBar") as ProgressBar
	var knife_container := level.get_node("Workstations/KnifeContainer") as StaticBody2D

	player.global_position = Vector2(156, 430)
	await _wait_physics_frames(2)
	await _tap_interact()
	_check(_held_item_id(hold_point) == &"potato", "The potato container must supply a potato.")
	var returning_potato := hold_point.get_child(0) as Node2D
	var potato_start_position := returning_potato.global_position
	var potato_start_rotation := returning_potato.rotation
	await _tap_interact()
	_check(_held_item_id(hold_point).is_empty(), "The potato container must accept a held potato.")
	await _wait_physics_frames(4)
	_check(
		is_instance_valid(returning_potato) and returning_potato.get_parent() == potato_container,
		"A returned potato must remain under its supplier while the animation plays.",
	)
	_check(
		returning_potato.global_position.distance_to(potato_start_position) > 0.5,
		"A returned potato must move toward its supplier.",
	)
	_check(
		returning_potato.scale.length() < Vector2.ONE.length(),
		"A returned potato must shrink during its animation.",
	)
	_check(
		absf(returning_potato.rotation - potato_start_rotation) > 0.05,
		"A returned potato must spin during its animation.",
	)
	await _tap_interact()
	_check(
		_held_item_id(hold_point) == &"potato",
		"The potato container must resupply while the previous item returns.",
	)
	await _wait_physics_frames(24)
	_check(not is_instance_valid(returning_potato), "A returned potato must be freed after animating.")

	var held_potato := hold_point.get_child(0) as Node2D
	player.global_position = Vector2(736, 370)
	await _wait_physics_frames(2)
	await _tap_interact()
	_check(
		hold_point.get_child_count() == 1 and hold_point.get_child(0) == held_potato,
		"A wrong supplier must keep the held item.",
	)
	await _wait_physics_frames(12)
	_check(
		held_potato.position.is_zero_approx()
		and is_zero_approx(held_potato.rotation)
		and held_potato.scale.is_equal_approx(Vector2.ONE),
		"A wrong-item shake must settle an interrupted pickup animation at the hold point.",
	)

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
	var returning_knife := hold_point.get_child(0) as Node2D
	var knife_start_rotation := returning_knife.rotation
	await _tap_interact()
	_check(_held_item_id(hold_point).is_empty(), "The knife container must accept a held knife.")
	await _wait_physics_frames(4)
	_check(
		is_instance_valid(returning_knife) and returning_knife.get_parent() == knife_container,
		"A returned knife must remain under its supplier while the animation plays.",
	)
	_check(
		returning_knife.scale.length() < Vector2.ONE.length(),
		"A returned knife must shrink during its animation.",
	)
	_check(
		absf(returning_knife.rotation - knife_start_rotation) > 0.05,
		"A returned knife must spin during its animation.",
	)
	await _wait_physics_frames(24)
	_check(not is_instance_valid(returning_knife), "A returned knife must be freed after animating.")

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
