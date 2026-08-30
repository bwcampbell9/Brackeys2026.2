extends SceneTree

const OVEN_SCENE := preload("res://scenes/oven.tscn")
const POTATO_SCENE := preload("res://scenes/pickup_item.tscn")
const CARROT_SCENE := preload("res://scenes/carrot_item.tscn")
const CHOPPED_POTATOES := preload("res://resources/items/chopped_potatoes.tres")
const CHOPPED_CARROTS := preload("res://resources/items/chopped_carrots.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	await _test_single_baked_potato(world)
	await _test_combined_recipe_waits_and_consumes(world)
	await _test_legacy_fallback(world)
	world.queue_free()
	await process_frame
	print("oven_cooking_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _test_single_baked_potato(world: Node2D) -> void:
	var oven := OVEN_SCENE.instantiate() as StaticBody2D
	var potato := POTATO_SCENE.instantiate() as RigidBody2D
	world.add_child(oven)
	world.add_child(potato)
	await process_frame

	var socket := oven.get_node("PickupSocket") as Node2D
	var controller := oven.get_node("OvenCookingController") as Node
	var sprite := oven.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_select_fast_recipe(controller, &"cooked_potato")
	_check(bool(socket.TryStore(potato, 0.0)), "The oven must accept its selected ingredient.")
	await process_frame
	_check(bool(controller.get("IsCooking")), "A complete single-input recipe must start.")
	_check(sprite.animation == &"cooking", "The oven must animate while cooking.")
	await create_timer(0.45).timeout

	var cooked_definition := potato.get("Definition") as Resource
	_check(cooked_definition.get("Id") == &"cooked_potato", "Potatoes must use the authored baked output.")
	var baked_frames := cooked_definition.get("SpriteFrames") as SpriteFrames
	_check(
		baked_frames != null and baked_frames.get_frame_count(&"idle") == 3,
		"Baked potatoes must use all three authored frames.",
	)
	_check(sprite.animation == &"idle", "The oven must return to idle after cooking.")
	oven.queue_free()
	potato.queue_free()
	await process_frame


func _test_combined_recipe_waits_and_consumes(world: Node2D) -> void:
	var oven := OVEN_SCENE.instantiate() as StaticBody2D
	var potatoes := POTATO_SCENE.instantiate() as RigidBody2D
	var carrots := CARROT_SCENE.instantiate() as RigidBody2D
	potatoes.set("Definition", CHOPPED_POTATOES)
	carrots.set("Definition", CHOPPED_CARROTS)
	world.add_child(oven)
	world.add_child(potatoes)
	world.add_child(carrots)
	await process_frame

	var primary := oven.get_node("PickupSocket") as Node2D
	var secondary := oven.get_node("SecondaryPickupSocket") as Node2D
	var controller := oven.get_node("OvenCookingController") as Node
	_select_fast_recipe(controller, &"baked_chopped_vegetables")
	_check(bool(primary.TryStore(potatoes, 0.0)), "The oven must accept either missing combined ingredient first.")
	await create_timer(0.15).timeout
	_check(not bool(controller.get("IsCooking")), "A two-input recipe must wait for every ingredient.")
	var oven_sprite := oven.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_check(
		oven_sprite.animation == &"idle",
		"The oven animation must remain idle until every ingredient is present.",
	)
	_check(
		potatoes.get("Definition").get("Id") == &"chopped_potatoes",
		"Waiting for the second ingredient must not transform the first.",
	)
	_check(bool(controller.call("CanAccept", carrots)), "The other missing ingredient must remain accepted.")
	_check(not bool(controller.call("CanAccept", potatoes)), "A duplicate ingredient must be rejected.")
	_check(bool(secondary.TryStore(carrots, 0.0)), "The second recipe ingredient must fit the second socket.")
	await process_frame
	_check(bool(controller.get("IsCooking")), "Cooking must start when the full ingredient multiset is present.")
	_check(
		oven_sprite.animation == &"cooking",
		"The oven animation must start with the complete recipe.",
	)
	_check(
		potatoes.global_position.x < carrots.global_position.x,
		"Both cooking ingredients must remain visible side by side.",
	)

	var removed := secondary.Take(world, 0.0) as RigidBody2D
	await process_frame
	_check(not bool(controller.get("IsCooking")), "Removing an ingredient must cancel and reset cooking.")
	_check(is_zero_approx(float(controller.get("Progress"))), "Canceled cooking must reset progress.")
	_check(bool(secondary.TryStore(removed, 0.0)), "A removed ingredient must be replaceable.")
	await create_timer(0.45).timeout

	var combined_definition := potatoes.get("Definition") as Resource
	_check(
		combined_definition.get("Id") == &"baked_chopped_vegetables",
		"The two ingredients must become the combined baked dish.",
	)
	_check(secondary.get("Item") == null, "The additional ingredient must be consumed.")
	_check(
		controller.call("GetFirstMissingIngredient") == null,
		"A completed output must not trigger another ingredient request.",
	)
	var extra_carrots := CARROT_SCENE.instantiate() as RigidBody2D
	extra_carrots.set("Definition", CHOPPED_CARROTS)
	world.add_child(extra_carrots)
	_check(
		not bool(controller.call("CanAccept", extra_carrots)),
		"A completed output must block extra recipe ingredients until collected.",
	)
	var frames := combined_definition.get("SpriteFrames") as SpriteFrames
	var frame := frames.get_frame_texture(&"idle", 0) as AtlasTexture
	_check(
		frame.atlas.resource_path
		== "res://assets/sprites/chopped_baked_carrots_and_potatos/chopped_baked_carrots_and_potatos-Sheet.png",
		"The combined baked dish must use its authored sprite sheet.",
	)
	oven.queue_free()
	potatoes.queue_free()
	extra_carrots.queue_free()
	await process_frame


func _test_legacy_fallback(world: Node2D) -> void:
	var oven := OVEN_SCENE.instantiate() as StaticBody2D
	var carrot := CARROT_SCENE.instantiate() as RigidBody2D
	world.add_child(oven)
	world.add_child(carrot)
	await process_frame
	var socket := oven.get_node("PickupSocket") as Node2D
	var controller := oven.get_node("OvenCookingController") as Node
	controller.set("Recipes", [])
	controller.set("SelectedCookingRecipe", null)
	var fallback_recipe := (controller.get("Recipe") as Resource).duplicate()
	fallback_recipe.set("Duration", 0.1)
	controller.set("Recipe", fallback_recipe)
	_check(bool(socket.TryStore(carrot, 0.0)), "Legacy cooking must remain available without authored recipes.")
	await create_timer(0.2).timeout
	var cooked_carrot := carrot.get("Definition") as Resource
	var fallback_material := cooked_carrot.get("VisualMaterial") as Material
	_check(cooked_carrot.get("Id") == &"cooked_carrot", "Legacy outputs must retain generated IDs.")
	_check(
		fallback_material != null
		and fallback_material.resource_path == "res://resources/materials/cooked_brown_black.tres",
		"Legacy outputs must retain the browned fallback material.",
	)
	oven.queue_free()
	carrot.queue_free()
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
