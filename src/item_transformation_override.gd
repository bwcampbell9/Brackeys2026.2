@tool
class_name ItemTransformationOverride
extends Resource
## Overrides the output produced when a specific transformation id is applied
## to the pickup item definition that owns this override.

@export var TransformationId: StringName = &""
@export var Output: PickupItemDefinition = null
