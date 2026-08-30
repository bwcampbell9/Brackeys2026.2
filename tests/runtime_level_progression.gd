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
		_is_win_audio_playing(),
		"Winning Level 1 must play the configured win sound.",
	)
	_check(
		_has_circle_transition(),
		"Winning Level 1 must start the circle transition.",
	)

	await create_timer(1.5, true, false, true).timeout
	_check(
		current_scene.scene_file_path == LEVEL_2_PATH,
		"Winning Level 1 must load Level 2.",
	)
	await create_timer(1.0, true, false, true).timeout
	await process_frame
	_check(
		_count_win_audio_players() == 0,
		"The Level 1 win sound must clean up after playback.",
	)
	hud = current_scene.get_node("Hud")
	var instant_win_event := InputEventAction.new()
	instant_win_event.action = &"debug_instant_win"
	instant_win_event.pressed = true
	hud._UnhandledInput(instant_win_event)
	await process_frame
	_check(
		_is_win_audio_playing(),
		"F10 must play the configured win sound.",
	)
	_check(
		_has_circle_transition(),
		"F10 must start Level 2's circle transition.",
	)

	await create_timer(1.5, true, false, true).timeout
	_check(
		current_scene.scene_file_path == LEVEL_3_PATH,
		"Winning Level 2 must load Level 3.",
	)
	await create_timer(1.0, true, false, true).timeout
	await process_frame
	_check(
		_count_win_audio_players() == 0,
		"The Level 2 win sound must clean up after playback.",
	)
	hud = current_scene.get_node("Hud")
	hud._UnhandledInput(instant_win_event)
	await process_frame
	_check(
		_count_win_audio_players() == 0 and not _has_circle_transition(),
		"The terminal level must not play win audio or start another transition.",
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


func _is_win_audio_playing() -> bool:
	var playing_count := 0
	for child in root.get_children():
		if _is_win_audio_player(child) and child.playing:
			playing_count += 1
	return _count_win_audio_players() == 1 and playing_count == 1


func _count_win_audio_players() -> int:
	var player_count := 0
	for child in root.get_children():
		if _is_win_audio_player(child):
			player_count += 1
	return player_count


func _is_win_audio_player(node: Node) -> bool:
	return (
		node is AudioStreamPlayer
		and node.stream != null
		and node.stream.resource_path == "res://assets/sounds/win.wav"
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
