extends SceneTree

const LEVEL_1_PATH := "res://scenes/level_1.tscn"
const LEVEL_2_PATH := "res://scenes/level_2.tscn"
const LEVEL_3_PATH := "res://scenes/level_3.tscn"

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file(LEVEL_1_PATH)
	await process_frame
	await process_frame
	_check(
		current_scene.scene_file_path == LEVEL_1_PATH,
		"The progression fixture must load Level 1.",
	)

	var hud := current_scene.get_node("Hud")
	for _index in range(10):
		hud.ApplyCustomerOrderOutcome(0)
	await process_frame
	_check(
		_has_circle_transition(),
		"Winning Level 1 must start the circle transition.",
	)

	await create_timer(1.5, true, false, true).timeout
	_check(
		current_scene.scene_file_path == LEVEL_2_PATH,
		"Winning Level 1 must load Level 2.",
	)

	hud = current_scene.get_node("Hud")
	for _index in range(10):
		hud.ApplyCustomerOrderOutcome(0)
	await process_frame
	_check(
		_has_circle_transition(),
		"Winning Level 2 must start the circle transition.",
	)

	await create_timer(1.5, true, false, true).timeout
	_check(
		current_scene.scene_file_path == LEVEL_3_PATH,
		"Winning Level 2 must load Level 3.",
	)

	current_scene.queue_free()
	await process_frame
	print("level_progression_runtime=", "failed" if _failed else "passed")
	quit(1 if _failed else 0)


func _has_circle_transition() -> bool:
	for child in root.get_children():
		var script := child.get_script() as Script
		if script != null and script.resource_path == "res://src/CircleTransition.cs":
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
