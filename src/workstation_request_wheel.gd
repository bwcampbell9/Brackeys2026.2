class_name WorkstationRequestWheel
extends Control

class WheelEntry:
	var ingredients: Array[PickupItemDefinition] = []
	var recipe: CookingRecipe = null

	func _init(entry_ingredients: Array[PickupItemDefinition], entry_recipe: CookingRecipe = null) -> void:
		ingredients = entry_ingredients
		recipe = entry_recipe


const WHEEL_LEFT_ACTION := &"move_left"
const WHEEL_RIGHT_ACTION := &"move_right"
const WHEEL_UP_ACTION := &"move_up"
const WHEEL_DOWN_ACTION := &"move_down"
const PREVIOUS_PAGE_ACTION := &"recipe_wheel_previous_page"
const NEXT_PAGE_ACTION := &"recipe_wheel_next_page"
const BLUE_TINT := Color(0.4, 0.7, 1.0, 1.0)
const ITEMS_PER_PAGE := 12
const DESIRED_ITEM_RADIUS := 22.0
const MINIMUM_ITEM_RADIUS := 8.0
const MINIMUM_ORBIT_RADIUS := 58.0
const ITEM_GAP := 8.0
const WHEEL_PADDING := 16.0
const MOUSE_DEADZONE_SQUARED := 64.0

var _entries: Array[WheelEntry] = []
var _selected_index := 0
var _requested_center: Vector2 = Vector2.ZERO
var _draw_center: Vector2 = Vector2.ZERO
var _viewport_size: Vector2 = Vector2.ZERO
var _orbit_radius := 0.0
var _item_radius := 0.0
var _background_radius := 0.0
var _page_index := 0
var _controller_selection_active := false

var selected_item: PickupItemDefinition:
	get:
		if _entries.is_empty():
			return null
		return _entries[_selected_index].ingredients[0]

var selected_recipe: CookingRecipe:
	get:
		if _entries.is_empty():
			return null
		return _entries[_selected_index].recipe

var page_count: int:
	get:
		return ceili(float(_entries.size()) / ITEMS_PER_PAGE)

var current_page_index: int:
	get:
		return _page_index

var entry_count: int:
	get:
		return _entries.size()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	hide()


func open(items: Array[PickupItemDefinition], current_item: PickupItemDefinition, center: Vector2) -> void:
	_entries.clear()
	for item in items:
		if item != null:
			_entries.append(WheelEntry.new([item]))

	_selected_index = _find_selected_index(current_item)
	_page_index = _selected_index / ITEMS_PER_PAGE
	_controller_selection_active = false
	set_center(center)
	set_process(true)
	show()
	queue_redraw()


func open_recipes(recipes: Array[CookingRecipe], current_recipe: CookingRecipe, center: Vector2) -> void:
	_entries.clear()
	for recipe in recipes:
		if recipe == null or recipe.Ingredients.is_empty():
			continue

		var ingredients: Array[PickupItemDefinition] = []
		for ingredient in recipe.Ingredients:
			if ingredient != null:
				ingredients.append(ingredient)
		if not ingredients.is_empty():
			_entries.append(WheelEntry.new(ingredients, recipe))

	_selected_index = _find_selected_recipe_index(current_recipe)
	_page_index = _selected_index / ITEMS_PER_PAGE
	_controller_selection_active = false
	set_center(center)
	set_process(true)
	show()
	queue_redraw()


func get_selected_ingredient_count() -> int:
	if _entries.is_empty():
		return 0
	return _entries[_selected_index].ingredients.size()


func get_selected_ingredient(index: int) -> PickupItemDefinition:
	if _entries.is_empty() or index < 0 or index >= _entries[_selected_index].ingredients.size():
		return null
	return _entries[_selected_index].ingredients[index]


func close() -> void:
	set_process(false)
	hide()


func set_center(center: Vector2) -> void:
	_requested_center = center
	_update_layout()
	position = Vector2.ZERO
	queue_redraw()


func _process(_delta: float) -> void:
	if get_viewport_rect().size != _viewport_size:
		_update_layout()
		queue_redraw()

	if Input.is_action_just_pressed(PREVIOUS_PAGE_ACTION):
		_change_page(-1)
	elif Input.is_action_just_pressed(NEXT_PAGE_ACTION):
		_change_page(1)

	var controller_direction := Input.get_vector(
		WHEEL_LEFT_ACTION,
		WHEEL_RIGHT_ACTION,
		WHEEL_UP_ACTION,
		WHEEL_DOWN_ACTION
	)
	if not controller_direction.is_zero_approx():
		_controller_selection_active = true
		_update_selection(controller_direction, 0.0)
	elif not _controller_selection_active:
		_update_selection(get_global_mouse_position() - _draw_center, MOUSE_DEADZONE_SQUARED)


func _input(input_event: InputEvent) -> void:
	if visible and input_event is InputEventMouseMotion:
		_controller_selection_active = false


func _update_selection(direction: Vector2, deadzone_squared: float) -> void:
	var displayed_item_count := _get_displayed_item_count()
	if displayed_item_count < 2 or direction.length_squared() <= deadzone_squared:
		return

	var angle := atan2(direction.y, direction.x) + PI * 0.5
	if angle < 0.0:
		angle += TAU

	var index := posmod(
		floori(angle / TAU * displayed_item_count + 0.5),
		displayed_item_count
	)
	index += _page_index * ITEMS_PER_PAGE
	if _selected_index == index:
		return

	_selected_index = index
	queue_redraw()


