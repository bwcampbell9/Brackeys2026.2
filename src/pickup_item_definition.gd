@tool
class_name PickupItemDefinition
extends Resource
## Serializable description of a pickup item: its identity, visuals, and the
## transformations that have already been applied to reach this state.

const _IDLE_ANIMATION: StringName = &"idle"
const _TEXTURE_PROPERTY: StringName = &"Texture"
const _SPRITE_FRAMES_PROPERTY: StringName = &"SpriteFrames"

@export var Id: StringName = &""
@export var DisplayName: String = ""
@export var ProcessingSpriteFrames: SpriteFrames = null
@export var Modulate: Color = Color.WHITE
@export var VisualScale: Vector2 = Vector2.ONE
@export var VisualMaterial: Material = null
@export var AppliedTransformationIds: Array[StringName] = []
@export var TransformationOverrides: Array[ItemTransformationOverride] = []

var _texture: Texture2D
var _sprite_frames: SpriteFrames


func _get_property_list() -> Array[Dictionary]:
	return [
		{
			"name": _TEXTURE_PROPERTY,
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "Texture2D",
			"usage": PROPERTY_USAGE_DEFAULT,
		},
		{
			"name": _SPRITE_FRAMES_PROPERTY,
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "SpriteFrames",
			"usage": PROPERTY_USAGE_DEFAULT,
		},
	]


func _get(property: StringName) -> Variant:
	match property:
		_TEXTURE_PROPERTY:
			return _texture
		_SPRITE_FRAMES_PROPERTY:
			return _sprite_frames
	return null


func _set(property: StringName, value: Variant) -> bool:
	match property:
		_TEXTURE_PROPERTY:
			_texture = value as Texture2D
			return true
		_SPRITE_FRAMES_PROPERTY:
			_sprite_frames = value as SpriteFrames
			return true
	return false


func get_texture() -> Texture2D:
	return _texture


func set_texture(value: Texture2D) -> void:
	_texture = value


func get_sprite_frames() -> SpriteFrames:
	return _sprite_frames


func set_sprite_frames(value: SpriteFrames) -> void:
	_sprite_frames = value


func get_display_texture() -> Texture2D:
	if _texture != null:
		return _texture

	if (
		_sprite_frames == null
		or not _sprite_frames.has_animation(_IDLE_ANIMATION)
		or _sprite_frames.get_frame_count(_IDLE_ANIMATION) == 0
	):
		return null

	return _sprite_frames.get_frame_texture(_IDLE_ANIMATION, 0)

func has_applied_transformation(transformation_id: StringName) -> bool:
	return AppliedTransformationIds.has(transformation_id)

func find_transformation_override(
	transformation_id: StringName
) -> ItemTransformationOverride:
	for transformation_override in TransformationOverrides:
		if (
			transformation_override != null
			and transformation_override.TransformationId == transformation_id
		):
			return transformation_override

	return null
