extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PICKUP_SCENE := preload("res://scenes/pickup_item.tscn")
const BABY_SCENE := preload("res://scenes/baby_pickup_item.tscn")
const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_pickup_push()
	await _check_baby_push()
	await _check_upright_foot_hitbox()
	await _check_character_push()
	await _check_main_scene_push_order()
	print("body_pushing_runtime=", "failed" if _failed else "passed")
	quit(1 if _failed else 0)


func _check_pickup_push() -> void:
	var world := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	var pickup := PICKUP_SCENE.instantiate() as RigidBody2D
	world.add_child(player)
	world.add_child(pickup)
	root.add_child(world)
	player.global_position = Vector2.ZERO
	pickup.global_position = Vector2(30, 19)
	var start := pickup.global_position
	for _frame in range(3):
		await physics_frame
	Input.action_press(&"move_right", 1.0)
	var previous_x := pickup.global_position.x
	var backward_steps := 0
	var max_step := 0.0
	for _frame in range(30):
		await physics_frame
		var step := pickup.global_position.x - previous_x
		if step < -0.01:
			backward_steps += 1
		max_step = maxf(max_step, absf(step))
		previous_x = pickup.global_position.x
	Input.action_release(&"move_right")
	await physics_frame
	_check(
		pickup.global_position.distance_to(start) > 80.0,
		"The player must easily push pickup items.",
	)
	_check(backward_steps == 0, "A pushed pickup must not jitter backward.")
	_check(max_step < 5.0, "A pushed pickup must move smoothly between ticks.")
	world.queue_free()
	await process_frame


func _check_baby_push() -> void:
	var world := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	var baby := BABY_SCENE.instantiate() as RigidBody2D
	baby.set("MinimumPauseDuration", 5.0)
	baby.set("MaximumPauseDuration", 5.0)
	world.add_child(player)
	world.add_child(baby)
	root.add_child(world)
	player.global_position = Vector2.ZERO
	baby.global_position = Vector2(30, 19)
	var start := baby.global_position
	for _frame in range(3):
		await physics_frame
	Input.action_press(&"move_right", 1.0)
	for _frame in range(30):
		await physics_frame
	Input.action_release(&"move_right")
	await physics_frame
	_check(
		baby.global_position.distance_to(start) > 80.0,
		"The baby must retain external push velocity while paused.",
	)
	world.queue_free()
	await process_frame


func _check_upright_foot_hitbox() -> void:
	var world := Node2D.new()
	var customer := CUSTOMER_SCENE.instantiate() as CharacterBody2D
	customer.get_node("CustomerWanderController").process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(customer)
	root.add_child(world)
	customer.global_position = Vector2.ZERO
	for _frame in range(3):
		await physics_frame
	customer.get_node("NpcMotor").call("SetTarget", Vector2(100, 0))
	for _frame in range(3):
		await physics_frame
	var collision := customer.get_node("CollisionShape2D") as CollisionShape2D
	_check(
		is_zero_approx(customer.rotation),
		"NPC bodies must remain upright while moving.",
	)
	_check(
		collision.global_position.distance_to(customer.global_position) < 0.1,
		"NPC collision and navigation origins must remain aligned at the feet.",
	)
	world.queue_free()
	await process_frame


func _check_character_push() -> void:
	var world := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	var customer := CUSTOMER_SCENE.instantiate() as CharacterBody2D
	customer.get_node("CustomerWanderController").process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(player)
	world.add_child(customer)
	root.add_child(world)
	player.global_position = Vector2.ZERO
	customer.global_position = Vector2(24, 19)
	var start := customer.global_position
	for _frame in range(3):
		await physics_frame
	Input.action_press(&"move_right", 1.0)
	var previous_x := customer.global_position.x
	var backward_steps := 0
	var max_step := 0.0
	for _frame in range(30):
		await physics_frame
		var step := customer.global_position.x - previous_x
		if step < -0.01:
			backward_steps += 1
		max_step = maxf(max_step, absf(step))
		previous_x = customer.global_position.x
	Input.action_release(&"move_right")
	await physics_frame
	var release_position := customer.global_position
	for _frame in range(60):
		await physics_frame
	_check(
		release_position.distance_to(start) > 25.0,
		"The player must easily push other moving characters.",
	)
	_check(
		customer.global_position.distance_to(release_position) < 6.0,
		"A pushed character must stop promptly after contact ends.",
	)
	_check(backward_steps == 0, "A pushed character must not jitter backward.")
	_check(max_step < 5.0, "A pushed character must move smoothly between ticks.")
	world.queue_free()
	await process_frame


func _check_main_scene_push_order() -> void:
	var level := MAIN_SCENE.instantiate()
	var player := level.get_node("Player") as CharacterBody2D
	var customer := level.get_node("Customer") as CharacterBody2D
	customer.get_node("CustomerWanderController").process_mode = Node.PROCESS_MODE_DISABLED
	for path: NodePath in [
		^"NpcWorker",
		^"MladyShubungusCustomer",
		^"LilShubungusCustomer",
		^"LilShubungus2Customer",
	]:
		var other := level.get_node(path) as CharacterBody2D
		other.process_mode = Node.PROCESS_MODE_DISABLED
		other.global_position = Vector2(800, 100)
	root.add_child(level)
	player.global_position = Vector2(400, 400)
	customer.global_position = Vector2(424, 419)
	for _frame in range(3):
		await physics_frame
	Input.action_press(&"move_right", 1.0)
	var start := customer.global_position
	var previous_x := start.x
	var backward_steps := 0
	var max_step := 0.0
	for _frame in range(30):
		await physics_frame
		var step := customer.global_position.x - previous_x
		if step < -0.01:
			backward_steps += 1
		max_step = maxf(max_step, absf(step))
		previous_x = customer.global_position.x
	Input.action_release(&"move_right")
	await physics_frame
	var release_position := customer.global_position
	for _frame in range(60):
		await physics_frame
	_check(
		release_position.distance_to(start) > 20.0,
		"Main-scene process order must preserve easy character pushing.",
	)
	_check(
		customer.global_position.distance_to(release_position) < 12.0,
		(
			"Main-scene pushing must stop promptly after contact ends "
			+ "(coasted %.2f px)." % customer.global_position.distance_to(release_position)
		),
	)
	_check(backward_steps == 0, "Main-scene pushing must not jitter backward.")
	_check(
		max_step < 5.0,
		"Main-scene pushing must remain within one normal movement tick.",
	)
	level.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
