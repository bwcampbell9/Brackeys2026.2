extends SceneTree

const LEVEL_2 := preload("res://scenes/level_2.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := LEVEL_2.instantiate()
	var customer := level.get_node(
		"CustomersNavigationRegion2D/Customer",
	) as CharacterBody2D
	var controller := customer.get_node("CustomerWanderController")
	var motor := customer.get_node("NpcMotor")
	var navigation_agent := customer.get_node("NavigationAgent2D") as NavigationAgent2D
	controller.set("RandomSeed", 42)
	controller.set("WanderDelay", 0.1)
	controller.set("StuckTimeout", 10.0)
	controller.set("WanderBounds", Rect2(-200, 500, 0, 0))

	for other in level.find_children("*", "CharacterBody2D", true, false):
		if other != customer:
			other.process_mode = Node.PROCESS_MODE_DISABLED
			other.collision_layer = 0
			other.collision_mask = 0

	root.add_child(level)
	await _wait_physics_frames(3)

	var started := await _wait_until(
		func() -> bool: return not bool(motor.get("IsAtTarget")),
		30,
	)
	_check(started, "Customer must begin the configured corner route.")
	if started:
		var target: Vector2 = motor.get("TargetPosition")
		var closest := NavigationServer2D.map_get_closest_point(
			navigation_agent.get_navigation_map(),
			target,
		)
		_check(
			target.distance_to(closest) <= 0.5,
			"Customer wander targets must be projected onto reachable navigation.",
		)
		var reached := await _wait_until(
			func() -> bool: return bool(motor.get("IsAtTarget")),
			300,
		)
		_check(
			reached,
			"Customer must finish the route instead of pushing into a corner.",
		)

	level.queue_free()
	await process_frame
	print("npc_corner_navigation_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _frame in range(max_frames):
		if predicate.call():
			return true
		await physics_frame
	return false


func _wait_physics_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
