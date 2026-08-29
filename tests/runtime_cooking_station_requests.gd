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
	await _wait_physics_frames(2)

	var player := level.get_node("Player") as CharacterBody2D
	level.get_node("NpcWorker").process_mode = Node.PROCESS_MODE_DISABLED
	await _request_at_station(
		player,
		level.get_node("Oven") as StaticBody2D,
		"Oven",
	)
	await _request_at_station(
		player,
		level.get_node("Stove") as StaticBody2D,
		"Stove",
	)

	level.queue_free()
	await process_frame
	print("cooking_station_requests_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _request_at_station(
	player: CharacterBody2D,
	station: StaticBody2D,
	station_name: String,
) -> void:
	var publisher := station.get_node("WorkstationTaskPublisher") as Node
	var indicator := station.get_node("TaskRequestIndicator") as Node2D
	_check(
		int(publisher.get("CurrentTaskId")) == 0 and not indicator.visible,
		"%s must start with no published task." % station_name,
	)
	player.global_position = station.global_position + Vector2(0, -48)
	await _wait_physics_frames(2)
	await _tap_interact()
	_check(
		int(publisher.get("CurrentTaskId")) != 0,
		"Tapping an empty %s must publish its item request." % station_name,
	)
	_check(
		indicator.visible and publisher.get("CurrentRequestedItem").get("Id") == &"potato",
		"%s must show its requested item after the player tap." % station_name,
	)


func _tap_interact() -> void:
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await _wait_physics_frames(2)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)