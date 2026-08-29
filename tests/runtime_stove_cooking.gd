extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const STOVE_SCENE := preload("res://scenes/stove.tscn")
const POTATO_SCENE := preload("res://scenes/pickup_item.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := MAIN_SCENE.instantiate()
	root.add_child(level)
	await process_frame
	var placed_stove := level.get_node_or_null("Stove") as StaticBody2D
	_check(placed_stove != null, "The main scene must contain the stove.")
	if placed_stove != null:
		_check(placed_stove.position == Vector2(672, 238), "The stove must be one tile above the cutting board.")
	level.queue_free()
	await process_frame

	var world := Node2D.new()
	var stove := STOVE_SCENE.instantiate() as StaticBody2D
	var potato := POTATO_SCENE.instantiate() as RigidBody2D
	world.add_child(stove)
	world.add_child(potato)
	root.add_child(world)
	await process_frame
	await process_frame

	var spawn_point := stove.get_node("ItemSpawnPoint") as Node2D
	spawn_point.position = Vector2(18, -70)
	var socket := spawn_point.get_node("PickupSocket") as Node2D
	var controller := stove.get_node("OvenCookingController") as Node
	var back_sprite := stove.get_node("BackSprite") as AnimatedSprite2D
	var front_sprite := stove.get_node("FrontSprite") as AnimatedSprite2D
	var fast_recipe := (controller.get("Recipe") as Resource).duplicate()
	fast_recipe.set("Duration", 0.25)
	controller.set("Recipe", fast_recipe)
	_check(bool(socket.TryStore(potato, 0.0)), "The stove must accept any item.")
	_check(potato.get_parent() == socket, "Raw items must be attached to the editable spawn point socket.")
	await process_frame
	_check(bool(controller.get("IsCooking")), "Stored items must start cooking automatically.")
	_check(back_sprite.animation == &"cooking", "The stove back must animate while cooking.")
	_check(front_sprite.animation == &"cooking", "The stove front must animate while cooking.")
	await create_timer(0.08).timeout
	_check(potato.position.x == 22.0, "Cooking items must stay centered at the authored horizontal offset.")
	_check(potato.position.y != -78.0, "Cooking items must bob around the authored vertical offset.")
	_check(potato.rotation != 0.0, "Cooking items must rotate slightly while bobbing.")
	await create_timer(0.25).timeout

	var cooked_definition := potato.get("Definition") as Resource
	_check(cooked_definition.get("Id") == &"cooked_potato", "The stove must apply the cooking transformation.")
	_check(back_sprite.animation == &"idle", "The stove back must return to idle after cooking.")
	_check(front_sprite.animation == &"idle", "The stove front must return to idle after cooking.")
	_check(potato.position == Vector2(22, -78), "Finished items must remain at the authored stove offset.")
	_check(
		potato.global_position == spawn_point.global_position + Vector2(22, -78),
		"Cooked items must finish at the editable spawn point plus its authored offset.",
	)
	_check(potato.rotation == 0.0, "Finished items must reset their rotation.")
	world.queue_free()
	await process_frame
	print("stove_cooking_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)