class_name PauseMenu
extends CanvasLayer

const _PAUSE_ACTION := &"pause"
const _CANCEL_ACTION := &"ui_cancel"
const _ACCEPT_ACTION := &"ui_accept"
const _TITLE_SCENE_PATH := "res://scenes/title_screen.tscn"

@export var PlayerInputManagerPath: NodePath = NodePath("../Player/InputManager")
@export_range(0.1, 2.0, 0.05, "or_greater") var DropDuration: float = 0.3
@export_range(0.0, 1.0, 0.05, "or_greater") var OpenDelay: float = 0.048
@export_range(0.1, 2.0, 0.05, "or_greater") var OpenDuration: float = 0.39

var _resume_button: MenuBannerButton
var _title_button: MenuBannerButton
var _quit_button: MenuBannerButton
var _player_input_manager: PlayerInputManager
var _scroll: Control
var _parchment_mask: Control
var _parchment: TextureRect
var _top_roll: TextureRect
var _bottom_roll: TextureRect
var _scroll_tween: Tween
var _scroll_rest_position: Vector2 = Vector2.ZERO
var _top_roll_open_position: Vector2 = Vector2.ZERO
var _bottom_roll_open_position: Vector2 = Vector2.ZERO
var _mask_open_position: Vector2 = Vector2.ZERO
var _mask_open_size: Vector2 = Vector2.ZERO
var _parchment_open_position: Vector2 = Vector2.ZERO
var _is_open: bool = false
var _is_transitioning: bool = false
var _resume_pending: bool = false
var _blocking_action_release_observed: bool = false
var _resume_blocking_action: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_input_manager = get_node(PlayerInputManagerPath) as PlayerInputManager
	_scroll = get_node("Overlay/Scroll") as Control
	_parchment_mask = get_node("Overlay/Scroll/ParchmentMask") as Control
	_parchment = get_node("Overlay/Scroll/ParchmentMask/Parchment") as TextureRect
	_top_roll = get_node("Overlay/Scroll/TopRoll") as TextureRect
	_bottom_roll = get_node("Overlay/Scroll/BottomRoll") as TextureRect
	_resume_button = get_node("Overlay/Scroll/ParchmentMask/ResumeButton") as MenuBannerButton
	_title_button = get_node("Overlay/Scroll/ParchmentMask/TitleButton") as MenuBannerButton
	_quit_button = get_node("Overlay/Scroll/ParchmentMask/QuitButton") as MenuBannerButton

	_scroll_rest_position = _scroll.position
	_top_roll_open_position = _top_roll.position
	_bottom_roll_open_position = _bottom_roll.position
	_mask_open_position = _parchment_mask.position
	_mask_open_size = _parchment_mask.size
	_parchment_open_position = _parchment.position

	_resume_button.pressed.connect(_resume_from_selection)
	_title_button.pressed.connect(_return_to_title)
	_quit_button.pressed.connect(_quit_game)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	visible = false


func _process(_delta: float) -> void:
	if not _resume_pending:
		return

	if Input.is_action_pressed(_resume_blocking_action):
		_blocking_action_release_observed = false
		return

	if not _blocking_action_release_observed:
		_blocking_action_release_observed = true
		return

	_resume_pending = false
	_blocking_action_release_observed = false
	_resume_blocking_action = &""
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	var was_controller_active := MenuInputMode.IsControllerActive
	if not MenuInputMode.observe(event) or not _is_open:
		return

	if not MenuInputMode.IsControllerActive:
		if MenuInputMode.is_keyboard_input(event):
			_release_menu_focus()
		_refresh_menu_presentation()
		return

	if not was_controller_active or not _has_menu_focus():
		_resume_button.grab_focus()
	_refresh_menu_presentation()


func _unhandled_input(event: InputEvent) -> void:
	var pause_pressed := event.is_action_pressed(_PAUSE_ACTION)
	var cancel_pressed := _is_open and event.is_action_pressed(_CANCEL_ACTION)
	if _is_transitioning and (pause_pressed or cancel_pressed):
		get_viewport().set_input_as_handled()
		return

	if not pause_pressed and not cancel_pressed:
		return

	if _is_open:
		if cancel_pressed:
			_begin_resume(_CANCEL_ACTION)
		else:
			_close_menu()
	elif not get_tree().paused:
		_open_menu()

	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
	if _is_open or _resume_pending:
		get_tree().paused = false


