extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const KNIFE_DEFINITION := preload("res://resources/items/knife.tres")
const CHOP_RECIPE := preload("res://resources/recipes/chop.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _run_correct_fetch_scenario()
	await _run_stolen_return_item_scenario()
	await _run_toolless_action_scenario()
	await _run_impossible_fetch_readiness_scenario()
	await _run_stolen_wrong_item_scenario()
	await _run_two_kitchen_scope_scenario()
	print("npc_tasks_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _run_correct_fetch_scenario() -> void:
	var level := MAIN_SCENE.instantiate()
	var player := level.get_node("Player") as CharacterBody2D
	var worker := level.get_node("NpcWorker") as CharacterBody2D
	var runner := worker.get_node("NpcTaskRunner")
	runner.set("Personality", null)
	runner.set("RandomSeed", 42)
	root.add_child(level)
	await process_frame
	await process_frame

	var start_position := worker.global_position
	var board_socket := level.get_node("Workstations/CuttingBoard/PickupSocket")
	var publisher := level.get_node("Workstations/CuttingBoard/WorkstationTaskPublisher")
	var indicator := level.get_node("Workstations/CuttingBoard/TaskRequestIndicator") as Node2D
	var broker := level.get_node("TaskSystem/TaskBroker")
	publisher.set("RequestMode", 1)
	_check(
		int(broker.get("open_task_count")) == 0
		and int(broker.get("claimed_task_count")) == 0
		and not indicator.visible,
		"A player-started workstation must begin without publishing or showing a request.",
	)
	player.global_position = Vector2(620, 340)
	await _wait_physics_frames(2)
	await _tap_interact()
	_check(
		int(publisher.get("current_task_id")) != 0
		and indicator.visible
		and publisher.get("current_requested_item").get("Id") == &"potato",
		"Interacting with an empty board must publish and show its potato request.",
	)
	player.global_position = Vector2(450, 500)
	var carrier := worker.get_node("PickupCarrier") as Node2D
	var rotated_carrier := await _wait_until(
		func() -> bool: return absf(carrier.rotation) > 0.1,
		300,
	)
	var sprite := worker.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_check(
		rotated_carrier
		and is_zero_approx(worker.rotation)
		and is_zero_approx(sprite.global_rotation)
		and sprite.global_position.is_equal_approx(
			worker.global_position + Vector2(0, -44)
		),
		"Facing must rotate carried items while the body and upright sprite stay aligned to the foot origin.",
	)
	var hold_point := worker.get_node("PickupCarrier/HoldPoint") as Node2D
	_check(
		hold_point.global_position.is_equal_approx(
			carrier.global_position
				+ Vector2(0, -42).rotated(carrier.global_rotation)
		),
		"The pickup location must rotate around the NPC visual center.",
	)
	var delivered := await _wait_until(
		func() -> bool: return _socket_item_id(board_socket) == &"potato",
		1200,
	)
	_check(delivered, "The fetch stage must deliver the requested potato.")
	publisher.set("RequestMode", 2)
	await _wait_physics_frames(2)
	_check(
		int(publisher.get("current_task_id")) != 0
		and indicator.visible
		and publisher.get("current_requested_item").get("Id") == &"knife",
		"Delivering a chop-able item must automatically publish and show the knife request.",
	)
	player.global_position = Vector2(450, 500)
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
	_check(
		int(broker.get("open_task_count")) == 0
		and int(broker.get("claimed_task_count")) == 0
		and not indicator.visible,
		"The completed workstation must leave no tasks or request indicator.",
	)
	var parked_item := Node2D.new()
	level.add_child(parked_item)
	var chopped_item = board_socket.take(parked_item, 0.0)
	_check(chopped_item != null, "The completed item must be removable for task reconciliation.")
	if chopped_item != null:
		_check(
			bool(board_socket.try_store(chopped_item, 0.0)),
			"The completed item must be replaceable on the cutting board.",
		)
	await _wait_physics_frames(2)
	_check(
		int(broker.get("open_task_count")) == 0 and int(broker.get("claimed_task_count")) == 0,
		"An already chopped item must not publish another cutting action task.",
	)

	level.queue_free()
	await process_frame


func _run_stolen_return_item_scenario() -> void:
	var level := MAIN_SCENE.instantiate()
	var worker := level.get_node("NpcWorker") as CharacterBody2D
	var runner := worker.get_node("NpcTaskRunner")
	runner.set("Personality", null)
	runner.set("RandomSeed", 43)
	root.add_child(level)
	await process_frame
	await process_frame
	var publisher := level.get_node("Workstations/CuttingBoard/WorkstationTaskPublisher")
	publisher.set("RequestMode", 1)
	_check(bool(publisher.call("try_publish_next_task")), "The fixture must publish the initial fetch stage.")
	var board_socket := level.get_node("Workstations/CuttingBoard/PickupSocket")
	var delivered := await _wait_until(
		func() -> bool: return _socket_item_id(board_socket) == &"potato",
		1200,
	)
	_check(delivered, "The fixture must deliver the potato before automatic processing.")
	publisher.set("RequestMode", 2)
	await _wait_physics_frames(2)

	var npc_carrier := worker.get_node("PickupCarrier")
	var returning_tool := await _wait_until(
		func() -> bool:
			return (
				int(runner.get("state")) == 5
				and npc_carrier.get("held_item") != null
			),
		1800,
	)
	_check(returning_tool, "The worker must begin returning its processing tool.")
	if not returning_tool:
		level.queue_free()
		await process_frame
		return

	var player_carrier := level.get_node("Player/PickupCarrier")
	var tool: Node = npc_carrier.get("held_item")
	_check(
		bool(npc_carrier.try_transfer_held_item_to(tool, player_carrier)),
		"The player fixture must be able to take the returning tool.",
	)
	await _wait_physics_frames(2)
	_check(
		int(runner.get("state")) != 5 and worker.velocity.is_zero_approx(),
		"Taking a returning tool must stop the return and release the worker.",
	)

	var external_hold := Node2D.new()
	level.add_child(external_hold)
	var completed_item: Node = board_socket.take(external_hold, 0.0)
	_check(
		completed_item != null,
		"The completed item must be removable to publish follow-up work.",
	)
	var accepted_follow_up := await _wait_until(
		func() -> bool: return int(runner.get("current_task_id")) != 0,
		300,
	)
	_check(
		accepted_follow_up,
		"A worker whose returning tool was taken must remain reusable.",
	)

	level.queue_free()
	await process_frame


func _run_toolless_action_scenario() -> void:
	var required_tool: Resource = CHOP_RECIPE.get("RequiredTool")
	CHOP_RECIPE.set("RequiredTool", null)
	var level := MAIN_SCENE.instantiate()
	var worker := level.get_node("NpcWorker") as CharacterBody2D
	var runner := worker.get_node("NpcTaskRunner")
	runner.set("Personality", null)
	runner.set("RandomSeed", 44)
	root.add_child(level)
	await process_frame
	await process_frame
	var publisher := level.get_node("Workstations/CuttingBoard/WorkstationTaskPublisher")
	publisher.set("RequestMode", 1)
	_check(bool(publisher.call("try_publish_next_task")), "The fixture must publish the initial fetch stage.")

	var board_socket := level.get_node("Workstations/CuttingBoard/PickupSocket")
	var delivered := await _wait_until(
		func() -> bool: return _socket_item_id(board_socket) == &"potato",
		1200,
	)
	_check(delivered, "The fixture must deliver the potato before automatic processing.")
	publisher.set("RequestMode", 2)
	await _wait_physics_frames(2)
	var completed := await _wait_until(
		func() -> bool: return _socket_item_id(board_socket) == &"chopped_potatoes",
		1800,
	)
	_check(
		completed,
		"A tool-less action task must navigate to its destination and complete.",
	)
	_check(
		worker.get_node("PickupCarrier/HoldPoint").get_child_count() == 0,
		"A tool-less action must complete without inventing a carried item.",
	)

	CHOP_RECIPE.set("RequiredTool", required_tool)
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
	var publisher := level.get_node("Workstations/CuttingBoard/WorkstationTaskPublisher")
	publisher.set("RequestMode", 1)
	_check(
		bool(publisher.call("try_publish_next_task")),
		"The scenario must start the player-requested fetch stage.",
	)

	var potato_source := level.get_node("Workstations/Container/NpcItemSource")
	potato_source.set("ItemDefinition", null)
	runner.process_mode = Node.PROCESS_MODE_INHERIT
	await _wait_physics_frames(120)

	var broker := level.get_node("TaskSystem/TaskBroker")
	_check(
		int(runner.get("current_task_id")) == 0
		and int(broker.get("open_task_count")) == 1
		and int(broker.get("claimed_task_count")) == 0,
		(
			"A fetch with no correct source must remain published but unclaimed, "
			+ "even when wrong items are available."
		),
	)

	potato_source.set("ItemDefinition", preload("res://resources/items/potato.tres"))
	var became_claimable := await _wait_until(
		func() -> bool: return int(runner.get("current_task_id")) != 0,
		300,
	)
	_check(
		became_claimable,
		"The existing fetch demand must become claimable when its correct source appears.",
	)
	_check(
		int(runner.get("selected_failure_mode")) == 0
		and runner.get("selected_item_id") != &"potato",
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
	var publisher := level.get_node("Workstations/CuttingBoard/WorkstationTaskPublisher")
	publisher.set("RequestMode", 1)
	_check(
		bool(publisher.call("try_publish_next_task")),
		"The scenario must start the player-requested fetch stage.",
	)
	var knife_source := level.get_node("Workstations/KnifeContainer/NpcItemSource")
	knife_source.set("ItemDefinition", null)
	runner.process_mode = Node.PROCESS_MODE_INHERIT

	var selected_baby := await _wait_until(
		func() -> bool:
			return (
				runner.get("selected_item_id") == &"baby"
				and int(runner.get("state")) == 1
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
		bool(baby.try_pick_up(external_hold, 0.0)),
		"The test actor must be able to steal the selected ground item.",
	)
	await _wait_physics_frames(2)
	_check(
		int(runner.get("state")) == 2,
		"A stolen target must move the worker into its retry delay.",
	)
	var broker := level.get_node("TaskSystem/TaskBroker")
	_check(
		int(runner.get("current_task_id")) == 0
			and int(broker.get("open_task_count")) == 1
			and int(broker.get("claimed_task_count")) == 0,
		"A worker that loses its item must release its task for republishing.",
	)
	_check(
		worker.velocity.is_zero_approx(),
		"The worker must stop immediately when its selected target is stolen.",
	)
	await _wait_physics_frames(30)
	_check(
		int(runner.get("state")) == 2,
		"The worker must not select another source before the retry delay expires.",
	)

	baby.throw(Vector2.ZERO)
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
				runner.get("state"),
				runner.get("selected_item_id"),
				worker.global_position,
				baby.global_position,
				worker.get_node("PickupCarrier/HoldPoint").get_child_count(),
				_socket_item_id(board_socket),
			]
		),
	)

	await _wait_physics_frames(2)
	_check(
		int(publisher.get("current_task_id")) != 0,
		"Delivering the wrong item must automatically publish its action stage.",
	)
	await _wait_physics_frames(120)
	_check(
		int(runner.get("current_task_id")) == 0
		and int(broker.get("open_task_count")) == 1
		and int(broker.get("claimed_task_count")) == 0,
		"An action task must remain unclaimed while its required knife is unavailable.",
	)

	knife_source.set("ItemDefinition", KNIFE_DEFINITION)
	var selected_valid_tool := await _wait_until(
		func() -> bool:
			return (
				int(runner.get("state")) == 4
				and runner.get("selected_item_id") == &"knife"
				and int(runner.get("selected_failure_mode")) == -1
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
	var first_publisher := first_kitchen.get_node(
		"Workstations/CuttingBoard/WorkstationTaskPublisher"
	)
	var second_publisher := second_kitchen.get_node(
		"Workstations/CuttingBoard/WorkstationTaskPublisher"
	)
	first_publisher.set("RequestMode", 1)
	second_publisher.set("RequestMode", 0)
	await _wait_physics_frames(2)

	var first_broker := first_kitchen.get_node("TaskSystem/TaskBroker")
	var second_broker := second_kitchen.get_node("TaskSystem/TaskBroker")
	_check(
		int(first_broker.get("open_task_count")) == 0
		and int(second_broker.get("open_task_count")) == 1,
		"Manual and automatic publishers must retain independent startup behavior.",
	)
	_check(
		bool(first_publisher.call("try_publish_next_task"))
		and int(first_broker.get("open_task_count")) == 1
		and int(second_broker.get("open_task_count")) == 1,
		"Starting the manual publisher must not affect the automatic kitchen broker.",
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


func _tap_interact() -> void:
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await _wait_physics_frames(2)


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
