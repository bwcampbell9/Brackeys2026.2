extends SceneTree

const LEVEL_1 := preload("res://scenes/level_1.tscn")
const WORKER_SCENE := preload("res://scenes/npc_worker.tscn")
const CUSTOMER_SCENES := [
	preload("res://scenes/customer.tscn"),
	preload("res://scenes/mlady_customer.tscn"),
	preload("res://scenes/lil_customer.tscn"),
	preload("res://scenes/lil_customer_2.tscn"),
]

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_configured_speeds()
	await _check_customer_delivery_in_range()
	print("worker_customer_delivery_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _check_configured_speeds() -> void:
	var worker := WORKER_SCENE.instantiate()
	_check(
		is_equal_approx(float(worker.get_node("NpcMotor").get("Speed")), 132.0),
		"Workers must move 20% faster at 132 px/s.",
	)
	worker.free()

	for customer_scene: PackedScene in CUSTOMER_SCENES:
		var customer := customer_scene.instantiate()
		_check(
			is_equal_approx(float(customer.get_node("NpcMotor").get("Speed")), 88.0),
			"Every customer variant must move 20% slower at 88 px/s.",
		)
		customer.free()


func _check_customer_delivery_in_range() -> void:
	var level := LEVEL_1.instantiate()
	var worker := level.get_node("NavigationRegion2D/NpcWorker") as CharacterBody2D
	var runner := worker.get_node("NpcTaskRunner")
	var motor := worker.get_node("NpcMotor")
	var carrier := worker.get_node("PickupCarrier")
	worker.set("ErrorRate", 0.0)
	runner.set("RandomSeed", 42)

	for other_worker in level.get_node("NavigationRegion2D").get_children():
		if other_worker != worker:
			other_worker.process_mode = Node.PROCESS_MODE_DISABLED

	var customer := level.get_node(
		"CustomersNavigationRegion2D/Customer",
	) as CharacterBody2D
	customer.get_node("CustomerWanderController").process_mode = Node.PROCESS_MODE_DISABLED
	customer.set("PossibleRequests", 128)
	customer.set("MinimumRequestCooldownSeconds", 0.0)
	customer.set("MaximumRequestCooldownSeconds", 0.0)
	for other_customer in level.get_node("CustomersNavigationRegion2D").get_children():
		if other_customer != customer:
			other_customer.set("MinimumRequestCooldownSeconds", 300.0)
			other_customer.set("MaximumRequestCooldownSeconds", 300.0)

	var publisher := customer.get_node("WorkstationTaskPublisher")
	root.add_child(level)
	var has_item_for_customer := await _wait_until(
		func() -> bool:
			return (
				int(runner.get("state")) == 3
				and carrier.get("held_item") != null
				and int(publisher.get("current_task_id")) != 0
			),
		1200,
	)
	_check(
		has_item_for_customer,
		"Worker must acquire the customer's requested item.",
	)
	if has_item_for_customer:
		worker.global_position = customer.global_position + Vector2(30, 0)
		motor.set_target(customer.global_position)
		_check(
			not bool(motor.get("is_at_target")),
			"Worker must still be navigating when proximity delivery begins.",
		)
		_check(
			worker.global_position.distance_to(customer.global_position) <= 34.0,
			"Worker must be inside the customer's interaction range.",
		)
		var delivered := await _wait_until(
			func() -> bool:
				return (
					carrier.get("held_item") == null
					and (
						bool(publisher.get("is_consuming"))
						or int(publisher.get("current_task_id")) == 0
					)
				),
			30,
		)
		_check(
			delivered,
			"Worker must hand off the item from any side when within range.",
		)

	level.queue_free()
	await process_frame


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _frame in range(max_frames):
		if predicate.call():
			return true
		await physics_frame
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
