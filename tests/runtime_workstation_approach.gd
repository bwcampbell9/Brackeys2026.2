extends SceneTree

const LEVEL_2 := preload("res://scenes/level_2.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := LEVEL_2.instantiate()
	var worker := level.get_node("NavigationRegion2D/NpcWorker") as CharacterBody2D
	var runner := worker.get_node("NpcTaskRunner")
	var motor := worker.get_node("NpcMotor")
	var navigation_agent := worker.get_node("NavigationAgent2D") as NavigationAgent2D
	worker.set("ErrorRate", 0.0)
	runner.set("RandomSeed", 42)

	for publisher in level.find_children("WorkstationTaskPublisher", "", true, false):
		publisher.set("RequestMode", 1)

	root.add_child(level)
	await _wait_physics_frames(3)

	var cutting_board := level.find_child("CuttingBoard", true, false)
	var publisher := cutting_board.get_node("WorkstationTaskPublisher")
	var socket := cutting_board.get_node("PickupSocket")
	runner.process_mode = Node.PROCESS_MODE_DISABLED
	_check(
		bool(motor.try_set_navigable_target(Vector2(-10000, -10000))),
		"A wander target outside the level must resolve onto navigation.",
	)
	var projected_wander_target: Vector2 = motor.get("target_position")
	_check(
		projected_wander_target.distance_to(
			NavigationServer2D.map_get_closest_point(
				navigation_agent.get_navigation_map(),
				projected_wander_target,
			)
		) <= 0.5,
		"Workers must only keep wander targets inside the navigation map.",
	)
	await _check_approach_side_selection(
		worker,
		motor,
		navigation_agent,
		cutting_board,
		publisher,
	)
	motor.stop()
	runner.process_mode = Node.PROCESS_MODE_INHERIT
	_check(
		bool(publisher.call("try_publish_next_task")),
		"The cutting board must publish a fetch task for the fixture.",
	)

	var navigating_to_board := await _wait_until(
		func() -> bool: return int(runner.get("state")) == 3,
		1200,
	)
	_check(
		navigating_to_board,
		"The worker must acquire the requested item and navigate to the cutting board.",
	)
	if navigating_to_board:
		var target: Vector2 = motor.get("target_position")
		var navigation_map := navigation_agent.get_navigation_map()
		var closest := NavigationServer2D.map_get_closest_point(
			navigation_map,
			target,
		)
		_check(
			target.distance_to(closest) <= 0.5,
			"The selected cutting-board approach must be inside the navigation map.",
		)
		var path := NavigationServer2D.map_get_path(
			navigation_map,
			worker.global_position,
			target,
			true,
		)
		_check(
			not path.is_empty(),
			"The selected cutting-board approach must be reachable from the worker.",
		)

	var delivered := await _wait_until(
		func() -> bool: return _socket_item_id(socket) == &"potato",
		1200,
	)
	_check(
		delivered,
		"The worker must reach and deliver to the cutting board.",
	)

	level.queue_free()
	await process_frame
	print("workstation_approach_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _check_approach_side_selection(
	worker: CharacterBody2D,
	motor: Node,
	navigation_agent: NavigationAgent2D,
	cutting_board: Node2D,
	publisher: Node2D,
) -> void:
	var navigation_map := navigation_agent.get_navigation_map()
	var original_position := worker.global_position
	var unique_targets := {}
	for direction: Vector2 in [
		Vector2.LEFT,
		Vector2.RIGHT,
		Vector2.UP,
		Vector2.DOWN,
	]:
		worker.global_position = NavigationServer2D.map_get_closest_point(
			navigation_map,
			cutting_board.global_position + direction * 160.0,
		)
		await physics_frame
		_check(
			bool(
				motor.try_set_approach_target(
					publisher,
					publisher.get("approach_position"),
				)
			),
			"Each worker origin must resolve a reachable workstation side.",
		)
		var target: Vector2 = motor.get("target_position")
		var closest := NavigationServer2D.map_get_closest_point(
			navigation_map,
			target,
		)
		_check(
			target.distance_to(closest) <= 0.5,
			"Every workstation-side candidate must lie inside navigation.",
		)
		unique_targets[Vector2i(roundi(target.x), roundi(target.y))] = true

	_check(
		unique_targets.size() >= 2,
		"Approach selection must use more than one side of the cutting board.",
	)
	worker.global_position = original_position


func _socket_item_id(socket: Node) -> StringName:
	var item: Node = socket.get("item")
	if item == null:
		return &""
	var definition: Resource = item.get("Definition")
	return definition.get("Id") if definition != null else &""


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
