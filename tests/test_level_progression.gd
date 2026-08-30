@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

const LEVEL_1_PATH := "res://scenes/level_1.tscn"
const LEVEL_2_PATH := "res://scenes/level_2.tscn"
const LEVEL_3_PATH := "res://scenes/level_3.tscn"


func suite_name() -> String:
	return "level_progression"


func test_title_starts_the_game_and_levels_advance_in_order() -> void:
	var project_config := ConfigFile.new()
	assert_eq(project_config.load("res://project.godot"), OK)
	assert_eq(
		project_config.get_value("application", "run/main_scene"),
		"res://scenes/title_screen.tscn",
	)
	var instant_win_input := project_config.get_value(
		"input",
		"debug_instant_win",
	) as Dictionary
	assert_true(
		instant_win_input.events.any(
			func(event: InputEvent) -> bool:
				return event is InputEventKey and event.keycode == KEY_F10
		)
	)

	var level_1 := track(_instantiate_scene(LEVEL_1_PATH)) as Node2D
	var level_1_hud := level_1.get_node("Hud")
	assert_eq(
		level_1_hud.get("NextLevelScenePath"),
		"res://scenes/level_2.tscn",
	)
	assert_eq(
		level_1_hud.get("NextLevelRevealTargetPath"),
		NodePath("Player"),
	)

	var level_2 := track(_instantiate_scene(LEVEL_2_PATH)) as Node2D
	assert_true(level_2.has_node("Player"))
	var level_2_hud := level_2.get_node("Hud")
	assert_eq(level_2_hud.get("NextLevelScenePath"), LEVEL_3_PATH)
	assert_eq(
		level_2_hud.get("NextLevelRevealTargetPath"),
		NodePath("Player"),
	)
	assert_false(level_2_hud.has_node("InstantWinButton"))

	var level_3 := track(_instantiate_scene(LEVEL_3_PATH)) as Node2D
	assert_true(level_3.has_node("Player"))
	assert_eq(level_3.get_node("Hud").get("NextLevelScenePath"), "")


func _instantiate_scene(path: String) -> Node:
	var packed_scene := ResourceLoader.load(
		path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE,
	) as PackedScene
	return packed_scene.instantiate()
