class_name GameOverController
extends CanvasLayer

enum GameOverPhase {
	PLAYING,
	PANNING_TO_DEATH,
	PANNING_TO_PLAYER,
	FADING,
	EXECUTIONER_IDLE,
	EXECUTIONER_WALKING,
	TAKEOUT,
	CHOP,
	COMPLETE,
}

const GAME_OVER_ACTION := &"game_over"
const FOCUS_UV_PARAMETER := &"focus_uv"
const PROGRESS_PARAMETER := &"progress"
const EXECUTIONER_SCENE_PATH := "res://scenes/executioner.tscn"
const TITLE_SCENE_PATH := "res://scenes/title_screen.tscn"
const BABY_DEATH_SOUND_PATH := "res://assets/sounds/baby_death.wav"

## Group joined so other systems can trigger game over via call_group.
const GAME_OVER_GROUP := &"game_over_controllers"

@export var PlayerPath: NodePath = NodePath("../Player")
@export_range(0.05, 5, 0.05, "or_greater") var DeathPanDuration: float = 0.5
@export_range(0, 5, 0.05, "or_greater") var DeathPanHoldDuration: float = 0.6
@export_range(0.05, 5, 0.05, "or_greater") var ReturnPanDuration: float = 0.5
@export_range(0.1, 5, 0.1, "or_greater") var RevealDuration: float = 0.75
@export_range(0.1, 5, 0.1, "or_greater") var ExecutionerIdleDuration: float = 1.0
@export_range(10, 1000, 1, "or_greater") var ExecutionerWalkSpeed: float = 220.0

var _player: Node2D
var _camera: Camera2D
var _overlay: ColorRect
var _overlay_material: ShaderMaterial
var _death_audio: AudioStreamPlayer
var _executioner: Executioner
var _phase: GameOverPhase = GameOverPhase.PLAYING
var _elapsed: float = 0.0
var _camera_pan_start_position: Vector2 = Vector2.ZERO
var _death_global_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RevealDuration = maxf(RevealDuration, 0.1)
	ExecutionerIdleDuration = maxf(ExecutionerIdleDuration, 0.1)
	ExecutionerWalkSpeed = maxf(ExecutionerWalkSpeed, 10.0)
	_player = get_node(PlayerPath) as Node2D
	_camera = _player.get_node("Camera2D") as Camera2D

	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = load("res://assets/shaders/game_over.gdshader")

	_overlay = ColorRect.new()
	_overlay.material = _overlay_material
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	_death_audio = AudioStreamPlayer.new()
	_death_audio.stream = load(BABY_DEATH_SOUND_PATH)
	add_child(_death_audio)

	add_to_group(GAME_OVER_GROUP)


func _process(delta: float) -> void:
	if not get_tree().paused and Input.is_action_just_pressed(GAME_OVER_ACTION):
		trigger_game_over()

	if _phase == GameOverPhase.PLAYING or _phase == GameOverPhase.COMPLETE:
		return

	_elapsed += delta

	if _phase == GameOverPhase.PANNING_TO_DEATH:
		_update_camera_pan(_camera_pan_start_position, _death_global_position, DeathPanDuration)
		if _elapsed >= DeathPanDuration + DeathPanHoldDuration:
			_camera_pan_start_position = _camera.global_position
			_phase = GameOverPhase.PANNING_TO_PLAYER
			_elapsed = 0.0
		return

	if _phase == GameOverPhase.PANNING_TO_PLAYER:
		_update_camera_pan(_camera_pan_start_position, _player.global_position, ReturnPanDuration)
		if _elapsed >= ReturnPanDuration:
			_phase = GameOverPhase.FADING
			_elapsed = 0.0
			_overlay.visible = true
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var screen_position := get_viewport().canvas_transform * _player.global_position
	var focus_uv := screen_position / viewport_size
	_overlay_material.set_shader_parameter(FOCUS_UV_PARAMETER, focus_uv)

	if _phase == GameOverPhase.FADING:
		var progress := clampf(_elapsed / RevealDuration, 0.0, 1.0)
		_overlay_material.set_shader_parameter(PROGRESS_PARAMETER, progress)
		if progress >= 1.0:
			_spawn_executioner()
		return

	if _phase == GameOverPhase.EXECUTIONER_IDLE:
		if _elapsed >= ExecutionerIdleDuration:
			_phase = GameOverPhase.EXECUTIONER_WALKING
			_executioner.play_walk()
		return

	if _phase == GameOverPhase.EXECUTIONER_WALKING:
		_update_executioner_walk(delta)


