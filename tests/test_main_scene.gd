@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

# The Godot AI scene-test runner currently discovers GDScript suites only.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PICKUP_ITEM_SCENE := preload("res://scenes/pickup_item.tscn")
const BABY_PICKUP_ITEM_SCENE := preload("res://scenes/baby_pickup_item.tscn")
const KNIFE_ITEM_SCENE := preload("res://scenes/knife_item.tscn")
const CUTTING_BOARD_SCENE := preload("res://scenes/cutting_board.tscn")
const POTATO_CONTAINER_SCENE := preload("res://scenes/potato_container.tscn")
const KNIFE_CONTAINER_SCENE := preload("res://scenes/knife_container.tscn")
const CHOP_RECIPE := preload("res://resources/recipes/chop.tres")
const CHOP_TRANSFORMATION := preload("res://resources/transformations/chop.tres")
const POTATO_DEFINITION := preload("res://resources/items/potato.tres")
const CHOPPED_POTATOES_DEFINITION := preload("res://resources/items/chopped_potatoes.tres")
const KNIFE_DEFINITION := preload("res://resources/items/knife.tres")
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
	var replaced_container_data = room_tiles.tile_set.get_source(1).get_tile_data(
		Vector2i(0, 0),
		0,
	)
	assert_eq(replaced_container_data.get_collision_polygons_count(0), 0)
	assert_eq(room_tiles.tile_set.get_custom_data_layers_count(), 0)

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


func test_player_has_composable_interaction_components() -> void:
	var level := track(MAIN_SCENE.instantiate())
	var player := level.get_node("Player") as CharacterBody2D
	var carrier := player.get_node_or_null("PickupCarrier") as Node2D
	var interactor := player.get_node_or_null("Interactor") as Node2D
	var input_manager := player.get_node_or_null("InputManager") as Node
	var player_shape := player.get_node("CollisionShape2D").shape as CircleShape2D

	assert_true(carrier != null, "The player must contain a pickup carrier.")
	assert_true(interactor != null, "The player must contain an interactor.")
	assert_true(input_manager != null, "The player must contain an input manager.")
	assert_true(player_shape != null, "The player must have a circular collision shape.")
	if carrier == null or interactor == null or input_manager == null or player_shape == null:
		return

	assert_eq(carrier.get_script().resource_path, "res://src/PickupCarrier.cs")
	assert_true(is_equal_approx(float(carrier.get("PickupDuration")), 0.2))
	assert_true(float(carrier.get("ThrowForce")) > 0.0)
	assert_true(carrier.get_node_or_null("HoldPoint") is Node2D)
	assert_true(
		carrier.get_node_or_null("PickupArea") == null,
		"The carrier must not own interaction sensing.",
	)

	assert_eq(interactor.get_script().resource_path, "res://src/PlayerInteractor.cs")
	assert_eq(float(interactor.get("InteractionConeDegrees")), 140.0)
	assert_eq(float(interactor.get("TargetFocusDistance")), 48.0)
	assert_false(bool(interactor.get("UseTargetPriority")))
	var interaction_area := interactor.get_node_or_null("InteractionArea") as Area2D
	assert_true(interaction_area != null)
	if interaction_area != null:
		assert_eq(interaction_area.collision_mask, 8)
		var pickup_shape: Shape2D = interaction_area.get_node("CollisionShape2D").shape
		assert_true(
			pickup_shape is CircleShape2D,
			"The interaction range must use a circular broad-phase area.",
		)
		if pickup_shape is CircleShape2D:
			assert_true(
				pickup_shape.radius > player_shape.radius,
				"The interaction range must extend beyond the player collision.",
			)

	var close_area := interactor.get_node_or_null("CloseInteractionArea") as Area2D
	assert_true(close_area != null)
	if close_area != null:
		assert_eq(close_area.collision_mask, 8)
		assert_eq(
			close_area.get_node("CollisionShape2D").shape,
			player.get_node("CollisionShape2D").shape,
			"The close interaction area must match the player collision footprint.",
		)

	assert_eq(input_manager.get_script().resource_path, "res://src/PlayerInputManager.cs")
	assert_true(is_equal_approx(float(input_manager.get("HoldThreshold")), 0.35))


