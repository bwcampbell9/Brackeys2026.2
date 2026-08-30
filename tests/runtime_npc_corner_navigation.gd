extends SceneTree

const WORKER_SCENE := preload("res://scenes/npc_worker.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var worker := WORKER_SCENE.instantiate() as CharacterBody2D
	worker.get_node("NpcTaskRunner").process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(worker)
	await physics_frame

	var motor := worker.get_node("NpcMotor")
	var navigation_agent := worker.get_node("NavigationAgent2D") as NavigationAgent2D
	var collision := worker.get_node("CollisionShape2D") as CollisionShape2D
	var body_shape := collision.shape as CircleShape2D
	_check(body_shape != null, "NPC corner test requires a circular body.")
	if body_shape != null:
		_check(
			navigation_agent.path_desired_distance <= body_shape.radius * 0.5,
			(
				"NPC corner waypoints must not advance before the body clears "
				+ "the turn (waypoint distance %.1f, radius %.1f)."
			) % [navigation_agent.path_desired_distance, body_shape.radius],
		)
	_check(
		is_equal_approx(
			navigation_agent.target_desired_distance,
			float(motor.get("ArrivalDistance")),
		),
		"Corner clearance must not change final-target arrival distance.",
	)

	worker.queue_free()
	await process_frame
	print("npc_corner_navigation_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