func _change_page(offset: int) -> void:
	if page_count < 2:
		return

	var local_index := _selected_index % ITEMS_PER_PAGE
	_page_index = posmod(_page_index + offset, page_count)
	_selected_index = mini(_page_index * ITEMS_PER_PAGE + local_index, _entries.size() - 1)
	_update_layout()
	queue_redraw()


func _get_displayed_item_count() -> int:
	return mini(ITEMS_PER_PAGE, _entries.size() - _page_index * ITEMS_PER_PAGE)


func _update_layout() -> void:
	_viewport_size = get_viewport_rect().size
	size = _viewport_size
	var displayed_item_count := _get_displayed_item_count()
	if displayed_item_count == 0:
		return

	var shortest_viewport_side := minf(_viewport_size.x, _viewport_size.y)
	var max_outer_radius := maxf(MINIMUM_ITEM_RADIUS + WHEEL_PADDING, shortest_viewport_side * 0.45)
	var desired_orbit_radius := 0.0
	if displayed_item_count != 1:
		desired_orbit_radius = maxf(
			MINIMUM_ORBIT_RADIUS,
			displayed_item_count * (DESIRED_ITEM_RADIUS * 2.0 + ITEM_GAP) / TAU
		)
	var max_orbit_radius := maxf(0.0, max_outer_radius - DESIRED_ITEM_RADIUS - WHEEL_PADDING)
	_orbit_radius = minf(desired_orbit_radius, max_orbit_radius)

	var available_item_diameter := DESIRED_ITEM_RADIUS * 2.0
	if displayed_item_count != 1:
		available_item_diameter = TAU * _orbit_radius / displayed_item_count - ITEM_GAP
	_item_radius = clampf(available_item_diameter * 0.5, MINIMUM_ITEM_RADIUS, DESIRED_ITEM_RADIUS)
	_background_radius = _orbit_radius + _item_radius + WHEEL_PADDING
	_draw_center = _clamp_center_to_viewport(_requested_center, _background_radius)


func _clamp_center_to_viewport(center: Vector2, radius: float) -> Vector2:
	if radius * 2.0 >= _viewport_size.x or radius * 2.0 >= _viewport_size.y:
		return _viewport_size * 0.5

	return Vector2(
		clampf(center.x, radius, _viewport_size.x - radius),
		clampf(center.y, radius, _viewport_size.y - radius)
	)


func _find_selected_index(current_item: PickupItemDefinition) -> int:
	if current_item != null:
		for index in _entries.size():
			if _entries[index].ingredients[0].Id == current_item.Id:
				return index
	return 0


func _find_selected_recipe_index(current_recipe: CookingRecipe) -> int:
	if current_recipe != null and current_recipe.Output != null:
		for index in _entries.size():
			var entry_recipe := _entries[index].recipe
			if (
				entry_recipe != null
				and entry_recipe.Output != null
				and entry_recipe.Output.Id == current_recipe.Output.Id
			):
				return index
	return 0


func _draw() -> void:
	if _entries.is_empty():
		return

	draw_circle(_draw_center, _background_radius, Color(0.04, 0.08, 0.14, 0.94))
	draw_arc(_draw_center, _background_radius, 0.0, TAU, 64, BLUE_TINT, 3.0)
	if page_count > 1:
		var page_step := TAU / page_count
		draw_arc(
			_draw_center,
			_background_radius - 6.0,
			-PI * 0.5 + _page_index * page_step,
			-PI * 0.5 + (_page_index + 1) * page_step,
			32,
			Color.WHITE,
			4.0
		)

	var displayed_item_count := _get_displayed_item_count()
	var first_item_index := _page_index * ITEMS_PER_PAGE
	var step := TAU / displayed_item_count
	for local_index in displayed_item_count:
		var item_index := first_item_index + local_index
		var angle := -PI * 0.5 + local_index * step
		var item_center := _draw_center + Vector2.from_angle(angle) * _orbit_radius
		var selected := item_index == _selected_index
		var radius := _item_radius
		if selected:
			radius = minf(_item_radius + 5.0, _item_radius * 1.2)
		draw_circle(
			item_center,
			radius,
			Color(0.12, 0.3, 0.52, 1.0) if selected else Color(0.1, 0.14, 0.2, 1.0)
		)
		draw_arc(item_center, radius, 0.0, TAU, 32, BLUE_TINT if selected else Color.WHITE, 2.0)
		_draw_ingredient_group(_entries[item_index].ingredients, item_center)


func _draw_ingredient_group(ingredients: Array[PickupItemDefinition], center: Vector2) -> void:
	var spacing := _item_radius * 0.85
	var start_x := -spacing * (ingredients.size() - 1) * 0.5
	var max_icon_size := _item_radius * 1.5 if ingredients.size() == 1 else _item_radius * 0.9
	for index in ingredients.size():
		var ingredient := ingredients[index]
		var texture := ingredient.get_texture()
		if texture == null:
			continue

		var icon_size: Vector2 = texture.get_size() * ingredient.VisualScale * 0.55
		var max_dimension := maxf(icon_size.x, icon_size.y)
		if max_dimension > max_icon_size:
			icon_size *= max_icon_size / max_dimension

		var icon_center := center + Vector2.RIGHT * (start_x + index * spacing)
		draw_texture_rect(
			texture,
			Rect2(icon_center - icon_size * 0.5, icon_size),
			false,
			ingredient.Modulate
		)
