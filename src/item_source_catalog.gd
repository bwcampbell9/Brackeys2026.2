## Discovers, reserves, and releases nodes in the "npc_item_sources" group
## that duck-type the [IItemSource] contract, scoped beneath a configured
## root so multiple independent kitchens do not see each other's sources.
class_name ItemSourceCatalog
extends Node

const ItemSourceGroup: StringName = &"npc_item_sources"

var _reservations: Dictionary = {} # int (source instance id) -> Node (requester)
var _scope_root: Node = null


func configure(scope_root: Node) -> void:
	if scope_root == null:
		push_error("ItemSourceCatalog.configure() requires a non-null scope_root.")
		return

	_scope_root = scope_root
	_reservations.clear()


func get_available_definitions_excluding(excluded: PickupItemDefinition, requester: Node) -> Array[PickupItemDefinition]:
	var definitions: Array[PickupItemDefinition] = []
	var seen_ids: Dictionary = {}
	for source in _get_available_sources(requester):
		var definition: PickupItemDefinition = source.available_definition
		if definition == null or _has_same_id(definition, excluded) or seen_ids.has(definition.Id):
			continue

		seen_ids[definition.Id] = true
		definitions.append(definition)

	definitions.sort_custom(func(left: PickupItemDefinition, right: PickupItemDefinition) -> bool:
		return str(left.Id) < str(right.Id)
	)
	return definitions


func has_available_source(definition: PickupItemDefinition, requester: Node) -> bool:
	if definition == null:
		push_error("ItemSourceCatalog.has_available_source() requires a non-null definition.")
		return false
	if requester == null:
		push_error("ItemSourceCatalog.has_available_source() requires a non-null requester.")
		return false

	for source in _get_available_sources(requester):
		var available: PickupItemDefinition = source.available_definition
		if available != null and _has_same_id(available, definition):
			return true

	return false


func find_return_source(definition: PickupItemDefinition) -> Object:
	if definition == null:
		push_error("ItemSourceCatalog.find_return_source() requires a non-null definition.")
		return null

	var result: Object = null
	for node in get_tree().get_nodes_in_group(ItemSourceGroup):
		if not _is_within_scope(node) or not IItemSource.conforms(node):
			continue
		if not node.can_return_item:
			continue

		var available: PickupItemDefinition = node.available_definition
		if available == null or not _has_same_id(available, definition):
			continue

		if result == null or node.source_node.get_instance_id() < result.source_node.get_instance_id():
			result = node

	return result


## GDScript has no "out" parameters, so the original bool-plus-out-source
## handshake collapses to a single return value: the reserved source, or
## [code]null[/code] when no candidate is available.
func try_reserve_source(definition: PickupItemDefinition, requester: Node, random: RandomNumberGenerator) -> Object:
	if definition == null:
		push_error("ItemSourceCatalog.try_reserve_source() requires a non-null definition.")
		return null
	if requester == null:
		push_error("ItemSourceCatalog.try_reserve_source() requires a non-null requester.")
		return null
	if random == null:
		push_error("ItemSourceCatalog.try_reserve_source() requires a non-null random.")
		return null

	var candidates: Array = []
	for candidate in _get_available_sources(requester):
		var available: PickupItemDefinition = candidate.available_definition
		if available != null and _has_same_id(available, definition):
			candidates.append(candidate)

	if candidates.is_empty():
		return null

	var source: Object = candidates[random.randi_range(0, candidates.size() - 1)]
	_reservations[source.source_node.get_instance_id()] = requester
	return source


func release(source: Object, requester: Node) -> void:
	if source == null:
		return

	var source_id: int = source.source_node.get_instance_id()
	if _reservations.has(source_id) and _reservations[source_id] == requester:
		_reservations.erase(source_id)


func _get_available_sources(requester: Node) -> Array:
	_prune_reservations()
	var sources: Array = []
	for node in get_tree().get_nodes_in_group(ItemSourceGroup):
		if not _is_within_scope(node) or not IItemSource.conforms(node):
			continue
		if not node.is_source_available:
			continue

		var owner_id: int = node.source_node.get_instance_id()
		if _reservations.has(owner_id) and _reservations[owner_id] != requester:
			continue

		sources.append(node)

	sources.sort_custom(func(left, right) -> bool:
		return left.source_node.get_instance_id() < right.source_node.get_instance_id()
	)
	return sources


func _is_within_scope(node: Node) -> bool:
	return _scope_root != null and (node == _scope_root or _scope_root.is_ancestor_of(node))


func _has_same_id(left: PickupItemDefinition, right: PickupItemDefinition) -> bool:
	return not left.Id.is_empty() and left.Id == right.Id


func _prune_reservations() -> void:
	var stale_ids: Array = []
	for reserved_id in _reservations:
		if not is_instance_valid(_reservations[reserved_id]):
			stale_ids.append(reserved_id)

	for stale_id in stale_ids:
		_reservations.erase(stale_id)
