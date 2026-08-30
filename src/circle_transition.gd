class_name CircleTransition
extends CanvasLayer

const _SHADER_PATH := "res://assets/shaders/circle_transition.gdshader"
const _CENTER_UV_PARAMETER := &"center_uv"
const _RADIUS_PROGRESS_PARAMETER := &"radius_progress"

var _material: ShaderMaterial


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_material = ShaderMaterial.new()
	_material.shader = load(_SHADER_PATH)

	var overlay := ColorRect.new()
	overlay.color = Color.BLACK
	overlay.material = _material
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


## Closes the circle, changes scene, then opens it around the reveal target.
## This is a coroutine (contains `await`); callers should `await` it the same
## way the C# source awaited the `Task<Error>` it returned.
func transition_to_scene(
	scene_path: String,
	reveal_target_path: NodePath,
	close_center: Vector2,
	reveal_at_viewport_center: bool = false,
	unpause_before_scene_change: bool = false,
	close_duration: float = 0.35,
	open_duration: float = 0.8
) -> Error:
	await _animate_radius(close_center, 1.0, 0.0, close_duration)

	var tree := get_tree()
	if unpause_before_scene_change:
		tree.paused = false

	var result := tree.change_scene_to_file(scene_path)
	if result != OK:
		push_error("Could not change to scene '%s': %s." % [scene_path, result])
		queue_free()
		return result

	var frame := 0
	while frame < 3 and tree.current_scene == null:
		await tree.process_frame
		frame += 1

	var reveal_center: Vector2
	if reveal_at_viewport_center:
		reveal_center = get_viewport().get_visible_rect().size * 0.5
	else:
		var reveal_target: Node2D = null
		if tree.current_scene != null:
			reveal_target = tree.current_scene.get_node_or_null(reveal_target_path) as Node2D
		if reveal_target == null:
			push_error(
				"Circle transition could not find reveal target '%s' in '%s'." % [
					reveal_target_path, scene_path
				]
			)
			queue_free()
			return ERR_DOES_NOT_EXIST

		reveal_center = reveal_target.get_global_transform_with_canvas().origin

	await _animate_radius(reveal_center, 0.0, 1.0, open_duration)
	queue_free()
	return OK


func _animate_radius(
	center: Vector2, start_radius: float, end_radius: float, duration: float
) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_material.set_shader_parameter(_CENTER_UV_PARAMETER, center / viewport_size)
	_material.set_shader_parameter(_RADIUS_PROGRESS_PARAMETER, start_radius)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT if end_radius > start_radius else Tween.EASE_IN)
	tween.tween_method(_set_radius_progress, start_radius, end_radius, maxf(duration, 0.05))
	await tween.finished


func _set_radius_progress(progress: float) -> void:
	_material.set_shader_parameter(_RADIUS_PROGRESS_PARAMETER, progress)
