@tool
class_name PickupItemDefinition
extends Resource
## Serializable description of a pickup item: its identity, visuals, and the
## transformations that have already been applied to reach this state.

const _IDLE_ANIMATION: StringName = &"idle"

@export var Id: StringName = &""
@export var DisplayName: String = ""
@export var Texture: Texture2D = null
## Declared before `SpriteFrames` below: both properties share the built-in
## `SpriteFrames` type name, and declaring the plain `SpriteFrames` member first
## would shadow that type identifier for any later property in this script that
## still needs to reference it as a type. Export order has no effect on how
## `.tres` resources bind these properties (they are matched by name).
@export var ProcessingSpriteFrames: SpriteFrames = null
@export var SpriteFrames: SpriteFrames = null
@export var Modulate: Color = Color.WHITE
@export var VisualScale: Vector2 = Vector2.ONE
@export var VisualMaterial: Material = null
@export var AppliedTransformationIds: Array[StringName] = []
@export var TransformationOverrides: Array[ItemTransformationOverride] = []

func get_display_texture() -> Texture2D:
	if Texture != null:
		return Texture

	if (
		SpriteFrames == null
		or not SpriteFrames.has_animation(_IDLE_ANIMATION)
		or SpriteFrames.get_frame_count(_IDLE_ANIMATION) == 0
	):
		return null

	return SpriteFrames.get_frame_texture(_IDLE_ANIMATION, 0)

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
