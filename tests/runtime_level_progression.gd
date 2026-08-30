extends SceneTree

const LEVEL_1_PATH := "res://scenes/level_1.tscn"
const LEVEL_2_PATH := "res://scenes/level_2.tscn"
const LEVEL_3_PATH := "res://scenes/level_3.tscn"
const WIN_SCREEN_PATH := "res://scenes/win_screen.tscn"

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
		hud.apply_customer_order_outcome(0)
	await process_frame
	_check(
		_is_win_audio_playing(),
		"Winning Level 1 must play the configured win sound.",
	)
	_check(
		_has_single_confetti_burst(),
		"Winning Level 1 must show one visible confetti burst.",
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
	_check(
		_count_confetti_bursts() == 0,
		"The Level 1 confetti burst must clean up after playback.",
	)
	hud = current_scene.get_node("Hud")
	var instant_win_event := InputEventAction.new()
	instant_win_event.action = &"debug_instant_win"
	instant_win_event.pressed = true
	hud._unhandled_input(instant_win_event)
	hud._unhandled_input(instant_win_event)
	await process_frame
	_check(
		_is_win_audio_playing(),
		"F10 must play the configured win sound.",
	)
	_check(
		_has_single_confetti_burst(),
		"F10 must show one visible confetti burst.",
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
	_check(
		_count_confetti_bursts() == 0,
		"The Level 2 confetti burst must clean up after playback.",
	)
	hud = current_scene.get_node("Hud")
	hud._unhandled_input(instant_win_event)
	hud._unhandled_input(instant_win_event)
	await process_frame
	_check(
		_is_win_audio_playing()
			and _has_single_confetti_burst()
			and _has_circle_transition(),
		"Winning Level 3 must celebrate and start the circle transition.",
	)
	await create_timer(1.5, true, false, true).timeout
	_check(
		current_scene.scene_file_path == WIN_SCREEN_PATH,
		"Winning Level 3 must open the win screen.",
	)
	var heading := current_scene.get_node_or_null(
		"Scroll/ParchmentMask/Heading",
	) as Label
	_check(
		heading != null
			and heading.text == "You Win!"
			and heading.get_theme_font("font").resource_path
				== "res://fonts/Pixel Game.otf",
		"The win screen must show 'You Win!' in the menu font.",
	)
	_check(
		current_scene.has_node("Scroll/ParchmentMask/CookButton")
			and current_scene.has_node("Scroll/ParchmentMask/TutorialButton")
			and current_scene.has_node("Scroll/ParchmentMask/ExitButton"),
		"The win screen must retain all main-menu buttons.",
	)
	_check(
		not current_scene.get_node("Scroll/ParchmentMask/AtTitle").visible
			and not current_scene.get_node("Scroll/ParchmentMask/YourTitle").visible
			and not current_scene.get_node("Scroll/ParchmentMask/ServiceTitle").visible,
		"The win heading must replace the main-menu title artwork.",
	)
	await create_timer(1.0, true, false, true).timeout
	await process_frame
	_check(
		_count_win_audio_players() == 0 and _count_confetti_bursts() == 0,
		"The terminal celebration must clean up after playback.",
	)

	var music_player := current_scene.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
		music_player.queue_free()
		await create_timer(0.25, true, false, true).timeout
	current_scene.queue_free()
	await process_frame
	await process_frame
	print("level_progression_runtime=", "failed" if _failed else "passed")
	quit(1 if _failed else 0)


func _has_circle_transition() -> bool:
	for child in root.get_children():
		var script := child.get_script() as Script
		if script != null and script.resource_path == "res://src/circle_transition.gd":
			return true
	return false


func _is_win_audio_playing() -> bool:
	var playing_count := 0
	for child in root.get_children():
		if _is_win_audio_player(child) and child.playing:
			playing_count += 1
	return _count_win_audio_players() == 1 and playing_count == 1


func _has_single_confetti_burst() -> bool:
	for child in root.get_children():
		if child.name == &"WinConfetti":
			return (
				_count_confetti_bursts() == 1
				and child is CanvasLayer
				and _count_visible_colored_pieces(child) >= 24
			)
	return false


func _count_visible_colored_pieces(burst: Node) -> int:
	var visible_piece_count := 0
	for child in burst.get_children():
		var piece := child as ColorRect
		if (
			piece != null
			and piece.is_visible_in_tree()
			and piece.color != Color.WHITE
			and piece.modulate.a > 0.0
			and piece.size.x > 0.0
			and piece.size.y > 0.0
		):
			visible_piece_count += 1
	return visible_piece_count


func _count_confetti_bursts() -> int:
	var burst_count := 0
	for child in root.get_children():
		if child.name == &"WinConfetti":
			burst_count += 1
	return burst_count


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
