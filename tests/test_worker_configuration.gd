@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

const WORKER_SCENE := preload("res://scenes/npc_worker.tscn")
const SHARED_PERSONALITY := preload(
	"res://resources/npc_personalities/kitchen_worker.tres"
)


func suite_name() -> String:
	return "worker_configuration"


func test_worker_exposes_an_isolated_error_rate_on_its_root() -> void:
	var reliable_worker := track(WORKER_SCENE.instantiate()) as CharacterBody2D
	var error_prone_worker := track(WORKER_SCENE.instantiate()) as CharacterBody2D
	assert_eq(
		reliable_worker.get_script().resource_path,
		"res://src/worker_configuration.gd",
	)
	assert_true(is_equal_approx(float(reliable_worker.get("ErrorRate")), 0.6))

	reliable_worker.set("ErrorRate", 0.0)
	error_prone_worker.set("ErrorRate", 1.0)
	assert_true(
		is_equal_approx(float(reliable_worker.get("ErrorRate")), 0.0)
	)
	assert_true(
		is_equal_approx(float(error_prone_worker.get("ErrorRate")), 1.0)
	)
	assert_true(
		is_equal_approx(float(SHARED_PERSONALITY.get("FailureChance")), 0.6),
		"The shared personality must retain the existing default.",
	)

	var error_rate_property: Dictionary = {}
	for property: Dictionary in reliable_worker.get_property_list():
		if property.name == &"ErrorRate":
			error_rate_property = property
			break
	assert_false(error_rate_property.is_empty())
	if not error_rate_property.is_empty():
		assert_eq(int(error_rate_property.hint), PROPERTY_HINT_RANGE)
		assert_true(String(error_rate_property.hint_string).begins_with("0,1,"))
