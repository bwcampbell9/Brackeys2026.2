extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const KNIFE_SCENE := preload("res://scenes/knife_item.tscn")
const KNIFE_DEFINITION := preload("res://resources/items/knife.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := MAIN_SCENE.instantiate()
	var player := level.get_node("Player") as CharacterBody2D
	var player_carrier := player.get_node("PickupCarrier")
	var worker := level.get_node("NpcWorker") as CharacterBody2D
	var runner := worker.get_node("NpcTaskRunner")
	runner.set("Personality", null)
	runner.set("RandomSeed", 42)
	runner.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	await process_frame
	await process_frame

	var carried_knife := KNIFE_SCENE.instantiate()
	level.add_child(carried_knife)
	carried_knife.global_position = player.global_position
	_check(
		bool(player_carrier.TryHold(carried_knife)),
		"The fixture must give the player a knife.",
	)
	player.global_position = Vector2(850, 500)

	var knife_source := level.get_node("Workstations/KnifeContainer/NpcItemSource")
	knife_source.set("ItemDefinition", null)
	var publisher := level.get_node("Workstations/CuttingBoard/WorkstationTaskPublisher")
	publisher.set("RequestMode", 1)
	_check(
		bool(publisher.call("TryPublishNextTask")),
		"The fixture must publish the potato fetch stage.",
	)
	runner.process_mode = Node.PROCESS_MODE_INHERIT

	var board_socket := level.get_node("Workstations/CuttingBoard/PickupSocket")
	var delivered := await _wait_until(
		func() -> bool: return _socket_item_id(board_socket) == &"potato",
		1200,
	)
	_check(delivered, "The worker must deliver the potato before requesting a knife.")
	publisher.set("RequestMode", 2)
	await _wait_physics_frames(2)
	_check(
		int(publisher.get("CurrentTaskId")) != 0,
		"Delivering the potato must automatically publish the chopping stage.",
	)

	var selected_carried_knife := await _wait_until(
		func() -> bool:
			return (
				int(runner.get("State")) == 1
				and runner.get("SelectedItemId") == &"knife"
			),
		300,
	)
	_check(
		selected_carried_knife,
		"The worker must select the player's carried knife as its tool source.",
	)
	player.global_position = worker.global_position
	carried_knife.global_position = worker.global_position
	knife_source.set("ItemDefinition", KNIFE_DEFINITION)

	var acquired_carried_knife := await _wait_until(
		func() -> bool:
			return (
				worker.get_node("PickupCarrier").get("HeldItem") == carried_knife
				and player_carrier.get("HeldItem") == null
			),
		1200,
	)
	_check(
		acquired_carried_knife,
		"The worker must acquire the knife carried by the player.",
	)

	var completed := await _wait_until(
		func() -> bool: return _socket_item_id(board_socket) == &"chopped_potatoes",
		1200,
	)
	_check(completed, "The worker must complete chopping with the carried knife.")

	var knife_container := level.get_node("Workstations/KnifeContainer")
	var returned := await _wait_until(
		func() -> bool:
			return (
				is_instance_valid(carried_knife)
				and carried_knife.get_parent() == knife_container
			),
		600,
	)
	_check(
		returned,
		"A carried knife used for chopping must be put back in matching storage.",
	)

	level.queue_free()
	await process_frame
	_finish()


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _frame in max_frames:
		if bool(predicate.call()):
			return true
		await physics_frame
	return false


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _socket_item_id(socket: Node) -> StringName:
	if socket.get_child_count() != 1:
		return &""
	var definition: Resource = socket.get_child(0).get("Definition")
	return definition.get("Id") if definition != null else &""


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _finish() -> void:
	print("npc_carried_knife_return_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)
