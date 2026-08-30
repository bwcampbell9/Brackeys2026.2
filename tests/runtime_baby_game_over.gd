extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CHOP_RECIPE := preload("res://resources/recipes/chop.tres")
const COOK_RECIPE := preload("res://resources/recipes/cook.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _load_main_scene()
	var baby := current_scene.get_node("BabyPickupItem")
	_check(bool(CHOP_RECIPE.Apply(baby)), "The baby fixture must accept chopping.")
	await process_frame
	_check_baby_cinematic("Chopping")

	await _load_main_scene()
	baby = current_scene.get_node("BabyPickupItem")
	_check(bool(COOK_RECIPE.Apply(baby)), "The baby fixture must accept cooking.")
	await process_frame
	_check_baby_cinematic("Cooking")

	await _load_main_scene()
	baby = current_scene.get_node("BabyPickupItem")
	var customer_socket := current_scene.get_node("Customer/PickupSocket")
	_check(
		bool(customer_socket.TryStore(baby, 0.0)),
		"The active customer must accept the baby as a fatal delivery.",
	)
	await process_frame
	_check_baby_cinematic("Eating")
	await _send_action(&"pause")
	_check(not paused, "Pause input must not interrupt the baby cinematic.")
	_check(
		not current_scene.get_node("PauseMenu").visible,
		"Pause input must not cover the baby cinematic.",
	)

	await create_timer(1.5, true, false, true).timeout
	var overlay := current_scene.get_node("GameOverController").get_child(0) as ColorRect
	_check(paused, "The baby cinematic must hand off to game over.")
	_check(overlay.visible, "Game over must reveal its overlay after the baby cinematic.")
	_check(is_equal_approx(Engine.time_scale, 1.0), "Game over must restore normal time.")

	paused = false
	current_scene.queue_free()
	await process_frame
	print("baby_game_over_runtime=", "failed" if _failed else "passed")
	quit(1 if _failed else 0)


func _load_main_scene() -> void:
	paused = false
	Engine.time_scale = 1.0
	change_scene_to_packed(MAIN_SCENE)
	await process_frame
	await process_frame
	current_scene.get_node("NpcWorker/NpcTaskRunner").process_mode = Node.PROCESS_MODE_DISABLED


func _check_baby_cinematic(action: String) -> void:
	_check(
		is_equal_approx(Engine.time_scale, 0.2),
		"%s the baby must start slow motion." % action,
	)
	var camera := current_scene.get_node_or_null("BabyDeathCamera") as Camera2D
	_check(camera != null, "%s the baby must create a focus camera." % action)
	if camera != null:
		_check(camera.is_current(), "%s the baby must activate the focus camera." % action)


func _send_action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	root.push_input(press)
	await process_frame

	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	root.push_input(release)
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
