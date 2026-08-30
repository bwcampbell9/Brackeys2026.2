class_name PickupItem
extends RigidBody2D

## Duck-typed IItemSource: exposes source_node, available_definition,
## is_source_available, can_return_item, approach_position, try_acquire,
## and try_return. Subclasses (BabyPickupItem, RecipeBookItem) override the
## protected-style `_on_*` hooks below instead of C#'s `protected virtual`
## members.

signal availability_changed

const IDLE_ANIMATION := &"idle"
const ITEM_SOURCE_GROUP := &"npc_item_sources"

var _world_parent: Node
var _world_collision_layer: int = 0
var _world_collision_mask: int = 0
var _is_attached: bool = false
var _motion_tween: Tween
var _definition: PickupItemDefinition
var _rest_scale: Vector2 = Vector2.ONE

@export var Definition: PickupItemDefinition:
	get:
		return _definition
	set(value):
		_definition = value
		_apply_definition()

var is_available: bool:
	get:
		return not _is_attached

var is_carried: bool:
	get:
		if not _is_attached:
			return false
		var parent := get_parent()
		return parent != null and parent.get_parent() is PickupCarrier

var is_transfer_available: bool:
	get:
		return is_available or is_carried

var source_node: Node2D:
	get:
		return self

var available_definition: PickupItemDefinition:
	get:
		return Definition

var is_source_available: bool:
	get:
		return is_transfer_available and Definition != null

var current_carrier: PickupCarrier:
	get:
		if not is_carried:
			return null
		return get_parent().get_parent() as PickupCarrier

var can_return_item: bool:
	get:
		return false

var approach_position: Vector2:
	get:
		return global_position


func _on_picked_up() -> void:
	pass


func _on_attachment_moved() -> void:
	pass


func _on_thrown() -> void:
	pass


func try_secondary_interact() -> bool:
	return false


func _ready() -> void:
	_rest_scale = scale
	_apply_definition()
	add_to_group(ITEM_SOURCE_GROUP)


func try_pick_up(hold_point: Node2D, duration: float) -> bool:
	if duration < 0.0:
		push_error("Pickup duration cannot be negative.")
		return false

	if _is_attached:
		return false

	_is_attached = true
	_world_parent = get_parent()
	_world_collision_layer = collision_layer
	_world_collision_mask = collision_mask

	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	collision_layer = 0
	collision_mask = 0
	reparent(hold_point, true)
	_on_picked_up()
	_tween_to_attachment(duration)
	availability_changed.emit()
	return true


func try_move_attachment(attachment_point: Node2D, duration: float) -> bool:
	if not _is_attached:
		return false

	reparent(attachment_point, true)
	_on_attachment_moved()
	_tween_to_attachment(duration)
	return true


func set_definition(definition: PickupItemDefinition) -> void:
	Definition = definition


func get_visual_material() -> Material:
	var visual := _get_active_visual()
	return visual.material if visual != null else null


func set_visual_material(material: Material) -> void:
	var visual := _get_active_visual()
	if visual == null:
		push_error("Pickup item requires an active visual to set its material.")
		return
	visual.material = material


func play_processing_animation(frames: SpriteFrames) -> void:
	var static_sprite := get_node_or_null("Sprite2D") as Sprite2D
	var animated_sprite := _ensure_animated_sprite()
	if static_sprite != null:
		static_sprite.visible = false

	animated_sprite.sprite_frames = frames
	animated_sprite.visible = true
	animated_sprite.material = _definition.VisualMaterial if _definition != null else null
	animated_sprite.modulate = _definition.Modulate if _definition != null else Color.WHITE
	animated_sprite.scale = _definition.VisualScale if _definition != null else Vector2.ONE
	animated_sprite.play(IDLE_ANIMATION)


func restore_definition_visual() -> void:
	_apply_definition()


