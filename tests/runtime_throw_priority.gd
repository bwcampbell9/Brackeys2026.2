extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PICKUP_ITEM_SCENE := preload("res://scenes/pickup_item.tscn")
const CUTTING_BOARD_SCENE := preload("res://scenes/cutting_board.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	var held_item := PICKUP_ITEM_SCENE.instantiate() as RigidBody2D
	var blocking_item := PICKUP_ITEM_SCENE.instantiate() as RigidBody2D
	world.add_child(player)
	world.add_child(held_item)
	world.add_child(blocking_item)
	root.add_child(world)

	player.global_position = Vector2.ZERO
	held_item.global_position = Vector2(0.0, -20.0)
	blocking_item.global_position = Vector2(0.0, -50.0)
	await process_frame
	await process_frame
	await _wait_physics_frames(2)

	var carrier := player.get_node("PickupCarrier")
	_check(bool(carrier.TryHold(held_item)), "The fixture must start with an item held.")
	await _wait_physics_frames(2)

	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await _wait_physics_frames(2)

	_check(
		carrier.get("HeldItem") == null,
		"An unavailable focused interaction must fall back to throwing the held item.",
	)
	_check(held_item.get_parent() == world, "The thrown item must return to the world.")
	_check(
		not held_item.linear_velocity.is_zero_approx(),
		"The thrown item must receive an impulse.",
	)

	blocking_item.global_position = Vector2(200.0, 0.0)
	var cutting_board := CUTTING_BOARD_SCENE.instantiate() as StaticBody2D
	world.add_child(cutting_board)
	cutting_board.global_position = Vector2(0.0, -50.0)
	_check(
		bool(carrier.TryHold(held_item)),
		"The fixture must hold the item again for the available-interaction check.",
	)
	await _wait_physics_frames(2)

	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await _wait_physics_frames(2)

	var socket := cutting_board.get_node("PickupSocket")
	_check(
		socket.get_child_count() == 1 and socket.get_child(0) == held_item,
		"An available mapped interaction must take priority over throwing.",
	)

	world.queue_free()
	await process_frame
	print("throw_priority_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