func test_input_manager_has_separate_rebindable_tap_and_hold_mappings() -> void:
	var player := track(PLAYER_SCENE.instantiate()) as CharacterBody2D
	Engine.get_main_loop().root.add_child(player)
	var input_manager := player.get_node("InputManager")
	var mappings: Array = input_manager.get("InteractionInputs")

	assert_eq(mappings.size(), 2)
	if mappings.size() != 2:
		return

	var tap_mapping: Resource = mappings[0]
	var hold_mapping: Resource = mappings[1]
	assert_ne(tap_mapping, hold_mapping)
	assert_eq(tap_mapping.get("InputAction"), &"interact")
	assert_eq(hold_mapping.get("InputAction"), &"interact")
	assert_eq(int(tap_mapping.get("Trigger")), 0)
	assert_eq(int(hold_mapping.get("Trigger")), 1)
	assert_eq(tap_mapping.get("ActionIds"), [&"transfer"])
	assert_eq(hold_mapping.get("ActionIds"), [&"process"])


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
	var definition: Resource = item.get("Definition")
	assert_true(definition != null)
	if definition != null:
		assert_eq(definition.get("Id"), &"potato")
	var target := item.get_node_or_null("InteractionTarget") as Area2D
	assert_true(target != null)
	if target != null:
		assert_eq(target.collision_layer, 8)
		var action := target.get_node("PickupTransferAction")
		assert_eq(action.get("ActionId"), &"transfer")
		assert_eq(int(action.get("Trigger")), 0)


func test_baby_pickup_item_has_crawl_contract() -> void:
	var baby: RigidBody2D = track(BABY_PICKUP_ITEM_SCENE.instantiate()) as RigidBody2D

	assert_true(baby != null)
	if baby == null:
		return

	assert_eq(baby.get_script().resource_path, "res://src/BabyPickupItem.cs")
	assert_eq(baby.get("Definition").get("Id"), &"baby")
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
		var transformed_definition := CHOP_TRANSFORMATION.Resolve(baby.get("Definition"))
		baby.SetDefinition(transformed_definition)
		assert_eq(transformed_definition.get("Id"), &"chopped_baby")
		assert_eq(sprite.material, CHOP_TRANSFORMATION.get("FallbackMaterial"))

	var target := baby.get_node_or_null("InteractionTarget") as Area2D
	assert_true(target != null)
	if target != null:
		assert_eq(target.collision_layer, 8)


func test_knife_item_has_pickup_definition() -> void:
	var knife := track(KNIFE_ITEM_SCENE.instantiate()) as RigidBody2D

	assert_true(knife != null)
	if knife == null:
		return

	assert_eq(knife.get_script().resource_path, "res://src/PickupItem.cs")
	assert_eq(knife.get("Definition"), KNIFE_DEFINITION)
	assert_eq(KNIFE_DEFINITION.get("Id"), &"knife")
	assert_eq(
		KNIFE_DEFINITION.get("Texture").resource_path,
		"res://assets/sprites/knife.png",
	)
	assert_true(knife.get_node("InteractionTarget") is Area2D)


func test_main_scene_has_one_baby_pickup() -> void:
	var level := track(MAIN_SCENE.instantiate())
	var baby: Node = level.get_node_or_null("BabyPickupItem")

	assert_true(baby != null)


