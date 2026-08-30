extends SceneTree

const LEVEL_1 := preload("res://scenes/level_1.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := LEVEL_1.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	await process_frame

	var cooldowns: Array[float] = []
	for customer in level.get_node("CustomersNavigationRegion2D").get_children():
		var publisher := customer.get_node_or_null("WorkstationTaskPublisher")
		if publisher == null:
			continue
		var cooldown := float(publisher.get("order_cooldown_remaining"))
		cooldowns.append(cooldown)
		_check(
			int(publisher.get("current_task_id")) == 0,
			"Customers must not publish an order immediately after spawning.",
		)
		_check(
			cooldown >= 0.9,
			"Every customer must wait at least one second before requesting.",
		)
		_check(
			is_equal_approx(float(publisher.get("OrderDurationSeconds")), 45.0),
			"Customers must have 50% more order time.",
		)

	var unique_cooldowns := {}
	for cooldown in cooldowns:
		unique_cooldowns[cooldown] = true
	_check(
		unique_cooldowns.size() > 1,
		"Spawn cooldowns must stagger customer requests.",
	)

	level.queue_free()
	await process_frame
	print("customer_spawn_timing_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
