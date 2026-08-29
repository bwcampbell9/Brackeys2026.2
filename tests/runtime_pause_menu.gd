extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_pause_bindings()
	_check_controller_ui_bindings()
	change_scene_to_packed(MAIN_SCENE)
	await process_frame
	await process_frame

	var pause_menu := current_scene.get_node_or_null("PauseMenu") as CanvasLayer
	_check(pause_menu != null, "The main scene must contain the pause menu.")
	if pause_menu == null:
		_finish()
		return

	_check(not paused, "Gameplay must begin unpaused.")
	_check(not pause_menu.visible, "The pause menu must begin hidden.")

	await _send_action(&"pause")
	_check(paused, "The pause action must pause the scene tree.")
	_check(pause_menu.visible, "The pause action must show the pause menu.")
	_check(
		root.gui_get_focus_owner() == pause_menu.get_node(
			"Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton"
		),
		"Opening the pause menu must focus Resume for controller input.",
	)

	Input.action_press(&"game_over")
	await process_frame
	Input.action_release(&"game_over")
	await process_frame
	var game_over_overlay := current_scene.get_node("GameOverController").get_child(0) as ColorRect
	_check(
		not game_over_overlay.visible,
		"Game over must not start while the pause menu owns the paused state.",
	)

	await _send_action(&"ui_down")
	_check(
		root.gui_get_focus_owner() == pause_menu.get_node(
			"Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleButton"
		),
		"Controller navigation must move focus to Return to Title.",
	)

	var carrier := current_scene.get_node("Player/PickupCarrier")
	var held_item := current_scene.get_node("RecipeBookItem")
	_check(bool(carrier.TryHold(held_item)), "The resume fixture must hold the recipe book.")
	await _send_joy_button(JOY_BUTTON_B)
	_check(not paused, "Controller B must resume gameplay.")
	_check(not pause_menu.visible, "Controller B must hide the pause menu.")
	_check(
		not bool(held_item.get("IsOpening")),
		"Controller B used to resume must not also open the held recipe book.",
	)

	await _send_action(&"pause")
	await _send_joy_button(JOY_BUTTON_A)
	_check(not paused, "Activating Resume must unpause gameplay.")
	_check(not pause_menu.visible, "Activating Resume must hide the pause menu.")
	_check(
		carrier.get("HeldItem") == held_item,
		"Controller A used to resume must not also trigger a gameplay interaction.",
	)

	await _send_action(&"pause")
	await _send_action(&"ui_down")
	await _send_action(&"ui_accept")
	await process_frame
	await process_frame
	_check(
		current_scene != null
		and current_scene.scene_file_path == "res://scenes/title_screen.tscn",
		"Return to Title must load the title screen.",
	)
	_check(not paused, "Returning to the title screen must leave the scene tree unpaused.")

	var play_button := current_scene.get_node(
		"CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PlayButton"
	)
	var exit_button := current_scene.get_node(
		"CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ExitButton"
	)
	_check(root.gui_get_focus_owner() == play_button, "The title screen must focus Play.")
	await _send_action(&"ui_down")
	_check(
		root.gui_get_focus_owner() == exit_button,
		"Controller navigation must move focus between title screen buttons.",
	)

	_finish()


func _check_pause_bindings() -> void:
	var has_escape := false
	var has_controller_menu := false
	for event in InputMap.action_get_events(&"pause"):
		if event is InputEventKey and event.keycode == KEY_ESCAPE:
			has_escape = true
		elif event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START:
			has_controller_menu = true

	_check(has_escape, "Pause must be bound to Escape.")
	_check(has_controller_menu, "Pause must be bound to the controller Menu/Start button.")


func _check_controller_ui_bindings() -> void:
	var accept_has_controller_a := false
	for event in InputMap.action_get_events(&"ui_accept"):
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
			accept_has_controller_a = true

	var cancel_has_controller_b := false
	for event in InputMap.action_get_events(&"ui_cancel"):
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B:
			cancel_has_controller_b = true

	_check(accept_has_controller_a, "Controller A must activate the focused menu button.")
	_check(cancel_has_controller_b, "Controller B must map to closing the pause menu.")


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


func _send_joy_button(button_index: int) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button_index
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame

	var release := InputEventJoypadButton.new()
	release.button_index = button_index
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _finish() -> void:
	print("pause_menu_runtime=", "failed" if _failed else "passed")
	quit(1 if _failed else 0)
