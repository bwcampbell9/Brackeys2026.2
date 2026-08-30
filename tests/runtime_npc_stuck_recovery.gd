extends SceneTree

const LEVEL_1 := preload("res://scenes/level_1.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := LEVEL_1.instantiate()
	level.get_node("Hud").set_script(null)
	level.get_node("GameOverController").set_script(null)

	var workers := level.get_node("NavigationRegion2D").get_children()
	var worker := workers[0] as CharacterBody2D
	var runner := worker.get_node("NpcTaskRunner")
	runner.set("RandomSeed", 42)
	runner.set("RetryDelay", 5.0)
	worker.set("ErrorRate", 0.0)

	var backup_runner := workers[1].get_node("NpcTaskRunner")
	backup_runner.process_mode = Node.PROCESS_MODE_DISABLED
	workers[1].set("ErrorRate", 0.0)
	workers[2].get_node("NpcTaskRunner").process_mode = Node.PROCESS_MODE_DISABLED

	var customers := level.get_node("CustomersNavigationRegion2D").get_children()
	var customer := customers[0]
	customer.set("PossibleRequests", 128)
	customer.set("MinimumRequestCooldownSeconds", 0.0)
	customer.set("MaximumRequestCooldownSeconds", 0.0)
	customer.set("OrderDurationSeconds", 120.0)
	for other_customer in customers:
		if other_customer == customer:
			continue
		other_customer.set("MinimumRequestCooldownSeconds", 300.0)
		other_customer.set("MaximumRequestCooldownSeconds", 300.0)

	root.add_child(level)
	for _frame in 5:
		await physics_frame

	var broker := level.get_node("TaskSystem/TaskBroker")
	var began_navigation := await _wait_until(
		func() -> bool:
			return (
				int(runner.get("state")) == 1
				and int(runner.get("current_task_id")) != 0
			),
		600,
	)
	_check(began_navigation, "The primary worker must claim a task and navigate to its source.")

	if began_navigation:
		var blocked_position := worker.global_position
		for _frame in 150:
			worker.global_position = blocked_position
			await physics_frame

		_check(
			int(runner.get("state")) == 2
			and int(runner.get("current_task_id")) == 0
			and int(broker.get("claimed_task_count")) == 0
			and int(broker.get("open_task_count")) == 1,
			(
				"A worker that cannot make navigation progress must release its task "
				+ "and source reservation for retry. state=%s task=%s open=%s claimed=%s"
				% [
					runner.get("state"),
					runner.get("current_task_id"),
					broker.get("open_task_count"),
					broker.get("claimed_task_count"),
				]
			),
		)

		runner.process_mode = Node.PROCESS_MODE_DISABLED
		backup_runner.process_mode = Node.PROCESS_MODE_INHERIT
		var reassigned := await _wait_until(
			func() -> bool: return int(backup_runner.get("current_task_id")) != 0,
			300,
		)
		_check(
			reassigned,
			"The released task and source reservation must be available to another worker.",
		)

	level.queue_free()
	await process_frame
	await _run_stalled_return_scenario()
	print("npc_stuck_recovery_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _run_stalled_return_scenario() -> void:
	var level := LEVEL_1.instantiate()
	level.get_node("Hud").set_script(null)
	level.get_node("GameOverController").set_script(null)

	var workers := level.get_node("NavigationRegion2D").get_children()
	for candidate in workers:
		candidate.get_node("NpcTaskRunner").process_mode = Node.PROCESS_MODE_DISABLED
	var worker := workers[0] as CharacterBody2D
	var runner := worker.get_node("NpcTaskRunner")
	var motor := worker.get_node("NpcMotor")
	var carrier := worker.get_node("PickupCarrier")
	worker.set("ErrorRate", 0.0)

	var customers := level.get_node("CustomersNavigationRegion2D").get_children()
	for customer in customers:
		customer.set("MinimumRequestCooldownSeconds", 300.0)
		customer.set("MaximumRequestCooldownSeconds", 300.0)

	root.add_child(level)
	for _frame in 5:
		await physics_frame

	var knife_source: ContainerItemSource
	for node in get_nodes_in_group(&"npc_item_sources"):
		if (
			level.is_ancestor_of(node)
			and node is ContainerItemSource
			and node.available_definition != null
			and node.available_definition.Id == &"knife"
		):
			knife_source = node
			break
	_check(knife_source != null, "The return fixture requires a knife container.")
	if knife_source != null:
		_check(
			knife_source.try_acquire(InteractionContext.new(worker, carrier)),
			"The return fixture must give the worker a knife.",
		)
		runner.set("_return_source", knife_source)
		_check(
			bool(motor.try_set_navigable_target(worker.global_position + Vector2(200.0, 0.0))),
			"The return fixture must assign a reachable target.",
		)
		runner.call("_set_state", 5)
		runner.process_mode = Node.PROCESS_MODE_INHERIT

		var blocked_position := worker.global_position
		for _frame in 150:
			worker.global_position = blocked_position
			await physics_frame

		_check(
			int(runner.get("state")) == 0 and carrier.get("held_item") == null,
			"A worker stalled while returning a tool must throw it and become available.",
		)

	level.queue_free()
	await process_frame


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _frame in max_frames:
		if bool(predicate.call()):
			return true
		await physics_frame
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
