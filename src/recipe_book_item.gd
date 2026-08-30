class_name RecipeBookItem
extends PickupItem

const OPEN_ANIMATION := &"open"
const PREVIOUS_PAGE_ACTION := &"cookbook_previous_page"
const NEXT_PAGE_ACTION := &"cookbook_next_page"
const HIDDEN_OVERLAY_POSITION := Vector2(0.0, -304.0)

@export_range(0.05, 2, 0.01, "or_greater") var OverlayShowDuration: float = 0.35
@export_range(0.05, 2, 0.01, "or_greater") var OverlayHideDuration: float = 0.25

var _sprite: AnimatedSprite2D
var _open_audio: AudioStreamPlayer2D
var _close_audio: AudioStreamPlayer2D
var _forward_page_audio: AudioStreamPlayer2D
var _backward_page_audio: AudioStreamPlayer2D
var _overlay_root: Control
var _overlay_image: TextureRect
var _second_page_image: TextureRect
var _previous_page_button: Button
var _next_page_button: Button
var _overlay_tween: Tween
var _overlay_shown_for_player: bool = false
var _page_index: int = 0

var _is_opening: bool = false
var _is_closing: bool = false
var _is_open: bool = false

var is_opening: bool:
	get:
		return _is_opening

var is_closing: bool:
	get:
		return _is_closing

var is_open: bool:
	get:
		return _is_open


func _ready() -> void:
	super._ready()
	_sprite = get_node("AnimatedSprite2D")
	_open_audio = get_node("OpenCookbookAudio")
	_close_audio = get_node("CloseCookbookAudio")
	_forward_page_audio = get_node("ForwardPageAudio")
	_backward_page_audio = get_node("BackwardPageAudio")
	_overlay_root = get_node("RecipeOverlay/OverlayRoot")
	_overlay_image = _overlay_root.get_node("Book")
	_second_page_image = _overlay_root.get_node("PageTwo")
	_previous_page_button = _overlay_root.get_node("PreviousPageButton")
	_next_page_button = _overlay_root.get_node("NextPageButton")
	_previous_page_button.pressed.connect(_show_previous_page)
	_next_page_button.pressed.connect(_show_next_page)

	if (
		not _sprite.sprite_frames.has_animation(OPEN_ANIMATION)
		or _sprite.sprite_frames.get_frame_count(OPEN_ANIMATION) != 6
		or _sprite.sprite_frames.get_animation_loop_mode(OPEN_ANIMATION) != SpriteFrames.LOOP_NONE
	):
		push_error("RecipeBookItem requires a non-looping six-frame 'open' animation.")
		return

	_sprite.animation = OPEN_ANIMATION
	_sprite.frame = 0
	_sprite.animation_finished.connect(_on_animation_finished)
	_overlay_root.position = HIDDEN_OVERLAY_POSITION
	_overlay_root.visible = false
	_set_page(0)
	_apply_overlay_definition()


func _input(event: InputEvent) -> void:
	if not _overlay_shown_for_player:
		return

	if event.is_action_pressed(PREVIOUS_PAGE_ACTION):
		_show_previous_page()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(NEXT_PAGE_ACTION):
		_show_next_page()
		get_viewport().set_input_as_handled()


func _on_picked_up() -> void:
	_refresh_overlay_visibility()


func _on_attachment_moved() -> void:
	_refresh_overlay_visibility()


func _on_thrown() -> void:
	_refresh_overlay_visibility()


func _on_definition_applied() -> void:
	_apply_overlay_definition()


func try_secondary_interact() -> bool:
	if not is_carried or is_opening or is_closing:
		return false

	if is_open:
		_is_closing = true
		_sprite.play_backwards(OPEN_ANIMATION)
		_close_audio.play()
	else:
		_is_opening = true
		_set_page(0)
		_sprite.play(OPEN_ANIMATION)
		_open_audio.play()

	return true


func _on_animation_finished() -> void:
	if _sprite.animation != OPEN_ANIMATION:
		return

	if _is_closing:
		_is_closing = false
		_is_open = false
	elif _is_opening:
		_is_opening = false
		_is_open = true

	_refresh_overlay_visibility()


func _refresh_overlay_visibility() -> void:
	var carrier := current_carrier
	var should_show := (
		carrier != null
		and carrier.get_parent() is Player
		and is_open
		and not is_opening
		and not is_closing
	)
	if should_show == _overlay_shown_for_player:
		return

	_overlay_shown_for_player = should_show
	if _overlay_tween != null:
		_overlay_tween.kill()
	_overlay_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT if should_show else Tween.EASE_IN
	)

	if should_show:
		if not _overlay_root.visible:
			_overlay_root.position = HIDDEN_OVERLAY_POSITION
			_overlay_root.visible = true

		_overlay_tween.tween_property(_overlay_root, "position", Vector2.ZERO, OverlayShowDuration)
		return

	_overlay_tween.tween_property(_overlay_root, "position", HIDDEN_OVERLAY_POSITION, OverlayHideDuration)
	_overlay_tween.tween_callback(_finish_hiding_overlay)


func _finish_hiding_overlay() -> void:
	if not _overlay_shown_for_player:
		_overlay_root.visible = false
	_overlay_tween = null


func _show_previous_page() -> void:
	if _page_index == 0:
		return
	_set_page(0)
	_backward_page_audio.play()


func _show_next_page() -> void:
	if _page_index == 1:
		return
	_set_page(1)
	_forward_page_audio.play()


func _set_page(page_index: int) -> void:
	_page_index = clampi(page_index, 0, 1)
	_overlay_image.visible = _page_index == 0
	_second_page_image.visible = _page_index == 1
	_previous_page_button.disabled = _page_index == 0
	_next_page_button.disabled = _page_index == 1


func _apply_overlay_definition() -> void:
	if _overlay_image == null or Definition == null:
		return

	_overlay_image.material = Definition.VisualMaterial
	_overlay_image.modulate = Definition.Modulate
	_second_page_image.material = Definition.VisualMaterial
	_second_page_image.modulate = Definition.Modulate