func trigger_game_over() -> void:
	trigger_game_over_at(_player.global_position)


func trigger_game_over_at(death_global_position: Vector2) -> void:
	if _phase != GameOverPhase.PLAYING:
		return

	_death_audio.play()
	_death_global_position = death_global_position
	_camera_pan_start_position = _camera.global_position
	_phase = GameOverPhase.PANNING_TO_DEATH
	_elapsed = 0.0
	get_tree().paused = true


func _update_camera_pan(
	from_global_position: Vector2,
	to_global_position: Vector2,
	duration: float
) -> void:
	var progress := clampf(_elapsed / duration, 0.0, 1.0) if duration > 0.0 else 1.0
	_camera.global_position = from_global_position.lerp(to_global_position, progress)


func _spawn_executioner() -> void:
	var executioner_scene := load(EXECUTIONER_SCENE_PATH) as PackedScene
	if executioner_scene == null:
		push_error("Could not load executioner scene at '%s'." % EXECUTIONER_SCENE_PATH)
		return

	_executioner = executioner_scene.instantiate()
	_executioner.process_mode = Node.PROCESS_MODE_ALWAYS
	_executioner.global_position = Vector2(_player.global_position.x, -64.0)
	_executioner.animation_finished.connect(_on_executioner_animation_finished)
	get_tree().current_scene.add_child(_executioner)
	_executioner.play_idle()
	_phase = GameOverPhase.EXECUTIONER_IDLE
	_elapsed = 0.0


func _update_executioner_walk(delta: float) -> void:
	var target_position := _player.global_position + Vector2(0.0, -110.0)
	_executioner.global_position = _executioner.global_position.move_toward(
		target_position,
		ExecutionerWalkSpeed * delta
	)
	if _executioner.global_position.is_equal_approx(target_position):
		_phase = GameOverPhase.TAKEOUT
		_executioner.play_takeout()


func _on_executioner_animation_finished() -> void:
	if _phase == GameOverPhase.TAKEOUT:
		_phase = GameOverPhase.CHOP
		_executioner.play_chop()
	elif _phase == GameOverPhase.CHOP:
		_show_completion_menu()


func _show_completion_menu() -> void:
	_phase = GameOverPhase.COMPLETE
	_overlay.material = null
	_overlay.color = Color.BLACK

	var menu := VBoxContainer.new()
	menu.anchor_left = 0.5
	menu.anchor_top = 0.5
	menu.anchor_right = 0.5
	menu.anchor_bottom = 0.5
	menu.offset_left = -96.0
	menu.offset_top = -48.0
	menu.offset_right = 96.0
	menu.offset_bottom = 48.0
	menu.mouse_filter = Control.MOUSE_FILTER_STOP

	var retry_button := Button.new()
	retry_button.name = "RetryButton"
	retry_button.text = "Retry"
	retry_button.custom_minimum_size = Vector2(192.0, 40.0)
	retry_button.focus_neighbor_top = NodePath("../ExitButton")
	retry_button.focus_neighbor_bottom = NodePath("../ExitButton")

	var exit_button := Button.new()
	exit_button.name = "ExitButton"
	exit_button.text = "Exit"
	exit_button.custom_minimum_size = Vector2(192.0, 40.0)
	exit_button.focus_neighbor_top = NodePath("../RetryButton")
	exit_button.focus_neighbor_bottom = NodePath("../RetryButton")

	retry_button.pressed.connect(_restart_scene)
	exit_button.pressed.connect(_return_to_title)
	menu.add_child(retry_button)
	menu.add_child(exit_button)
	add_child(menu)
	retry_button.grab_focus()


func _restart_scene() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _return_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)