func _open_menu() -> void:
	_resume_pending = false
	_blocking_action_release_observed = false
	_resume_blocking_action = &""
	_is_open = true
	visible = true
	get_tree().paused = true
	if MenuInputMode.IsControllerActive:
		_resume_button.grab_focus()
	else:
		_release_menu_focus()
	_play_scroll_opening()


func _close_menu() -> void:
	_resume_pending = false
	_blocking_action_release_observed = false
	_resume_blocking_action = &""
	if _scroll_tween != null:
		_scroll_tween.kill()
	get_tree().paused = false
	_is_open = false
	visible = false


func _resume_from_selection() -> void:
	_begin_resume(_ACCEPT_ACTION)


func _begin_resume(blocking_action: StringName) -> void:
	_player_input_manager.suppress_current_gameplay_input()
	if _scroll_tween != null:
		_scroll_tween.kill()
	_is_open = false
	visible = false
	_resume_pending = true
	_blocking_action_release_observed = false
	_resume_blocking_action = blocking_action


func _return_to_title() -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	_resume_button.disabled = true
	_title_button.disabled = true
	_quit_button.disabled = true

	var player: Node2D = _player_input_manager.get_parent() as Node2D
	var close_center: Vector2 = player.get_global_transform_with_canvas().origin
	var transition := CircleTransition.new()
	get_tree().root.add_child(transition)
	var result: Error = await transition.transition_to_scene(
		_TITLE_SCENE_PATH,
		NodePath(""),
		close_center,
		true,
		true
	)
	if result == OK or not is_instance_valid(self):
		return

	get_tree().paused = true
	_is_transitioning = false
	_resume_button.disabled = false
	_title_button.disabled = false
	_quit_button.disabled = false


func _quit_game() -> void:
	get_tree().quit()


func _play_scroll_opening() -> void:
	if _scroll_tween != null:
		_scroll_tween.kill()

	var closed_roll_y := (_top_roll_open_position.y + _bottom_roll_open_position.y) * 0.5
	_top_roll.position = Vector2(_top_roll_open_position.x, closed_roll_y)
	_bottom_roll.position = Vector2(_bottom_roll_open_position.x, closed_roll_y)
	_parchment_mask.position = Vector2(
		_mask_open_position.x,
		closed_roll_y + (_top_roll.size.y * 0.5)
	)
	_parchment_mask.size = Vector2(_mask_open_size.x, 0.0)
	_parchment.position = Vector2(
		_parchment_open_position.x,
		_parchment_open_position.y - (_parchment_mask.position.y - _mask_open_position.y)
	)
	_scroll.position = _scroll_rest_position - Vector2(
		0.0,
		get_viewport().get_visible_rect().size.y + _scroll.size.y
	)

	_scroll_tween = create_tween()
	_scroll_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_scroll_tween.tween_property(
		_scroll, "position", _scroll_rest_position, DropDuration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scroll_tween.tween_interval(OpenDelay)
	_scroll_tween.set_parallel()
	_scroll_tween.set_trans(Tween.TRANS_CUBIC)
	_scroll_tween.set_ease(Tween.EASE_IN_OUT)
	_scroll_tween.tween_property(_top_roll, "position", _top_roll_open_position, OpenDuration)
	_scroll_tween.tween_property(
		_bottom_roll, "position", _bottom_roll_open_position, OpenDuration
	)
	_scroll_tween.tween_property(_parchment_mask, "position", _mask_open_position, OpenDuration)
	_scroll_tween.tween_property(_parchment_mask, "size", _mask_open_size, OpenDuration)
	_scroll_tween.tween_property(_parchment, "position", _parchment_open_position, OpenDuration)


func _has_menu_focus() -> bool:
	return (
		_resume_button.has_focus()
		or _title_button.has_focus()
		or _quit_button.has_focus()
	)


func _release_menu_focus() -> void:
	_resume_button.release_focus()
	_title_button.release_focus()
	_quit_button.release_focus()


func _refresh_menu_presentation() -> void:
	_resume_button.refresh_input_mode_presentation()
	_title_button.refresh_input_mode_presentation()
	_quit_button.refresh_input_mode_presentation()


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected or Input.get_connected_joypads().size() > 0:
		return

	MenuInputMode.deactivate_controller()
	_release_menu_focus()
