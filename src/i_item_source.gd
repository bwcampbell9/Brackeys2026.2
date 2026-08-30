## GDScript has no interfaces, so pickup item sources (item stands,
## containers, pickup sockets, etc.) implement this contract via consistent
## duck typing instead. [method conforms] validates a candidate node and
## fails loudly (an explicit [method @GlobalScope.push_error], not a
## silently-accepted node) when a required member is missing, since a
## malformed member of the "npc_item_sources" group is a real bug rather
## than an "unavailable" source.
##
## Conforming nodes expose:
##   [code]source_node: Node2D[/code]
##   [code]available_definition: PickupItemDefinition[/code] (nullable)
##   [code]is_source_available: bool[/code]
##   [code]can_return_item: bool[/code]
##   [code]approach_position: Vector2[/code]
##   [code]try_acquire(context: InteractionContext) -> bool[/code]
##   [code]try_return(context: InteractionContext) -> bool[/code]
class_name IItemSource
extends RefCounted

const REQUIRED_PROPERTIES: Array[StringName] = [
	&"source_node",
	&"available_definition",
	&"is_source_available",
	&"can_return_item",
	&"approach_position",
]

const REQUIRED_METHODS: Array[StringName] = [
	&"try_acquire",
	&"try_return",
]


## Returns true when [param node] implements every property and method
## required by the item source contract.
static func conforms(node: Object) -> bool:
	if node == null:
		return false

	for property_name in REQUIRED_PROPERTIES:
		if not (property_name in node):
			push_error(
				"Node '%s' is registered as an item source but is missing property '%s'." % [
					node.get_path() if node is Node else str(node),
					property_name,
				]
			)
			return false

	for method_name in REQUIRED_METHODS:
		if not node.has_method(method_name):
			push_error(
				"Node '%s' is registered as an item source but does not implement '%s'." % [
					node.get_path() if node is Node else str(node),
					method_name,
				]
			)
			return false

	return true
