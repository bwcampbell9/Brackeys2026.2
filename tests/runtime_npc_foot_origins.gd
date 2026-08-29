extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := MAIN_SCENE.instantiate()
	var worker := level.get_node("NpcWorker") as CharacterBody2D
	worker.get_node("NpcTaskRunner").process_mode = Node.PROCESS_MODE_DISABLED

	var customers: Array[CharacterBody2D] = [
		level.get_node("Customer"),
		level.get_node("MladyShubungusCustomer"),
		level.get_node("LilShubungusCustomer"),
		level.get_node("LilShubungus2Customer"),
	]
	for customer in customers:
		customer.get_node("CustomerWanderController").process_mode = Node.PROCESS_MODE_DISABLED

	root.add_child(level)
	await process_frame
	await physics_frame

	_check_ai_origin(worker, Vector2(0, -44))
	_check(
		worker.get_node("AnimatedSprite2D").global_position.is_equal_approx(
			Vector2(480, 400)
		),
		"The worker visual must retain its original initial world position.",
	)

	var expected_customer_visuals := [
		Vector2(760, 400),
		Vector2(680, 400),
		Vector2(840, 400),
		Vector2(600, 400),
	]
	for index in customers.size():
		_check_ai_origin(customers[index], Vector2(0, -40))
		_check(
			customers[index].get_node("AnimatedSprite2D").global_position.is_equal_approx(
				expected_customer_visuals[index]
			),
			"Customer %d must retain its original initial world position." % index,
		)

	var carrier := worker.get_node("PickupCarrier") as Node2D
	var hold_point := carrier.get_node("HoldPoint") as Node2D
	var start_position := worker.global_position
	worker.get_node("NpcMotor").SetTarget(start_position + Vector2(120, -80))
	var turned := await _wait_until(
		func() -> bool:
			return (
				worker.global_position.distance_to(start_position) > 1.0
				and absf(carrier.rotation) > 0.1
			),
		120,
	)
	_check(turned, "The worker must move and turn its carrier toward the target.")
	_check(
		is_zero_approx(worker.rotation),
		"The worker body must stay upright so its foot origin does not orbit.",
	)
	_check_ai_origin(worker, Vector2(0, -44))
	_check(
		hold_point.global_position.is_equal_approx(
			carrier.global_position
				+ Vector2(0, -42).rotated(carrier.global_rotation)
		),
		"The hold point must rotate around the preserved visual center.",
	)

	level.queue_free()
	print("npc_foot_origins_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _check_ai_origin(actor: CharacterBody2D, visual_offset: Vector2) -> void:
	var collision := actor.get_node("CollisionShape2D") as CollisionShape2D
	var sprite := actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_check(
		collision.position.is_zero_approx()
		and collision.global_position.is_equal_approx(actor.global_position),
		"%s navigation and collision origins must coincide." % actor.name,
	)
	_check(
		sprite.global_position.is_equal_approx(actor.global_position + visual_offset)
		and is_zero_approx(sprite.global_rotation),
		"%s visual must remain upright above its foot origin." % actor.name,
	)


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _frame in max_frames:
		if predicate.call():
			return true
		await physics_frame
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
