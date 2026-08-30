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
	var customer_paths := [
		"Customer",
		"MladyShubungusCustomer",
		"LilShubungusCustomer",
		"LilShubungus2Customer",
	]
	for customer_path in customer_paths:
		var customer := level.get_node(customer_path)
		_check_request_animation(
			customer.get_node("WorkstationTaskPublisher"),
			customer.get_node("TaskRequestIndicator"),
			8.0,
			customer_path,
			true,
		)
	await _wait_process_frames(40)
	for customer_path in customer_paths:
		_check_open_animation_finished(
			level.get_node("%s/TaskRequestIndicator" % customer_path),
			customer_path,
		)
	await _request_at_station(
		player,
		level.get_node("Oven") as StaticBody2D,
		"Oven",
		&"potato",
	)
	await _request_at_station(
		player,
		level.get_node("Stove") as StaticBody2D,
		"Stove",
		&"chopped_potatoes",
	)

	level.queue_free()
	await process_frame
	print("cooking_station_requests_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _request_at_station(
	player: CharacterBody2D,
	station: StaticBody2D,
	station_name: String,
	expected_item_id: StringName,
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
		indicator.visible
		and publisher.get("CurrentRequestedItem").get("Id") == expected_item_id,
		"%s must show its requested ingredient after the player tap." % station_name,
	)
	_check_request_animation(publisher, indicator, 24.0, station_name, false)
	await _wait_process_frames(20)
	_check_open_animation_finished(indicator, station_name)

	publisher.set("RequestMode", 0)
	await process_frame
	var bubble := indicator.get_node("Background") as AnimatedSprite2D
	_check(
		bubble.is_playing() and bubble.frame < 3,
		"%s must replay its bubble opening when its request is republished." % station_name,
	)


func _check_request_animation(
	publisher: Node,
	indicator: Node2D,
	indicator_fps: float,
	label: String,
	expect_timer: bool,
) -> void:
	var bubble := indicator.get_node("Background") as AnimatedSprite2D
	var icon := indicator.get_node("Icon") as Sprite2D
	var secondary_icon := indicator.get_node("SecondaryIcon") as Sprite2D
	var timer_bar := indicator.get_node("TimerBar") as Sprite2D
	_check(
		bubble != null
			and bubble.sprite_frames.has_animation(&"open")
			and bubble.sprite_frames.get_frame_count(&"open") == 4
			and not bubble.sprite_frames.get_animation_loop(&"open"),
		"%s must use the four-frame, non-looping bubble opening." % label,
	)
	_check(
		is_equal_approx(
			float(publisher.get("RequestIndicatorOpenFramesPerSecond")),
			indicator_fps,
		),
		"%s must open its bubble at %.0f frames per second." % [label, indicator_fps],
	)
	_check(
		indicator.visible
			and bubble.is_playing()
			and bubble.frame < 3
			and icon.texture != null,
		"%s must animate its bubble while retaining the requested-item icon." % label,
	)
	_check(
		timer_bar.visible == expect_timer,
		"%s timer visibility must match its customer-order role." % label,
	)
	_check(
		not secondary_icon.visible,
		"%s must hide the unused second ingredient icon." % label,
	)


func _check_open_animation_finished(indicator: Node2D, label: String) -> void:
	var bubble := indicator.get_node("Background") as AnimatedSprite2D
	_check(
		bubble.frame == 3,
		(
			"%s must hold the fully open bubble after its animation "
			+ "(frame=%s)."
		) % [label, bubble.frame],
	)


func _tap_interact() -> void:
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await _wait_physics_frames(2)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _wait_process_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)