func _tween_to_attachment(duration: float) -> void:
	var tween := (
		start_motion_tween()
		.set_parallel()
		.set_trans(Tween.TRANS_QUAD)
		.set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(self, "position", Vector2.ZERO, duration)
	tween.tween_property(self, "rotation", 0.0, duration)
	tween.tween_property(self, "scale", _rest_scale, duration)


func start_motion_tween() -> Tween:
	if _motion_tween != null:
		_motion_tween.kill()
	_motion_tween = create_tween()
	return _motion_tween


func reset_attachment_presentation() -> void:
	if _motion_tween != null:
		_motion_tween.kill()
	_motion_tween = null
	position = Vector2.ZERO
	rotation = 0.0
	scale = _rest_scale


func play_shake() -> void:
	var tween := (
		start_motion_tween()
		.set_parallel()
		.set_trans(Tween.TRANS_SINE)
		.set_ease(Tween.EASE_IN_OUT)
	)
	tween.tween_property(self, "position", Vector2.ZERO, 0.2)
	tween.tween_property(self, "scale", _rest_scale, 0.2)
	tween.tween_method(_apply_shake_progress, 0.0, 1.0, 0.2)
	tween.chain().tween_callback(_finish_shake)


func animate_return_to(target: Node2D, duration: float, spin_turns: float) -> void:
	if duration < 0.0:
		push_error("Return duration cannot be negative.")
		return

	reparent(target, true)
	var tween := (
		start_motion_tween()
		.set_parallel()
		.set_trans(Tween.TRANS_CUBIC)
		.set_ease(Tween.EASE_IN)
	)
	tween.tween_property(self, "position", Vector2.ZERO, duration)
	tween.tween_property(self, "rotation", rotation + TAU * spin_turns, duration)
	tween.tween_property(self, "scale", Vector2.ZERO, duration)
	tween.chain().tween_callback(queue_free)


func throw(impulse: Vector2) -> void:
	if not _is_attached:
		return

	var world_parent: Node = (
		_world_parent if is_instance_valid(_world_parent) else get_tree().current_scene
	)
	if world_parent == null:
		push_error("A pickup item requires a world parent when thrown.")
		return

	if _motion_tween != null:
		_motion_tween.kill()
	_motion_tween = null
	reparent(world_parent, true)
	scale = _rest_scale
	collision_layer = _world_collision_layer
	collision_mask = _world_collision_mask
	freeze = false
	sleeping = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_is_attached = false
	_on_thrown()
	availability_changed.emit()
	apply_central_impulse(impulse)


func try_acquire(context: InteractionContext) -> bool:
	var source: PickupCarrier = current_carrier
	if source != null:
		return source.try_transfer_held_item_to(self, context.carrier)
	return context.carrier.try_hold(self)


func try_return(_context: InteractionContext) -> bool:
	return false


func _apply_definition() -> void:
	if _definition == null:
		_on_definition_applied()
		return

	var static_sprite := get_node_or_null("Sprite2D") as Sprite2D
	var animated_sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _definition.SpriteFrames != null and animated_sprite == null:
		animated_sprite = _ensure_animated_sprite()

	var uses_definition_animation := _definition.SpriteFrames != null and animated_sprite != null
	var uses_scene_animation := (
		static_sprite == null
		and animated_sprite != null
		and animated_sprite.sprite_frames != null
	)
	var uses_animation := uses_definition_animation or uses_scene_animation
	if static_sprite != null:
		static_sprite.visible = not uses_animation

	if animated_sprite != null:
		animated_sprite.visible = uses_animation
		if uses_definition_animation:
			animated_sprite.sprite_frames = _definition.SpriteFrames
			animated_sprite.play(IDLE_ANIMATION)
		elif not uses_scene_animation:
			animated_sprite.stop()

	var visual: CanvasItem = animated_sprite if uses_animation else static_sprite
	if visual != null:
		visual.material = _definition.VisualMaterial
		visual.modulate = _definition.Modulate
		if visual is Node2D:
			(visual as Node2D).scale = _definition.VisualScale

		if visual is Sprite2D and _definition.Texture != null:
			(visual as Sprite2D).texture = _definition.Texture

	_on_definition_applied()


func _ensure_animated_sprite() -> AnimatedSprite2D:
	var animated_sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		return animated_sprite

	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	add_child(animated_sprite)
	return animated_sprite


func _get_active_visual() -> CanvasItem:
	var animated_sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null and animated_sprite.visible:
		return animated_sprite
	return get_node_or_null("Sprite2D") as Sprite2D


func _on_definition_applied() -> void:
	pass


func _apply_shake_progress(progress: float) -> void:
	rotation = sin(progress * TAU * 2.0) * 0.12 * (1.0 - progress)


func _finish_shake() -> void:
	rotation = 0.0