func test_cutting_board_composes_transfer_process_and_socket() -> void:
	var board := track(CUTTING_BOARD_SCENE.instantiate()) as StaticBody2D
	var socket := board.get_node_or_null("PickupSocket")
	var target := board.get_node_or_null("InteractionTarget") as Area2D

	assert_true(socket != null)
	assert_true(target != null)
	if socket == null or target == null:
		return

	assert_eq(socket.get_script().resource_path, "res://src/PickupSocket.cs")
	var board_sprite := board.get_node("Sprite2D") as Sprite2D
	assert_true(board_sprite != null)
	var board_texture := board_sprite.texture as AtlasTexture
	assert_true(board_texture != null)
	if board_texture != null:
		assert_eq(
			board_texture.atlas.resource_path,
			"res://assets/sprites/workstations_tilemap/workstations.png",
		)
		assert_eq(board_texture.region, Rect2(128, 0, 64, 64))
	var board_shape := board.get_node("CollisionShape2D").shape as RectangleShape2D
	assert_true(board_shape != null)
	if board_shape != null:
		assert_eq(board_shape.size, Vector2(64, 64))
	assert_eq(target.collision_layer, 8)
	assert_eq(target.priority, 2)

	var transfer := target.get_node("TransferItemAction")
	var process := target.get_node("ProcessItemAction")
	assert_eq(transfer.get_script().resource_path, "res://src/SlotTransferAction.cs")
	assert_eq(process.get_script().resource_path, "res://src/TimedItemProcessAction.cs")
	assert_eq(transfer.get("SocketPath"), NodePath("../../PickupSocket"))
	assert_eq(process.get("SocketPath"), NodePath("../../PickupSocket"))
	assert_eq(transfer.get("ActionId"), &"transfer")
	assert_eq(int(transfer.get("Trigger")), 0)
	assert_eq(process.get("ActionId"), &"process")
	assert_eq(int(process.get("Trigger")), 1)
	assert_eq(process.get("Recipe"), CHOP_RECIPE)
	assert_eq(CHOP_RECIPE.get("Transformation"), CHOP_TRANSFORMATION)
	assert_eq(CHOP_TRANSFORMATION.get("Id"), &"chop")
	assert_eq(
		CHOP_TRANSFORMATION.get("FallbackMaterial").resource_path,
		"res://resources/materials/chopped_green.tres",
	)
	var potato_overrides: Array = POTATO_DEFINITION.get("TransformationOverrides")
	assert_eq(potato_overrides.size(), 1)
	assert_eq(potato_overrides[0].get("TransformationId"), &"chop")
	assert_eq(potato_overrides[0].get("Output"), CHOPPED_POTATOES_DEFINITION)
	assert_true(
		CHOPPED_POTATOES_DEFINITION.get("AppliedTransformationIds").has(&"chop")
	)
	assert_eq(CHOP_RECIPE.get("RequiredTool"), KNIFE_DEFINITION)
	assert_true(float(CHOP_RECIPE.get("Duration")) > 0.0)
	var progress_bar := board.get_node_or_null("ProgressBar") as ProgressBar
	assert_true(progress_bar != null)
	if progress_bar != null:
		assert_false(progress_bar.visible)
		assert_eq(progress_bar.max_value, 100.0)
	var presentation := board.get_node_or_null("ProcessPresentation")
	assert_true(presentation != null)
	if presentation != null:
		assert_eq(
			presentation.get_script().resource_path,
			"res://src/CuttingBoardProcessPresentation.cs",
		)


func test_potato_container_owns_its_visual_collision_and_interaction() -> void:
	var container := track(POTATO_CONTAINER_SCENE.instantiate()) as StaticBody2D

	assert_true(container != null)
	if container == null:
		return

	assert_eq(container.collision_layer, 1)
	assert_eq(container.collision_mask, 0)
	var container_sprite := container.get_node("Sprite2D") as Sprite2D
	assert_true(container_sprite != null)
	var container_texture := container_sprite.texture as AtlasTexture
	assert_true(container_texture != null)
	if container_texture != null:
		assert_eq(
			container_texture.atlas.resource_path,
			"res://assets/sprites/workstations_tilemap/workstations.png",
		)
		assert_eq(container_texture.region, Rect2(64, 0, 64, 64))
	var shape := container.get_node("CollisionShape2D").shape as RectangleShape2D
	assert_true(shape != null)
	if shape != null:
		assert_eq(shape.size, Vector2(64, 64))
	assert_eq(
		container.get_node("InteractionTarget/PickupContainerAction").get("PickupScene"),
		PICKUP_ITEM_SCENE,
	)
	assert_eq(
		container.get_node("InteractionTarget/PickupContainerAction").get("AcceptedItem").get("Id"),
		&"potato",
	)
	assert_true(
		float(
			container.get_node("InteractionTarget/PickupContainerAction").get("ReturnDuration")
		) > 0.0
	)


