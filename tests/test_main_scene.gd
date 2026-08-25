@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

# The Godot AI scene-test runner currently discovers GDScript suites only.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PICKUP_ITEM_SCENE := preload("res://scenes/pickup_item.tscn")
const BABY_PICKUP_ITEM_SCENE := preload("res://scenes/baby_pickup_item.tscn")
const EXPECTED_INPUTS := {
	"move_left": {"keycodes": [KEY_A, KEY_LEFT], "axis": 0, "axis_value": -1.0},
	"move_right": {"keycodes": [KEY_D, KEY_RIGHT], "axis": 0, "axis_value": 1.0},
	"move_up": {"keycodes": [KEY_W, KEY_UP], "axis": 1, "axis_value": -1.0},
	"move_down": {"keycodes": [KEY_S, KEY_DOWN], "axis": 1, "axis_value": 1.0},
}


func suite_name() -> String:
	return "main_scene"


func test_main_scene_has_a_bounded_csharp_player() -> void:
	var level := track(MAIN_SCENE.instantiate())
	var player := level.get_node_or_null("Player") as CharacterBody2D
	var room_tiles := level.get_node_or_null("RoomTiles") as TileMapLayer

	assert_true(player != null, "The level must contain a CharacterBody2D player.")
	assert_true(room_tiles != null, "The level must contain a TileMapLayer room.")
	if player == null or room_tiles == null:
		return

	assert_eq(player.get_script().resource_path, "res://src/Player.cs")
	assert_true(float(player.get("Speed")) > 0.0, "Player speed must be positive.")
	assert_eq(player.collision_layer, 4)
	assert_eq(player.collision_mask, 1)

	var player_shape := player.get_node("CollisionShape2D") as CollisionShape2D
	assert_true(player_shape != null, "Player must have a collision shape.")
	if player_shape != null:
		assert_false(player_shape.disabled)
		assert_true(
			player_shape.shape is CircleShape2D,
			"Player collision must use a CircleShape2D.",
		)

	assert_eq(room_tiles.position, Vector2(0, 14))
	assert_true(room_tiles.tile_set != null, "The room must use a saved TileSet resource.")
	assert_eq(room_tiles.tile_set.tile_size, Vector2i(64, 64))
	assert_eq(room_tiles.tile_set.get_physics_layers_count(), 1)
	assert_eq(room_tiles.get_used_cells().size(), 120)
	var wall_data = room_tiles.tile_set.get_source(0).get_tile_data(Vector2i(1, 0), 0)
	assert_eq(wall_data.get_collision_polygons_count(0), 1)

	var project_config := ConfigFile.new()
	assert_eq(project_config.load("res://project.godot"), OK)
	for action in EXPECTED_INPUTS:
		assert_true(
			project_config.has_section_key("input", action),
			"%s must exist." % action,
		)
		var setting: Variant = project_config.get_value("input", action, {})
		assert_true(setting is Dictionary, "%s must have valid input settings." % action)
		if not setting is Dictionary:
			continue
		var events: Array = setting.get("events", [])
		assert_true(
			events.size() >= 3,
			"%s must include keyboard and controller bindings." % action,
		)
		var expected: Dictionary = EXPECTED_INPUTS[action]
		for keycode in expected.keycodes:
			assert_true(
				_has_key_binding(events, keycode),
				"%s is missing keycode %s." % [action, keycode],
			)
		assert_true(
			_has_stick_binding(events, expected.axis, expected.axis_value),
			"%s must use the expected left-stick direction on any controller." % action,
		)

	var interaction_setting: Dictionary = project_config.get_value("input", "interact", {})
	var interaction_events: Array = interaction_setting.get("events", [])
	assert_true(_has_key_binding(interaction_events, KEY_E))
	assert_true(_has_button_binding(interaction_events, JOY_BUTTON_A))


