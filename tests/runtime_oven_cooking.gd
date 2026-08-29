extends SceneTree

const OVEN_SCENE := preload("res://scenes/oven.tscn")
const POTATO_SCENE := preload("res://scenes/pickup_item.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	var oven := OVEN_SCENE.instantiate() as StaticBody2D
	var potato := POTATO_SCENE.instantiate() as RigidBody2D
	world.add_child(oven)
	world.add_child(potato)
	root.add_child(world)
	await process_frame
	await process_frame

	var socket := oven.get_node("PickupSocket") as Node2D
	var controller := oven.get_node("OvenCookingController") as Node
	var sprite := oven.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var fast_recipe := (controller.get("Recipe") as Resource).duplicate()
	fast_recipe.set("Duration", 0.1)
	controller.set("Recipe", fast_recipe)
	_check(bool(socket.TryStore(potato, 0.0)), "The oven must accept any item.")
	await process_frame
	_check(bool(controller.get("IsCooking")), "Stored items must start cooking automatically.")
	_check(sprite.animation == &"cooking", "The oven must animate while cooking.")
	await create_timer(0.2).timeout

	var cooked_definition := potato.get("Definition") as Resource
	_check(cooked_definition.get("Id") == &"cooked_potato", "Items without an authored output must receive a cooked definition.")
	_check(cooked_definition.get("AppliedTransformationIds").has(&"cook"), "The cooked definition must record the cooking transformation.")
	var fallback_material := cooked_definition.get("VisualMaterial") as Material
	_check(
		fallback_material != null
		and fallback_material.resource_path == "res://resources/materials/cooked_brown_black.tres",
		"Fallback cooking must apply the browned and blackened material.",
	)
	_check(sprite.animation == &"idle", "The oven must return to idle after cooking.")
	world.queue_free()
	await process_frame
	print("oven_cooking_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)