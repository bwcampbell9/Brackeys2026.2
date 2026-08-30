extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BOARD_SCENE := preload("res://scenes/cutting_board.tscn")
const POTATO_SCENE := preload("res://scenes/pickup_item.tscn")
const KNIFE_SCENE := preload("res://scenes/knife_item.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _run_definitionless_pickup_scenario()

	var world := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	var second_player := PLAYER_SCENE.instantiate() as CharacterBody2D
	var board := BOARD_SCENE.instantiate() as StaticBody2D
	var potato := POTATO_SCENE.instantiate() as RigidBody2D
	var knife := KNIFE_SCENE.instantiate() as RigidBody2D
	var second_knife := KNIFE_SCENE.instantiate() as RigidBody2D
	world.add_child(board)
	world.add_child(player)
	world.add_child(second_player)
	world.add_child(potato)
	world.add_child(knife)
	world.add_child(second_knife)
	root.add_child(world)
	board.global_position = Vector2(300, 200)
	player.global_position = Vector2(280, 260)
	second_player.global_position = Vector2(320, 260)
	await process_frame
	await process_frame
	await _wait_physics_frames(2)

	var carrier := player.get_node("PickupCarrier")
	var second_carrier := second_player.get_node("PickupCarrier")
	var second_hold_point := second_player.get_node("PickupCarrier/HoldPoint") as Node2D
	var socket := board.get_node("PickupSocket")
	var progress_bar := board.get_node("ProgressBar") as ProgressBar
	var chopping_audio := board.get_node("ChoppingAudio") as AudioStreamPlayer2D
	_check(bool(carrier.try_hold(potato)), "The fixture must let the player hold a potato.")
	_check(bool(carrier.try_place(socket)), "The fixture must place the potato on the board.")
	_check(bool(carrier.try_hold(knife)), "The fixture must let the player hold a knife.")
	_check(
		bool(second_carrier.try_hold(second_knife)),
		"The fixture must let a second actor hold another knife.",
	)
	_check(
		not bool(carrier.try_transfer_held_item_to(knife, second_carrier)),
		"A carrier must reject transferring an item it does not hold.",
	)
	_check(
		bool(carrier.try_transfer_held_item_to(potato, second_carrier)) == false,
		"A carrier must reject transfer when the destination is occupied.",
	)
	_check(
		bool(carrier.try_transfer_held_item_to(knife, second_carrier)) == false,
		"A failed transfer must leave the source unchanged.",
	)
	_check(
		bool(second_carrier.throw()),
		"The destination fixture must be able to clear its held item.",
	)
	_check(
		bool(carrier.try_transfer_held_item_to(knife, second_carrier)),
		"The first successful carrier transfer must take the item directly.",
	)
	_check(
		carrier.get("held_item") == null
			and second_carrier.get("held_item") == knife
			and knife.get_parent() == second_hold_point,
		"A direct transfer must update both carriers while keeping the item attached.",
	)
	_check(
		bool(second_carrier.try_transfer_held_item_to(knife, carrier)),
		"The transferred item must be transferable again by its new carrier.",
	)
	_check(
		bool(second_carrier.try_hold(second_knife)),
		"The waiting actor fixture must reacquire its processing tool.",
	)

	Input.action_press("interact")
	await _wait_physics_frames(50)
	_check(progress_bar.visible, "Processing must be active before the item is taken.")
	_check(
		progress_bar.value > 0.0 and progress_bar.value < 100.0,
		"Processing must have partial progress before cancellation.",
	)
	_check(chopping_audio.playing, "Active processing must play the chopping sound.")
	_check(
		socket.get_child(0).get("Definition").get("Id") == &"potato",
		"A second actor must not begin the same action and double processing speed.",
	)
	player.queue_free()
	await _wait_physics_frames(5)
	_check(
		progress_bar.visible
		and progress_bar.value > 0.0
		and progress_bar.value < 20.0,
		"The waiting actor must take ownership after the active actor exits.",
	)

	var external_hold := Node2D.new()
	world.add_child(external_hold)
	external_hold.global_position = socket.global_position
	var stolen_item: Node2D = socket.take(external_hold, 0.0)
	await _wait_physics_frames(2)
	_check(stolen_item == potato, "Taking from the socket must return the active potato.")
	_check(socket.get_child_count() == 0, "Taking the item must empty the cutting board.")
	_check(not progress_bar.visible, "Taking the item must hide processing progress.")
	_check(is_zero_approx(progress_bar.value), "Taking the item must reset processing progress.")
	_check(
		not chopping_audio.playing,
		"Taking the item must stop the chopping sound.",
	)
	_check(
		second_hold_point.get_child_count() == 1
		and second_hold_point.get_child(0) == second_knife
		and second_knife.position.is_zero_approx(),
		"Canceling through item removal must restore the held knife.",
	)

	Input.action_release("interact")
	world.queue_free()
	await process_frame
	print("processing_cancel_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _run_definitionless_pickup_scenario() -> void:
	var world := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	var item := POTATO_SCENE.instantiate() as RigidBody2D
	item.set("Definition", null)
	world.add_child(player)
	world.add_child(item)
	root.add_child(world)
	player.global_position = Vector2.ZERO
	item.global_position = Vector2(0, -40)
	await process_frame
	await process_frame
	await _wait_physics_frames(2)

	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await _wait_physics_frames(2)
	_check(
		player.get_node("PickupCarrier").get("held_item") == item,
		"A loose pickup must remain transferable without NPC source metadata.",
	)

	world.queue_free()
	await process_frame


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