func test_player_has_reusable_pickup_carrier() -> void:
	var level := track(MAIN_SCENE.instantiate())
	var player := level.get_node("Player") as CharacterBody2D
	var carrier := player.get_node_or_null("PickupCarrier") as Node2D

	assert_true(carrier != null, "The player must contain a pickup carrier.")
	if carrier == null:
		return

	assert_eq(carrier.get_script().resource_path, "res://src/PickupCarrier.cs")
	assert_eq(float(carrier.get("PickupConeDegrees")), 140.0)
	assert_true(is_equal_approx(float(carrier.get("PickupDuration")), 0.2))
	assert_true(float(carrier.get("ThrowForce")) > 0.0)
	assert_true(carrier.get_node_or_null("HoldPoint") is Node2D)

	var pickup_area := carrier.get_node_or_null("PickupArea") as Area2D
	assert_true(pickup_area != null)
	if pickup_area != null:
		assert_eq(pickup_area.collision_mask, 2)
		var pickup_shape: Shape2D = pickup_area.get_node("CollisionShape2D").shape
		assert_true(
			pickup_shape is CircleShape2D,
			"The pickup range must use a circular broad-phase area.",
		)
		if pickup_shape is CircleShape2D:
			assert_eq(pickup_shape.radius, 97.0)

	var close_pickup_area := carrier.get_node_or_null("ClosePickupArea") as Area2D
	assert_true(close_pickup_area != null)
	if close_pickup_area != null:
		assert_eq(close_pickup_area.collision_mask, 2)
		assert_eq(
			close_pickup_area.get_node("CollisionShape2D").shape,
			player.get_node("CollisionShape2D").shape,
			"The omnidirectional pickup area must match the player collision footprint.",
		)


func test_pickup_item_has_top_down_physics_contract() -> void:
	var item := track(PICKUP_ITEM_SCENE.instantiate()) as RigidBody2D

	assert_true(item != null)
	if item == null:
		return

	assert_eq(item.get_script().resource_path, "res://src/PickupItem.cs")
	assert_eq(item.collision_layer, 2)
	assert_eq(item.collision_mask, 1)
	assert_eq(item.gravity_scale, 0.0)
	assert_true(item.get_node("CollisionShape2D").shape is CircleShape2D)


func test_baby_pickup_item_has_crawl_contract() -> void:
	var baby: RigidBody2D = track(BABY_PICKUP_ITEM_SCENE.instantiate()) as RigidBody2D

	assert_true(baby != null)
	if baby == null:
		return

	assert_eq(baby.get_script().resource_path, "res://src/BabyPickupItem.cs")
	assert_eq(baby.collision_layer, 2)
	assert_eq(baby.collision_mask, 1)
	var shape: CircleShape2D = baby.get_node("CollisionShape2D").shape as CircleShape2D
	assert_true(shape != null)
	if shape != null:
		assert_true(is_equal_approx(shape.radius, 32.01562))

	var sprite := baby.get_node("AnimatedSprite2D") as AnimatedSprite2D
	assert_true(sprite != null)
	if sprite != null:
		assert_eq(sprite.sprite_frames.get_frame_count("crawl"), 2)
		assert_eq(sprite.sprite_frames.get_frame_texture("crawl", 0).get_width(), 64)
		assert_eq(sprite.sprite_frames.get_frame_texture("crawl", 1).get_width(), 64)


func test_main_scene_has_one_baby_pickup() -> void:
	var level := track(MAIN_SCENE.instantiate())
	var baby: Node = level.get_node_or_null("BabyPickupItem")

	assert_true(baby != null)


func _has_key_binding(events: Array, keycode: Key) -> bool:
	for event in events:
		if event is InputEventKey and event.keycode == keycode:
			return true
	return false


func _has_stick_binding(events: Array, axis: int, axis_value: float) -> bool:
	for event in events:
		if (
			event is InputEventJoypadMotion
			and event.device == -1
			and event.axis == axis
			and is_equal_approx(event.axis_value, axis_value)
		):
			return true
	return false


func _has_button_binding(events: Array, button_index: JoyButton) -> bool:
	for event in events:
		if (
			event is InputEventJoypadButton
			and event.device == -1
			and event.button_index == button_index
		):
			return true
	return false
