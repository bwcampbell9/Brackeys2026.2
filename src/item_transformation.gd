@tool
class_name ItemTransformation
extends Resource
## Describes how to transform one pickup item definition into another (e.g.
## chopping raw produce, cooking an ingredient).

@export var Id: StringName = &""
@export var ResultIdPrefix: String = ""
@export var ResultNamePrefix: String = ""
@export var FallbackMaterial: Material = null
@export var FallbackOutput: PickupItemDefinition = null

func can_apply(input: PickupItemDefinition) -> bool:
	if Id.is_empty() or input.has_applied_transformation(Id):
		return false

	var transformation_override := input.find_transformation_override(Id)
	return (
		(transformation_override != null and transformation_override.Output != null)
		or FallbackOutput != null
		or FallbackMaterial != null
	)

func resolve(input: PickupItemDefinition) -> PickupItemDefinition:
	if not can_apply(input):
		push_error("%s cannot be applied to %s." % [Id, input.Id])
		return null

	var found_override := input.find_transformation_override(Id)
	var explicit_output: PickupItemDefinition = (
		found_override.Output if found_override != null else null
	)
	var uses_generated_fallback := explicit_output == null and FallbackOutput == null
	var output_template: PickupItemDefinition
	if explicit_output != null:
		output_template = explicit_output
	elif FallbackOutput != null:
		output_template = FallbackOutput
	else:
		if FallbackMaterial == null:
			push_error("%s requires a fallback output or material." % Id)
			return null
		output_template = input

	var id_prefix: String = Id if ResultIdPrefix.strip_edges() == "" else ResultIdPrefix
	var result := PickupItemDefinition.new()
	result.Id = (
		"%s_%s" % [id_prefix, input.Id] if uses_generated_fallback else output_template.Id
	)
	result.DisplayName = (
		"%s%s" % [ResultNamePrefix, input.DisplayName]
		if uses_generated_fallback
		else output_template.DisplayName
	)
	result.Texture = output_template.Texture
	result.SpriteFrames = output_template.SpriteFrames
	result.Modulate = output_template.Modulate
	result.VisualScale = output_template.VisualScale
	result.VisualMaterial = (
		FallbackMaterial if uses_generated_fallback else output_template.VisualMaterial
	)

	_copy_transformation_ids(output_template, result)
	_copy_transformation_ids(input, result)
	_add_transformation_id(result, Id)
	for transformation_override in output_template.TransformationOverrides:
		if transformation_override != null:
			result.TransformationOverrides.append(transformation_override)

	return result

static func _copy_transformation_ids(
	source: PickupItemDefinition, destination: PickupItemDefinition
) -> void:
	for transformation_id in source.AppliedTransformationIds:
		_add_transformation_id(destination, transformation_id)

static func _add_transformation_id(
	definition: PickupItemDefinition, transformation_id: StringName
) -> void:
	if not definition.AppliedTransformationIds.has(transformation_id):
		definition.AppliedTransformationIds.append(transformation_id)
