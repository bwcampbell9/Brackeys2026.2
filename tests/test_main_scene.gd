@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

# The Godot AI scene-test runner currently discovers GDScript suites only.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const EXPECTED_BOUNDARIES := {
	"LeftCollision": {"position": Vector2(20, 270), "size": Vector2(40, 540)},
	"RightCollision": {"position": Vector2(940, 270), "size": Vector2(40, 540)},
	"TopCollision": {"position": Vector2(480, 20), "size": Vector2(960, 40)},
	"BottomCollision": {"position": Vector2(480, 520), "size": Vector2(960, 40)},
}
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
	var walls := level.get_node_or_null("Walls") as StaticBody2D

	assert_true(player != null, "The level must contain a CharacterBody2D player.")
	assert_true(walls != null, "The level must contain static boundary walls.")
	if player == null or walls == null:
		return

	assert_eq(player.get_script().resource_path, "res://src/Player.cs")
	assert_true(float(player.get("Speed")) > 0.0, "Player speed must be positive.")

	var player_shape := player.get_node("CollisionShape2D") as CollisionShape2D
	assert_true(player_shape != null, "Player must have a collision shape.")
	if player_shape != null:
		assert_false(player_shape.disabled)
		assert_true(
			player_shape.shape is RectangleShape2D,
			"Player collision must use a RectangleShape2D.",
		)

	var collision_shapes: Array[CollisionShape2D] = []
	for child in walls.get_children():
		if child is CollisionShape2D:
			collision_shapes.append(child)
	assert_eq(collision_shapes.size(), EXPECTED_BOUNDARIES.size())

	for collision_shape in collision_shapes:
		var expected: Dictionary = EXPECTED_BOUNDARIES.get(collision_shape.name, {})
		assert_false(expected.is_empty(), "Every wall collision must be intentional.")
		assert_false(collision_shape.disabled)
		assert_true(
			collision_shape.shape is RectangleShape2D,
			"%s must use a RectangleShape2D." % collision_shape.name,
		)
		if not expected.is_empty() and collision_shape.shape is RectangleShape2D:
			assert_eq(collision_shape.position, expected.position)
			assert_eq((collision_shape.shape as RectangleShape2D).size, expected.size)

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
