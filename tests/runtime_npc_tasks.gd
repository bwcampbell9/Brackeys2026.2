extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const KNIFE_DEFINITION := preload("res://resources/items/knife.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _run_correct_fetch_scenario()
	await _run_impossible_fetch_readiness_scenario()
	await _run_stolen_wrong_item_scenario()
	await _run_two_kitchen_scope_scenario()
	print("npc_tasks_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _run_correct_fetch_scenario() -> void:
	var level := MAIN_SCENE.instantiate()
	var worker := level.get_node("NpcWorker") as CharacterBody2D
	var runner := worker.get_node("NpcTaskRunner")
	runner.set("Personality", null)
	runner.set("RandomSeed", 42)
	root.add_child(level)
	await process_frame
	await process_frame

	var start_position := worker.global_position
	var board_socket := level.get_node("Workstations/CuttingBoard/PickupSocket")
	var rotated_body := await _wait_until(
		func() -> bool: return absf(worker.rotation) > 0.1,
		300,
	)
	_check(
		rotated_body and is_zero_approx(worker.get_node("Sprite2D").rotation),
		"Facing must rotate the whole NPC body rather than only its sprite.",
	)
	var hold_point := worker.get_node("PickupCarrier/HoldPoint") as Node2D
	_check(
		hold_point.global_position.is_equal_approx(
			worker.global_position
				+ Vector2(0, -42).rotated(worker.global_rotation)
		),
		"The pickup location must rotate with the NPC body.",
	)
	var completed := await _wait_until(
		func() -> bool: return _socket_item_id(board_socket) == &"chopped_potatoes",
		1800,
	)
	_check(completed, "A correct worker must fetch, deliver, and process the requested potato.")
	_check(
		worker.global_position.distance_to(start_position) > 100.0,
		"The worker must physically walk between task targets.",
	)
	_check(
		level.get_node("BabyPickupItem").get("Definition").get("Id") == &"baby",
		"The separate baby pickup must remain unchanged during correct work.",
	)
	var returned_tool := await _wait_until(
		func() -> bool:
			return worker.get_node("PickupCarrier/HoldPoint").get_child_count() == 0,
		600,
	)
	_check(
		returned_tool,
		"The worker must return its processing tool after completing the action.",
	)
	var broker := level.get_node("TaskSystem/TaskBroker")
	_check(
		int(broker.get("OpenTaskCount")) == 0 and int(broker.get("ClaimedTaskCount")) == 0,
		"The completed workstation must leave no open or claimed tasks.",
	)

	level.queue_free()
	await process_frame


func _run_impossible_fetch_readiness_scenario() -> void:
	var level := MAIN_SCENE.instantiate()
	var runner := level.get_node("NpcWorker/NpcTaskRunner")
	var personality: Resource = runner.get("Personality").duplicate(true)
	personality.set("FailureChance", 1.0)
	runner.set("Personality", personality)
	runner.set("RandomSeed", 19)
	runner.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	await process_frame
	await process_frame

	var potato_source := level.get_node("Workstations/PotatoContainer/NpcItemSource")
	potato_source.set("ItemDefinition", null)
	runner.process_mode = Node.PROCESS_MODE_INHERIT
	await _wait_physics_frames(120)

	var broker := level.get_node("TaskSystem/TaskBroker")
	_check(
		int(runner.get("CurrentTaskId")) == 0
		and int(broker.get("OpenTaskCount")) == 1
		and int(broker.get("ClaimedTaskCount")) == 0,
		(
			"A fetch with no correct source must remain published but unclaimed, "
			+ "even when wrong items are available."
		),
	)

	potato_source.set("ItemDefinition", preload("res://resources/items/potato.tres"))
	var became_claimable := await _wait_until(
		func() -> bool: return int(runner.get("CurrentTaskId")) != 0,
		300,
	)
	_check(
		became_claimable,
		"The existing fetch demand must become claimable when its correct source appears.",
	)
	_check(
		int(runner.get("SelectedFailureMode")) == 0
		and runner.get("SelectedItemId") != &"potato",
		"A personality mistake may be selected only after the success path is feasible.",
	)

	level.queue_free()
	await process_frame


func _run_stolen_wrong_item_scenario() -> void:
	var level := MAIN_SCENE.instantiate()
	var worker := level.get_node("NpcWorker") as CharacterBody2D
	var runner := worker.get_node("NpcTaskRunner")
	var personality: Resource = runner.get("Personality").duplicate(true)
	personality.set("FailureChance", 1.0)
	runner.set("Personality", personality)
	runner.set("RandomSeed", 7)
	runner.set("RetryDelay", 1.0)
	runner.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	await process_frame
	await process_frame
	var knife_source := level.get_node("Workstations/KnifeContainer/NpcItemSource")
	knife_source.set("ItemDefinition", null)
	runner.process_mode = Node.PROCESS_MODE_INHERIT

	var selected_baby := await _wait_until(
		func() -> bool:
			return (
				runner.get("SelectedItemId") == &"baby"
				and int(runner.get("State")) == 1
			),
		300,
	)
	_check(selected_baby, "With one wrong definition available, the worker must target the baby.")
	if not selected_baby:
		level.queue_free()
		await process_frame
		return

	var baby := level.get_node("BabyPickupItem")
	var external_hold := Node2D.new()
	level.add_child(external_hold)
	external_hold.global_position = baby.global_position
	_check(
		bool(baby.TryPickUp(external_hold, 0.0)),
		"The test actor must be able to steal the selected ground item.",
	)
	await _wait_physics_frames(2)
	_check(
		int(runner.get("State")) == 2,
		"A stolen target must move the worker into its retry delay.",
	)
	var broker := level.get_node("TaskSystem/TaskBroker")
	_check(
		int(runner.get("CurrentTaskId")) == 0
			and int(broker.get("OpenTaskCount")) == 1
			and int(broker.get("ClaimedTaskCount")) == 0,
		"A worker that loses its item must release its task for republishing.",
	)
	_check(
		worker.velocity.is_zero_approx(),
		"The worker must stop immediately when its selected target is stolen.",
	)
	await _wait_physics_frames(30)
	_check(
		int(runner.get("State")) == 2,
		"The worker must not select another source before the retry delay expires.",
	)

	baby.Throw(Vector2.ZERO)
	var board_socket := level.get_node("Workstations/CuttingBoard/PickupSocket")
	var delivered_wrong_item := await _wait_until(
		func() -> bool: return _socket_item_id(board_socket) == &"baby",
		900,
	)
	_check(
		delivered_wrong_item,
		(
			"The worker must retry and deliver its originally selected wrong item. "
			+ "state=%s selected=%s worker=%s baby=%s held=%s socket=%s"
			% [
				runner.get("State"),
				runner.get("SelectedItemId"),
				worker.global_position,
				baby.global_position,
				worker.get_node("PickupCarrier/HoldPoint").get_child_count(),
				_socket_item_id(board_socket),
			]
		),
	)

	await _wait_physics_frames(120)
	_check(
		int(runner.get("CurrentTaskId")) == 0
		and int(broker.get("OpenTaskCount")) == 1
		and int(broker.get("ClaimedTaskCount")) == 0,
		"An action task must remain unclaimed while its required knife is unavailable.",
	)

	knife_source.set("ItemDefinition", KNIFE_DEFINITION)
	var selected_valid_tool := await _wait_until(
		func() -> bool:
			return (
				int(runner.get("State")) == 4
				and runner.get("SelectedItemId") == &"knife"
				and int(runner.get("SelectedFailureMode")) == -1
			),
		900,
	)
	_check(
		selected_valid_tool,
		"An action task must use its required knife and cannot substitute the baby.",
	)
	var processed_wrong_item := await _wait_until(
		func() -> bool: return _socket_item_id(board_socket) == &"chopped_baby",
		1200,
	)
	_check(
		processed_wrong_item,
		"An occupied workstation must request and perform its action without validating the item.",
	)

	level.queue_free()
	await process_frame


func _run_two_kitchen_scope_scenario() -> void:
	var first_kitchen := MAIN_SCENE.instantiate()
	var second_kitchen := MAIN_SCENE.instantiate()
	first_kitchen.get_node("NpcWorker/NpcTaskRunner").process_mode = Node.PROCESS_MODE_DISABLED
	second_kitchen.get_node("NpcWorker/NpcTaskRunner").process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(first_kitchen)
	root.add_child(second_kitchen)
	await process_frame
	await process_frame
	await _wait_physics_frames(2)

	var first_broker := first_kitchen.get_node("TaskSystem/TaskBroker")
	var second_broker := second_kitchen.get_node("TaskSystem/TaskBroker")
	_check(
		int(first_broker.get("OpenTaskCount")) == 1
		and int(second_broker.get("OpenTaskCount")) == 1,
		"Each simultaneous kitchen must retain exactly one task in its own broker.",
	)

	first_kitchen.queue_free()
	second_kitchen.queue_free()
	await process_frame


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
