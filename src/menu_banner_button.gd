class_name MenuBannerButton
extends TextureButton

@export_range(-12, 12, 0.5) var HoverRotationDegrees: float = -3.0
@export_range(0.05, 1, 0.05, "or_greater") var TiltDuration: float = 0.18
@export_range(1, 1.2, 0.01) var FocusScale: float = 1.06
@export var FocusColor: Color = Color(1.0, 0.88, 0.55)

var _presentation_tween: Tween
var _has_focus: bool = false
var _is_hovered: bool = false


func _ready() -> void:
	pivot_offset = size * 0.5
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)


func refresh_input_mode_presentation() -> void:
	_update_presentation()


func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_presentation()


func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_presentation()


func _on_focus_entered() -> void:
	_has_focus = true
	_update_presentation()


func _on_focus_exited() -> void:
	_has_focus = false
	_update_presentation()


func _update_presentation() -> void:
	if _presentation_tween != null:
		_presentation_tween.kill()
	_presentation_tween = create_tween()
	_presentation_tween.set_parallel()
	_presentation_tween.set_trans(Tween.TRANS_BACK)
	_presentation_tween.set_ease(Tween.EASE_OUT)

	var is_controller_focused := _has_focus and MenuInputMode.IsControllerActive
	var is_highlighted := _is_hovered or is_controller_focused
	var target_rotation := deg_to_rad(HoverRotationDegrees if is_highlighted else 0.0)
	var target_scale := Vector2.ONE * (FocusScale if is_controller_focused else 1.0)
	var target_color := FocusColor if is_highlighted else Color.WHITE

	_presentation_tween.tween_property(self, "rotation", target_rotation, TiltDuration)
	_presentation_tween.tween_property(self, "scale", target_scale, TiltDuration)
	_presentation_tween.tween_property(self, "self_modulate", target_color, TiltDuration)