func test_knife_container_supplies_the_knife_scene() -> void:
	var container := track(KNIFE_CONTAINER_SCENE.instantiate()) as StaticBody2D

	assert_true(container != null)
	if container == null:
		return

	var texture := container.get_node("Sprite2D").texture as AtlasTexture
	assert_true(texture != null)
	if texture != null:
		assert_eq(
			texture.atlas.resource_path,
			"res://assets/sprites/workstations_tilemap/workstations.png",
		)
		assert_eq(texture.region, Rect2(192, 0, 64, 64))
	assert_eq(
		container.get_node("InteractionTarget/PickupContainerAction").get("PickupScene"),
		KNIFE_ITEM_SCENE,
	)
	assert_eq(
		container.get_node("InteractionTarget/PickupContainerAction").get("AcceptedItem"),
		KNIFE_DEFINITION,
	)
	assert_true(
		float(
			container.get_node("InteractionTarget/PickupContainerAction").get("ReturnSpinTurns")
		) > 0.0
	)


func test_main_scene_has_interactable_container_and_cutting_board() -> void:
	var level := track(MAIN_SCENE.instantiate())
	var workstations := level.get_node_or_null("Workstations") as TileMapLayer

	assert_true(workstations != null, "The level must contain a workstation tile layer.")
	if workstations == null:
		return

	assert_eq(workstations.position, Vector2(0, 14))
	assert_true(workstations.tile_set != null)
	assert_eq(
		workstations.tile_set.resource_path,
		"res://assets/sprites/workstations_tilemap/workstations_tiles.tres",
	)
	assert_eq(
		workstations.get_used_cells(),
		[Vector2i(1, 6), Vector2i(10, 4), Vector2i(11, 4)],
	)

	var source := workstations.tile_set.get_source(0) as TileSetScenesCollectionSource
	assert_true(source != null, "Workstations must use a scene collection tile source.")
	if source == null:
		return

	assert_eq(source.get_scene_tiles_count(), 3)
	assert_eq(workstations.get_cell_atlas_coords(Vector2i(1, 6)), Vector2i.ZERO)
	assert_eq(workstations.get_cell_atlas_coords(Vector2i(10, 4)), Vector2i.ZERO)
	assert_eq(workstations.get_cell_atlas_coords(Vector2i(11, 4)), Vector2i.ZERO)
	var container_tile_id := workstations.get_cell_alternative_tile(Vector2i(1, 6))
	var board_tile_id := workstations.get_cell_alternative_tile(Vector2i(10, 4))
	var knife_container_tile_id := workstations.get_cell_alternative_tile(Vector2i(11, 4))
	assert_eq(source.get_scene_tile_scene(container_tile_id), POTATO_CONTAINER_SCENE)
	assert_eq(source.get_scene_tile_scene(board_tile_id), CUTTING_BOARD_SCENE)
	assert_eq(source.get_scene_tile_scene(knife_container_tile_id), KNIFE_CONTAINER_SCENE)
	assert_eq(
		workstations.map_to_local(Vector2i(1, 6)) + workstations.position,
		Vector2(96, 430),
	)
	assert_eq(
		workstations.map_to_local(Vector2i(10, 4)) + workstations.position,
		Vector2(672, 302),
	)
	assert_eq(
		workstations.map_to_local(Vector2i(11, 4)) + workstations.position,
		Vector2(736, 302),
	)


func test_item_transformations_preserve_history_through_authored_outputs() -> void:
	var first := ItemTransformation.new()
	first.Id = &"first"
	first.FallbackMaterial = ShaderMaterial.new()
	var input := PickupItemDefinition.new()
	input.Id = &"input"
	input.DisplayName = "Input"
	var first_result := first.Resolve(input)

	var second := ItemTransformation.new()
	second.Id = &"second"
	var authored_output := PickupItemDefinition.new()
	authored_output.Id = &"authored_output"
	var transformation_override := ItemTransformationOverride.new()
	transformation_override.TransformationId = &"second"
	transformation_override.Output = authored_output
	var overrides: Array[ItemTransformationOverride] = [null, transformation_override]
	first_result.TransformationOverrides = overrides

	var second_result := second.Resolve(first_result)
	var applied_ids: Array[StringName] = second_result.AppliedTransformationIds
	assert_eq(second_result.Id, &"authored_output")
	assert_true(applied_ids.has(&"first"))
	assert_true(applied_ids.has(&"second"))
	assert_false(first.CanApply(second_result))
	assert_false(second.CanApply(second_result))


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
