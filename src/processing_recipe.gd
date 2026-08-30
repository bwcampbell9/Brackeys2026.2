@tool
class_name ProcessingRecipe
extends Resource
## Defines a tool-processing transformation (e.g. chopping) applied to a
## single item, optionally requiring a specific tool item to be held.

@export var Transformation: ItemTransformation = null
@export var RequiredTool: PickupItemDefinition = null
@export_range(0.1, 30, 0.1, "or_greater") var Duration: float = 1.5

## Sentinel default for `tool` in `matches()` below, distinguishing "no tool
## argument supplied" (ignore RequiredTool, mirroring the C# single-argument
## `Matches(PickupItem)` overload) from "an explicit null tool" (enforce
## RequiredTool, mirroring the C# `Matches(PickupItem, PickupItem?)` overload
## called with a null tool). GDScript has no method overloading, so a single
## `matches(item, tool = ...)` must serve both call shapes already in use
## across independently-ported consumers.
const _NO_TOOL_ARGUMENT: StringName = &"__processing_recipe_no_tool_argument__"

## `item`/`tool` hold PickupItem-like objects (duck-typed; see the matching
## note in cooking_recipe.gd for why these are not statically typed as
## `PickupItem`).
##
## Call with one argument (`matches(item)`) to mirror the C# single-argument
## `Matches(PickupItem)` overload, checking only whether the transformation
## itself applies and ignoring RequiredTool. Call with two arguments
## (`matches(item, tool)`, `tool` possibly null) to mirror the C#
## `Matches(PickupItem, PickupItem?)` overload, which additionally enforces
## that the held tool (or lack of one) satisfies RequiredTool.
func matches(item, tool = _NO_TOOL_ARGUMENT) -> bool:
	if Transformation == null:
		return false

	var definition = item.Definition
	if not (definition is PickupItemDefinition) or not Transformation.can_apply(definition):
		return false

	if tool is StringName and tool == _NO_TOOL_ARGUMENT:
		return true

	if RequiredTool == null:
		return tool == null

	return tool != null and tool.Definition == RequiredTool

func apply(item) -> bool:
	if Transformation == null:
		return false

	var definition = item.Definition
	if not (definition is PickupItemDefinition) or not Transformation.can_apply(definition):
		return false

	item.set_definition(Transformation.resolve(definition))
	return true
