@tool
class_name CookingRecipe
extends Resource
## Defines which set of ingredient items combine into an output item over time
## (e.g. combining chopped vegetables into a soup in the oven).

@export var Output: PickupItemDefinition = null
@export var Ingredients: Array[PickupItemDefinition] = []
@export_range(0.1, 30, 0.1, "or_greater") var Duration: float = 10.0

## `items` holds PickupItem-like objects (each exposing a "Definition"
## property). Left untyped/duck-typed rather than statically hinted as
## `Array[PickupItem]` because pickup_item.gd is ported by a different agent and
## may not exist yet when this script is parsed; a missing global class in a
## type hint would be a parse error. Runtime behavior is unaffected since
## Godot resolves `.Definition` dynamically regardless of static typing.
func matches(items: Array) -> bool:
	if Output == null or Ingredients.is_empty() or items.size() != Ingredients.size():
		return false

	for ingredient in Ingredients:
		var required_count := _count_required(ingredient.Id)
		var stored_count := _count_stored(items, ingredient.Id)
		if stored_count != required_count:
			return false

	return true

func can_accept(stored_items: Array, candidate: PickupItemDefinition) -> bool:
	return (
		_is_valid_partial(stored_items)
		and stored_items.size() < Ingredients.size()
		and _count_stored(stored_items, candidate.Id) < _count_required(candidate.Id)
	)

func get_first_missing_ingredient(stored_items: Array) -> PickupItemDefinition:
	if not _is_valid_partial(stored_items):
		return null

	for ingredient in Ingredients:
		if _count_stored(stored_items, ingredient.Id) < _count_required(ingredient.Id):
			return ingredient

	return null

func _is_valid_partial(items: Array) -> bool:
	if items.size() > Ingredients.size():
		return false

	for item in items:
		var definition = item.Definition
		if (
			not (definition is PickupItemDefinition)
			or _count_required(definition.Id) == 0
			or _count_stored(items, definition.Id) > _count_required(definition.Id)
		):
			return false

	return true

func _count_required(id: StringName) -> int:
	var count := 0
	for ingredient in Ingredients:
		if ingredient.Id == id:
			count += 1
	return count

static func _count_stored(items: Array, id: StringName) -> int:
	var count := 0
	for item in items:
		if item.Definition != null and item.Definition.Id == id:
			count += 1
	return count
