extends SceneTree

const LEVEL_2 := preload("res://scenes/level_2.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := LEVEL_2.instantiate()
	level.get_node("Hud").set_script(null)
	level.get_node("GameOverController").set_script(null)

	var workers := level.get_node("NavigationRegion2D").get_children()
	var active_runners: Array[Node] = []
	for index in workers.size():
		var worker := workers[index] as CharacterBody2D
		var runner := worker.get_node("NpcTaskRunner")
		worker.set("ErrorRate", 0.0)
		runner.set("RandomSeed", 100 + index)
		runner.process_mode = Node.PROCESS_MODE_DISABLED
		if index < 2:
			active_runners.append(runner)

	for customer in level.get_node("CustomersNavigationRegion2D").get_children():
		if customer.get_node_or_null("WorkstationTaskPublisher") == null:
			continue
		customer.set("MinimumRequestCooldownSeconds", 300.0)
		customer.set("MaximumRequestCooldownSeconds", 300.0)

	root.add_child(level)
	await _wait_physics_frames(5)

	var catalog := level.get_node("TaskSystem/ItemSourceCatalog")
	var random := RandomNumberGenerator.new()
	random.seed = 42
	var baby := level.get_node("BabyPickupItem")
	var first_baby_source = catalog.try_reserve_source(
		baby.get("Definition"),
		active_runners[0],
		random,
	)
	var second_baby_source = catalog.try_reserve_source(
		baby.get("Definition"),
		active_runners[1],
		random,
	)
	_check(
		first_baby_source == baby and second_baby_source == null,
		"A finite pickup item must remain reserved to only one worker.",
	)
	catalog.release(first_baby_source, active_runners[0])

	var socket := PickupSocket.new()
	level.add_child(socket)
	_check(
		socket.try_store(baby, 0.0),
		"The fixture must move the finite item into a pickup socket.",
	)
	socket.set_npc_source_enabled(true)
	var first_socket_source = catalog.try_reserve_source(
		baby.get("Definition"),
		active_runners[0],
		random,
	)
	var second_socket_source = catalog.try_reserve_source(
		baby.get("Definition"),
		active_runners[1],
		random,
	)
	_check(
		first_socket_source == socket and second_socket_source == null,
		"A finite pickup socket must remain reserved to only one worker.",
	)
	catalog.release(first_socket_source, active_runners[0])

	var board_publishers: Array[Node] = []
	var customer_region := level.get_node("CustomersNavigationRegion2D")
	for publisher in level.find_children("WorkstationTaskPublisher", "", true, false):
		if (
			customer_region.is_ancestor_of(publisher)
			or publisher.get("ActionTask") == null
			or publisher.get("_cooking_controller") != null
		):
			continue
		board_publishers.append(publisher)

	_check(
		board_publishers.size() >= 2,
		"The fixture requires two cutting-board publishers.",
	)
	if board_publishers.size() >= 2:
		_check(
			bool(board_publishers[0].call("try_publish_next_task"))
			and bool(board_publishers[1].call("try_publish_next_task")),
			"Both cutting boards must publish their potato fetch tasks.",
		)
		for runner in active_runners:
			runner.process_mode = Node.PROCESS_MODE_INHERIT

		var both_claimed := await _wait_until(
			func() -> bool:
				return (
					int(active_runners[0].get("current_task_id")) != 0
					and int(active_runners[1].get("current_task_id")) != 0
				),
			10,
		)
		var broker := level.get_node("TaskSystem/TaskBroker")
		_check(
			both_claimed
			and int(broker.get("open_task_count")) == 0
			and int(broker.get("claimed_task_count")) == 2,
			(
				"Two workers must claim simultaneous tasks from the unlimited "
				+ "potato container without waiting for one another. open=%s claimed=%s"
			)
			% [
				broker.get("open_task_count"),
				broker.get("claimed_task_count"),
			],
		)
		if both_claimed:
			var first_source = active_runners[0].get("_source")
			var second_source = active_runners[1].get("_source")
			_check(
				first_source is ContainerItemSource
				and second_source == first_source,
				"Both workers must be allowed to reserve the same unlimited container.",
			)

	level.queue_free()
	await process_frame
	print("parallel_container_claims_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _frame in max_frames:
		if bool(predicate.call()):
			return true
		await physics_frame
	return false


func _wait_physics_frames(frame_count: int) -> void:
	for _frame in frame_count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
