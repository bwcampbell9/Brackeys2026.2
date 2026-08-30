extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const STOVE_SCENE := preload("res://scenes/stove.tscn")
const POTATO_SCENE := preload("res://scenes/pickup_item.tscn")
const CARROT_SCENE := preload("res://scenes/carrot_item.tscn")
const CHOPPED_POTATOES := preload("res://resources/items/chopped_potatoes.tres")
const CHOPPED_CARROTS := preload("res://resources/items/chopped_carrots.tres")
const POTATO_SOUP := preload("res://resources/items/potato_soup.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := MAIN_SCENE.instantiate()
	root.add_child(level)
	await process_frame
	var placed_stove := level.get_node_or_null("Stove") as StaticBody2D
	_check(placed_stove != null, "The main scene must contain the stove.")
	level.queue_free()
	await process_frame

	var world := Node2D.new()
	root.add_child(world)
	await _test_single_soup(world)
	await _test_combined_soup(world)
	world.queue_free()
	await process_frame
	print("stove_cooking_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _test_single_soup(world: Node2D) -> void:
	var stove := STOVE_SCENE.instantiate() as StaticBody2D
	var potatoes := POTATO_SCENE.instantiate() as RigidBody2D
	potatoes.set("Definition", CHOPPED_POTATOES)
	world.add_child(stove)
	world.add_child(potatoes)
	await process_frame

	var spawn_point := stove.get_node("ItemSpawnPoint") as Node2D
	spawn_point.position = Vector2(18, -70)
	var socket := spawn_point.get_node("PickupSocket") as Node2D
	var controller := stove.get_node("OvenCookingController") as Node
	var back_sprite := stove.get_node("BackSprite") as AnimatedSprite2D
	var front_sprite := stove.get_node("FrontSprite") as AnimatedSprite2D
	_select_fast_recipe(controller, &"potato_soup")
	_check(bool(socket.TryStore(potatoes, 0.0)), "The stove must accept its selected ingredient.")
	await process_frame
	_check(bool(controller.get("IsCooking")), "A complete soup recipe must start.")
	_check(back_sprite.animation == &"cooking", "The stove back must animate while cooking.")
	_check(front_sprite.animation == &"cooking", "The stove front must animate while cooking.")
	await create_timer(0.45).timeout

	var cooked_definition := potatoes.get("Definition") as Resource
	_check(cooked_definition.get("Id") == POTATO_SOUP.get("Id"), "Chopped potatoes must become potato soup.")
	var soup_sprite := potatoes.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_check(soup_sprite.visible, "Soup results must show their animated pickup visual.")
	_check(soup_sprite.sprite_frames.get_frame_count(&"idle") == 2, "Potato soup must have two frames.")
	_check(back_sprite.animation == &"idle", "The stove back must return to idle.")
	_check(front_sprite.animation == &"idle", "The stove front must return to idle.")
	stove.queue_free()
	potatoes.queue_free()
	await process_frame


func _test_combined_soup(world: Node2D) -> void:
	var stove := STOVE_SCENE.instantiate() as StaticBody2D
	var carrots := CARROT_SCENE.instantiate() as RigidBody2D
	var potatoes := POTATO_SCENE.instantiate() as RigidBody2D
	carrots.set("Definition", CHOPPED_CARROTS)
	potatoes.set("Definition", CHOPPED_POTATOES)
	world.add_child(stove)
	world.add_child(carrots)
	world.add_child(potatoes)
	await process_frame

	var primary := stove.get_node("ItemSpawnPoint/PickupSocket") as Node2D
	var secondary := stove.get_node("ItemSpawnPoint/SecondaryPickupSocket") as Node2D
	var controller := stove.get_node("OvenCookingController") as Node
	var back_sprite := stove.get_node("BackSprite") as AnimatedSprite2D
	var front_sprite := stove.get_node("FrontSprite") as AnimatedSprite2D
	_select_fast_recipe(controller, &"carrot_potato_soup")
	_check(bool(primary.TryStore(carrots, 0.0)), "Combined soup must accept carrots first.")
	await create_timer(0.15).timeout
	_check(not bool(controller.get("IsCooking")), "Combined soup must wait for potatoes.")
	_check(
		back_sprite.animation == &"idle" and front_sprite.animation == &"idle",
		"The stove animation must remain idle until every ingredient is present.",
	)
	_check(bool(secondary.TryStore(potatoes, 0.0)), "Combined soup must accept potatoes second.")
	await process_frame
	await process_frame
	_check(bool(controller.get("IsCooking")), "Combined soup must start with both ingredients.")
	_check(
		back_sprite.animation == &"cooking" and front_sprite.animation == &"cooking",
		"Both stove layers must animate once the recipe is complete.",
	)
	_check(
		carrots.global_position.x < potatoes.global_position.x
		and carrots.position.y < -60.0
		and potatoes.position.y < -60.0,
		"Both soup ingredients must be presented side by side above the pot (carrots=%s, potatoes=%s)."
		% [carrots.position, potatoes.position],
	)
	await create_timer(0.45).timeout

	var definition := carrots.get("Definition") as Resource
	_check(definition.get("Id") == &"carrot_potato_soup", "Both ingredients must become combined soup.")
	_check(secondary.get("Item") == null, "The second soup ingredient must be consumed.")
	var frames := definition.get("SpriteFrames") as SpriteFrames
	var frame := frames.get_frame_texture(&"idle", 0) as AtlasTexture
	_check(
		frame.region == Rect2(384, 0, 64, 64),
		"Combined soup must use the final authored soup frames.",
	)
	stove.queue_free()
	carrots.queue_free()
	await process_frame


func _select_fast_recipe(controller: Node, output_id: StringName) -> void:
	for recipe: Resource in controller.get("Recipes"):
		if recipe.get("Output").get("Id") != output_id:
			continue
		var fast_recipe := recipe.duplicate()
		fast_recipe.set("Duration", 0.35)
		controller.set("SelectedCookingRecipe", fast_recipe)
		return
	_check(false, "Expected cooking recipe %s." % output_id)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
