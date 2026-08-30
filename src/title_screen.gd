class_name TitleScreen
extends Control

const _LEVEL_ONE_SCENE_PATH := "res://scenes/level_1.tscn"
const _TUTORIAL_SCENE_PATH := "res://scenes/tutorial_screen.tscn"
const _LEVEL_ONE_PLAYER_PATH := ^"Player"

@export_range(0.1, 2.0, 0.05, "or_greater") var _dropDuration: float = 0.65
@export_range(0.0, 1.0, 0.05, "or_greater") var _openDelay: float = 0.1
@export_range(0.1, 2.0, 0.05, "or_greater") var _openDuration: float = 0.85

var _scroll: Control
var _parchment_mask: Control
var _parchment: TextureRect
var _top_roll: TextureRect
var _bottom_roll: TextureRect
var _cook_button: MenuBannerButton
var _tutorial_button: MenuBannerButton
var _exit_button: MenuBannerButton
var _menu_enabled: bool = false
var _is_transitioning: bool = false


func _ready() -> void:
	_scroll = get_node("Scroll") as Control
	_parchment_mask = get_node("Scroll/ParchmentMask") as Control
	_parchment = get_node("Scroll/ParchmentMask/Parchment") as TextureRect
	_top_roll = get_node("Scroll/TopRoll") as TextureRect
	_bottom_roll = get_node("Scroll/BottomRoll") as TextureRect
	_cook_button = get_node("Scroll/ParchmentMask/CookButton") as MenuBannerButton
	_tutorial_button = get_node("Scroll/ParchmentMask/TutorialButton") as MenuBannerButton
	_exit_button = get_node("Scroll/ParchmentMask/ExitButton") as MenuBannerButton
	_set_menu_enabled(false)
	_cook_button.pressed.connect(_on_cook_pressed)
	_tutorial_button.pressed.connect(_on_tutorial_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	var scroll_rest_position := _scroll.position
	var top_roll_open_position := _top_roll.position
	var bottom_roll_open_position := _bottom_roll.position
	var mask_open_position := _parchment_mask.position
	var mask_open_size := _parchment_mask.size
	var parchment_open_position := _parchment.position

	var closed_roll_y := (top_roll_open_position.y + bottom_roll_open_position.y) * 0.5
	_top_roll.position = Vector2(top_roll_open_position.x, closed_roll_y)
	_bottom_roll.position = Vector2(bottom_roll_open_position.x, closed_roll_y)
	_parchment_mask.position = Vector2(
		mask_open_position.x, closed_roll_y + (_top_roll.size.y * 0.5)
	)
	_parchment_mask.size = Vector2(mask_open_size.x, 0.0)
	_parchment.position = Vector2(
		parchment_open_position.x,
		parchment_open_position.y - (_parchment_mask.position.y - mask_open_position.y)
	)
	_scroll.position = scroll_rest_position - Vector2(0.0, size.y + _scroll.size.y)

	var tween := create_tween()
	tween.tween_property(
		_scroll, "position", scroll_rest_position, _dropDuration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(_openDelay)

	tween.set_parallel()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_top_roll, "position", top_roll_open_position, _openDuration)
	tween.tween_property(_bottom_roll, "position", bottom_roll_open_position, _openDuration)
	tween.tween_property(_parchment_mask, "position", mask_open_position, _openDuration)
	tween.tween_property(_parchment_mask, "size", mask_open_size, _openDuration)
	tween.tween_property(_parchment, "position", parchment_open_position, _openDuration)
	tween.tween_callback(_enable_menu)


func _input(event: InputEvent) -> void:
	var was_controller_active := MenuInputMode.IsControllerActive
	if not MenuInputMode.observe(event) or not _menu_enabled:
		return

	if not MenuInputMode.IsControllerActive:
		if MenuInputMode.is_keyboard_input(event):
			_release_menu_focus()
		_refresh_menu_presentation()
		return

	if not was_controller_active or not _has_menu_focus():
		_cook_button.grab_focus()
	_refresh_menu_presentation()


func _exit_tree() -> void:
	Input.joy_connection_changed.disconnect(_on_joy_connection_changed)


func _enable_menu() -> void:
	_set_menu_enabled(true)
	if MenuInputMode.IsControllerActive:
		_cook_button.grab_focus()
	else:
		_release_menu_focus()


func _set_menu_enabled(enabled: bool) -> void:
	_menu_enabled = enabled
	_cook_button.disabled = not enabled
	_tutorial_button.disabled = not enabled
	_exit_button.disabled = not enabled


func _on_cook_pressed() -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	_set_menu_enabled(false)

	var transition := CircleTransition.new()
	get_tree().root.add_child(transition)
	var close_center: Vector2 = _cook_button.global_position + (_cook_button.size * 0.5)
	var result: Error = await transition.transition_to_scene(
		_LEVEL_ONE_SCENE_PATH,
		_LEVEL_ONE_PLAYER_PATH,
		close_center
	)
	if result != OK and is_instance_valid(self):
		_is_transitioning = false
		_set_menu_enabled(true)
		if MenuInputMode.IsControllerActive:
			_cook_button.grab_focus()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_tutorial_pressed() -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	_set_menu_enabled(false)
	var result: Error = get_tree().change_scene_to_file(_TUTORIAL_SCENE_PATH)
	if result != OK and is_instance_valid(self):
		_is_transitioning = false
		_set_menu_enabled(true)
		if MenuInputMode.IsControllerActive:
			_tutorial_button.grab_focus()


func _has_menu_focus() -> bool:
	return (
		_cook_button.has_focus()
		or _tutorial_button.has_focus()
		or _exit_button.has_focus()
	)


func _release_menu_focus() -> void:
	_cook_button.release_focus()
	_tutorial_button.release_focus()
	_exit_button.release_focus()


func _refresh_menu_presentation() -> void:
	_cook_button.refresh_input_mode_presentation()
	_tutorial_button.refresh_input_mode_presentation()
	_exit_button.refresh_input_mode_presentation()


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected or Input.get_connected_joypads().size() > 0:
		return

	MenuInputMode.deactivate_controller()
	_release_menu_focus()
