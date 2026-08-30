class_name OvenCookingController
extends Node

signal cooking_state_changed
signal cooking_completed(output: PickupItemDefinition)

var _sockets: Array[PickupSocket] = []
var _cooking_items: Array[PickupItem] = []
var _sprite: AnimatedSprite2D
var _selected_cooking_recipe: CookingRecipe
var _elapsed: float = 0.0
var _is_applying_recipe := false

@export var SocketPath: NodePath = NodePath("../PickupSocket")

@export var AdditionalSocketPaths: Array[NodePath] = []

@export var SpritePath: NodePath = NodePath("../AnimatedSprite2D")

@export var Recipe: ProcessingRecipe

@export var Recipes: Array[CookingRecipe] = []

@export var SelectedCookingRecipe: CookingRecipe:
	get:
		return _selected_cooking_recipe
	set(value):
		if _selected_cooking_recipe == value:
			return

		_selected_cooking_recipe = value
		if is_node_ready():
			_reconcile_cooking()
			cooking_state_changed.emit()

var is_cooking: bool:
	get:
		return _cooking_items.size() > 0

var has_any_item: bool:
	get:
		for socket in _sockets:
			if socket.item != null:
				return true
		return false

var progress: float:
	get:
		var duration := _get_active_duration()
		if is_cooking and duration > 0.0:
			return clampf(_elapsed / duration, 0.0, 1.0)
		return 0.0


func _ready() -> void:
	var socket := get_node_or_null(SocketPath) as PickupSocket
	if socket == null:
		push_error("OvenCookingController requires a valid pickup socket path.")
		return
	_add_socket(socket)
	for path in AdditionalSocketPaths:
		var extra_socket := get_node_or_null(path) as PickupSocket
		if extra_socket == null:
			push_error("OvenCookingController requires pickup socket '%s'." % path)
			return
		_add_socket(extra_socket)

	_sprite = get_node_or_null(SpritePath) as AnimatedSprite2D
	if _sprite == null:
		push_error("OvenCookingController requires a valid animated sprite path.")
		return
	if Recipes.size() > 0 and _selected_cooking_recipe == null:
		_selected_cooking_recipe = Recipes[0]

	_reset_presentation()
	_begin_cooking()


func _exit_tree() -> void:
	for socket in _sockets:
		if is_instance_valid(socket) and socket.item_changed.is_connected(_on_socket_item_changed):
			socket.item_changed.disconnect(_on_socket_item_changed)


func _process(delta: float) -> void:
	if not is_cooking:
		return

	if not _cooking_items_are_unchanged() or not _can_cook_stored_items():
		_stop_cooking()
		return

	_elapsed += delta
	if _elapsed < _get_active_duration():
		return

	var cooked_baby: PickupItem = _cooking_items[0] if _cooking_items.size() == 1 else null
	if not _apply_active_recipe():
		_stop_cooking()
		return

	_enable_npc_output_source(_cooking_items[0])
	_stop_cooking()
	cooking_state_changed.emit()

	if cooked_baby is BabyPickupItem:
		get_tree().call_group(
			GameOverController.GAME_OVER_GROUP,
			"trigger_game_over_at",
			cooked_baby.global_position
		)


func can_accept(item: PickupItem) -> bool:
	var definition: PickupItemDefinition = item.Definition
	if definition == null:
		return false

	var stored_items := _get_stored_items()
	if (
		stored_items.is_empty()
		and item is BabyPickupItem
		and Recipe != null
		and Recipe.matches(item, null)
	):
		return true

	if _uses_authored_recipes():
		return (
			_selected_cooking_recipe != null
			and _selected_cooking_recipe.can_accept(stored_items, definition)
		)

	return stored_items.is_empty() and Recipe != null and Recipe.matches(item, null)


func find_recipe_by_output(output: PickupItemDefinition) -> CookingRecipe:
	for recipe in Recipes:
		if recipe.Output != null and recipe.Output.Id == output.Id:
			return recipe
	return null


func try_select_recipe(recipe: CookingRecipe) -> bool:
	if has_any_item or not Recipes.has(recipe):
		return false

	SelectedCookingRecipe = recipe
	return true


func get_first_missing_ingredient() -> PickupItemDefinition:
	if _selected_cooking_recipe == null:
		return null
	return _selected_cooking_recipe.get_first_missing_ingredient(_get_stored_items())


func _uses_authored_recipes() -> bool:
	return Recipes.size() > 0


func _add_socket(socket: PickupSocket) -> void:
	_sockets.append(socket)
	socket.item_changed.connect(_on_socket_item_changed)


func _get_stored_items() -> Array[PickupItem]:
	var items: Array[PickupItem] = []
	for socket in _sockets:
		var item := socket.item
		if item != null:
			items.append(item)
	return items


func _on_socket_item_changed() -> void:
	if _is_applying_recipe:
		return

	_reconcile_cooking()
	cooking_state_changed.emit()


func _reconcile_cooking() -> void:
	_stop_cooking()
	_begin_cooking()


func _begin_cooking() -> void:
	if not _can_cook_stored_items():
		return

	_cooking_items.append_array(_get_stored_items())
	_elapsed = 0.0
	_sprite.play(&"cooking")


func _can_cook_stored_items() -> bool:
	var items := _get_stored_items()
	if _uses_legacy_recipe_for(items):
		return (
			items.size() == 1
			and Recipe != null
			and Recipe.Duration > 0.0
			and Recipe.matches(items[0], null)
		)

	if _uses_authored_recipes():
		return (
			_selected_cooking_recipe != null
			and _selected_cooking_recipe.Duration > 0.0
			and _selected_cooking_recipe.matches(items)
		)

	return false


func _cooking_items_are_unchanged() -> bool:
	var stored_items := _get_stored_items()
	if stored_items.size() != _cooking_items.size():
		return false

	for index in stored_items.size():
		if stored_items[index] != _cooking_items[index]:
			return false
	return true


func _get_active_duration() -> float:
	if _uses_legacy_recipe_for(_cooking_items):
		return Recipe.Duration if Recipe != null else 0.0
	return _selected_cooking_recipe.Duration if _selected_cooking_recipe != null else 0.0


func _apply_active_recipe() -> bool:
	if _uses_legacy_recipe_for(_cooking_items):
		return _cooking_items.size() == 1 and Recipe != null and Recipe.apply(_cooking_items[0])

	if _uses_authored_recipes():
		return _apply_authored_recipe()

	return false


func _uses_legacy_recipe_for(items: Array[PickupItem]) -> bool:
	return not _uses_authored_recipes() or (items.size() == 1 and items[0] is BabyPickupItem)


func _apply_authored_recipe() -> bool:
	var recipe := _selected_cooking_recipe
	if recipe == null or recipe.Output == null or not recipe.matches(_cooking_items):
		return false

	_is_applying_recipe = true
	var output: PickupItemDefinition = recipe.Output
	var result_item := _cooking_items[0]
	result_item.set_definition(output)
	for index in range(1, _cooking_items.size()):
		var consumed_item := _cooking_items[index]
		for socket in _sockets:
			if socket.item == consumed_item:
				socket.try_discard(consumed_item)
				break
	cooking_completed.emit(output)
	_is_applying_recipe = false
	return true


func _enable_npc_output_source(output: PickupItem) -> void:
	for socket in _sockets:
		if socket.item == output:
			socket.set_npc_source_enabled(true)
			return


func _stop_cooking() -> void:
	_cooking_items.clear()
	_elapsed = 0.0
	_reset_presentation()


func _reset_presentation() -> void:
	if is_instance_valid(_sprite):
		_sprite.play(&"idle")
