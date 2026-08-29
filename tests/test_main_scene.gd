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
const CARROT_CONTAINER_SCENE := preload("res://scenes/carrot_container.tscn")
const KNIFE_CONTAINER_SCENE := preload("res://scenes/knife_container.tscn")
const OVEN_SCENE := preload("res://scenes/oven.tscn")
const EXECUTIONER_SCENE := preload("res://scenes/executioner.tscn")
const NPC_WORKER_SCENE := preload("res://scenes/npc_worker.tscn")
const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const FETCH_TASK := preload("res://resources/tasks/fetch_workstation_item.tres")
const PROCESS_TASK := preload("res://resources/tasks/process_workstation_item.tres")
const CHOP_RECIPE := preload("res://resources/recipes/chop.tres")
const CHOP_TRANSFORMATION := preload("res://resources/transformations/chop.tres")
const POTATO_DEFINITION := preload("res://resources/items/potato.tres")
const CHOPPED_POTATOES_DEFINITION := preload("res://resources/items/chopped_potatoes.tres")
const CARROT_DEFINITION := preload("res://resources/items/carrot.tres")
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
	var game_over_setting: Dictionary = project_config.get_value("input", "game_over", {})
	var game_over_events: Array = game_over_setting.get("events", [])
	assert_true(_has_key_binding(game_over_events, KEY_SPACE))

	var game_over_controller := level.get_node_or_null("GameOverController") as CanvasLayer
	assert_true(game_over_controller != null)
	if game_over_controller != null:
		assert_eq(
			game_over_controller.get_script().resource_path,
			"res://src/GameOverController.cs",
		)
		assert_eq(game_over_controller.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_player_has_composable_interaction_components() -> void:
	var level := track(MAIN_SCENE.instantiate())
	var player := level.get_node("Player") as CharacterBody2D
	var carrier := player.get_node_or_null("PickupCarrier") as Node2D
	var hold_point := player.get_node_or_null("PickupCarrier/HoldPoint") as Node2D
	var interactor := player.get_node_or_null("Interactor") as Node2D
	var input_manager := player.get_node_or_null("InputManager") as Node
	var player_shape := player.get_node("CollisionShape2D").shape as CircleShape2D

	assert_true(carrier != null, "The player must contain a pickup carrier.")
	assert_true(hold_point != null, "The pickup carrier must contain a hold point.")
	assert_true(interactor != null, "The player must contain an interactor.")
	assert_true(input_manager != null, "The player must contain an input manager.")
	assert_true(player_shape != null, "The player must have a circular collision shape.")
	if (
		carrier == null
		or hold_point == null
		or interactor == null
		or input_manager == null
		or player_shape == null
	):
		return

	assert_eq(carrier.get_script().resource_path, "res://src/PickupCarrier.cs")
	assert_true(is_equal_approx(float(carrier.get("PickupDuration")), 0.2))
	assert_true(float(carrier.get("ThrowForce")) > 0.0)
	assert_true(carrier.visible, "The pickup carrier must keep held items visible.")
	assert_true(hold_point.visible, "The hold point must keep held items visible.")
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


func test_executioner_has_the_game_over_animation_contract() -> void:
	var executioner := track(EXECUTIONER_SCENE.instantiate()) as Node2D

	assert_true(executioner != null)
	if executioner == null:
		return

	var sprite := executioner.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	assert_true(sprite != null)
	if sprite == null:
		return

	assert_eq(executioner.get_script().resource_path, "res://src/Executioner.cs")
	assert_eq(sprite.sprite_frames.get_frame_count(&"idle"), 2)
	assert_eq(sprite.sprite_frames.get_frame_count(&"walk"), 2)
	assert_eq(sprite.sprite_frames.get_frame_count(&"takeout"), 5)
	assert_eq(sprite.sprite_frames.get_frame_count(&"chop"), 6)
	assert_true(sprite.sprite_frames.get_animation_loop(&"idle"))
	assert_true(sprite.sprite_frames.get_animation_loop(&"walk"))
	assert_false(sprite.sprite_frames.get_animation_loop(&"takeout"))
	assert_false(sprite.sprite_frames.get_animation_loop(&"chop"))


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


func test_main_scene_composes_scene_scoped_npc_task_system() -> void:
	var level := track(MAIN_SCENE.instantiate())
	var task_system: Node = level.get_node_or_null("TaskSystem")
	var broker: Node = level.get_node_or_null("TaskSystem/TaskBroker")
	var catalog: Node = level.get_node_or_null("TaskSystem/ItemSourceCatalog")
	var navigation_region := level.get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	var worker := level.get_node_or_null("NpcWorker") as CharacterBody2D
	var baby := level.get_node_or_null("BabyPickupItem") as RigidBody2D

	assert_true(task_system != null)
	assert_true(broker != null)
	assert_true(catalog != null)
	assert_true(navigation_region != null)
	assert_true(worker != null)
	assert_true(baby != null)
	if (
		task_system == null
		or broker == null
		or catalog == null
		or navigation_region == null
		or worker == null
		or baby == null
	):
		return

	assert_eq(task_system.get_script().resource_path, "res://src/KitchenTaskSystem.cs")
	assert_eq(broker.get_script().resource_path, "res://src/TaskBroker.cs")
	assert_eq(catalog.get_script().resource_path, "res://src/ItemSourceCatalog.cs")
	assert_true(navigation_region.navigation_polygon != null)
	assert_eq(navigation_region.navigation_polygon.get_outline_count(), 1)
	assert_eq(
		navigation_region.navigation_polygon.get_outline(0),
		PackedVector2Array([
			Vector2(64, 64),
			Vector2(896, 64),
			Vector2(896, 476),
			Vector2(64, 476),
		]),
	)
	assert_eq(worker.scene_file_path, NPC_WORKER_SCENE.resource_path)
	var worker_sprite := worker.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	assert_true(worker_sprite != null)
	if worker_sprite != null:
		assert_eq(worker_sprite.sprite_frames.get_frame_count(&"idle"), 2)
		assert_eq(worker_sprite.sprite_frames.get_frame_count(&"walk"), 2)
		assert_eq(worker_sprite.sprite_frames.get_animation_speed(&"idle"), 2.0)
		assert_eq(worker_sprite.sprite_frames.get_animation_speed(&"walk"), 4.0)
		assert_eq(
			worker_sprite.sprite_frames.get_frame_texture(&"idle", 0).atlas.resource_path,
			"res://assets/sprites/worker/worker.png",
		)
	assert_eq(
		worker.get_node("WorkerVisualController").get_script().resource_path,
		"res://src/WorkerVisualController.cs",
	)
	assert_eq(worker.get_node("NpcMotor").get_script().resource_path, "res://src/NpcMotor.cs")
	assert_eq(
		worker.get_node("NpcTaskRunner").get_script().resource_path,
		"res://src/NpcTaskRunner.cs",
	)
	var personality: Resource = worker.get_node("NpcTaskRunner").get("Personality")
	assert_true(personality != null)
	if personality != null:
		assert_true(is_equal_approx(float(personality.get("FailureChance")), 0.6))
		var tendencies: Array = personality.get("FailureTendencies")
		assert_eq(tendencies.size(), 1)
		if tendencies.size() == 1:
			assert_eq(int(tendencies[0].get("Mode")), 0)
			assert_true(is_equal_approx(float(tendencies[0].get("Weight")), 1.0))
	assert_true(worker.get_node_or_null("NavigationAgent2D") is NavigationAgent2D)
	assert_true(worker.get_node_or_null("PickupCarrier/HoldPoint") is Node2D)
	assert_eq(baby.get_script().resource_path, "res://src/BabyPickupItem.cs")
	assert_eq(baby.get("Definition").get("Id"), &"baby")


func test_customer_composes_wandering_chopped_potato_order() -> void:
	var customer := track(CUSTOMER_SCENE.instantiate()) as CharacterBody2D
	var sprite := customer.get_node_or_null("Sprite2D") as Sprite2D
	var controller := customer.get_node_or_null("CustomerWanderController")
	var publisher := customer.get_node_or_null("WorkstationTaskPublisher")
	var indicator := customer.get_node_or_null("TaskRequestIndicator") as Node2D
	var transfer := customer.get_node_or_null("InteractionTarget/TransferItemAction")

	assert_true(sprite != null)
	assert_true(controller != null)
	assert_true(publisher != null)
	assert_true(indicator != null)
	assert_true(transfer != null)
	if (
		sprite == null
		or controller == null
		or publisher == null
		or indicator == null
		or transfer == null
	):
		return

	assert_eq(sprite.texture.resource_path, "res://assets/sprites/Sprite2.png")
	assert_eq(
		controller.get_script().resource_path,
		"res://src/CustomerWanderController.cs",
	)
	assert_eq(
		controller.get("UprightVisualPath"),
		NodePath("../TaskRequestIndicator"),
	)
	assert_eq(controller.get("UprightVisualOffset"), Vector2(0, -52))
	assert_eq(int(publisher.get("RequestMode")), 0)
	assert_eq(publisher.get("FetchTask"), FETCH_TASK)
	assert_eq(publisher.get("RequestedItem"), CHOPPED_POTATOES_DEFINITION)
	assert_true(bool(publisher.get("ConsumeDeliveredItem")))
	assert_eq(publisher.get("ConsumerVisualPath"), NodePath("../Sprite2D"))
	assert_eq(transfer.get("AcceptedItem"), CHOPPED_POTATOES_DEFINITION)


func test_catalog_matches_transformed_output_by_item_id() -> void:
	var level := track(MAIN_SCENE.instantiate())
	var runner: Node = level.get_node("NpcWorker/NpcTaskRunner")
	runner.process_mode = Node.PROCESS_MODE_DISABLED
	Engine.get_main_loop().root.add_child(level)
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame

	var catalog: Node = level.get_node("TaskSystem/ItemSourceCatalog")
	var socket: Node = level.get_node("Workstations/CuttingBoard/PickupSocket")
	var item: Node = PICKUP_ITEM_SCENE.instantiate()
	level.add_child(item)
	item.set("Definition", POTATO_DEFINITION)

	assert_true(bool(socket.call("TryStore", item, 0.0)))
	assert_true(bool(CHOP_RECIPE.call("Apply", item)))
	socket.call("SetNpcSourceEnabled", true)
	assert_ne(item.get("Definition"), CHOPPED_POTATOES_DEFINITION)
	assert_eq(
		item.get("Definition").get("Id"),
		CHOPPED_POTATOES_DEFINITION.get("Id"),
	)
	assert_true(
		bool(
			catalog.call(
				"HasAvailableSource",
				CHOPPED_POTATOES_DEFINITION,
				runner,
			)
		),
		"Transformed output must satisfy a task requesting the same item ID.",
	)


func test_workstations_are_excluded_from_npc_navigation() -> void:
	var level := track(MAIN_SCENE.instantiate())
	var workstations := level.get_node_or_null("Workstations") as TileMapLayer
	var navigation_region := level.get_node_or_null("NavigationRegion2D") as NavigationRegion2D

	assert_true(workstations != null)
	assert_true(navigation_region != null)
	if workstations == null or navigation_region == null:
		return

	var navigation_polygon := navigation_region.navigation_polygon
	assert_true(navigation_polygon != null)
	if navigation_polygon == null:
		return

	assert_true(workstations.is_in_group(&"workstation_navigation_source"))
	assert_eq(
		navigation_polygon.source_geometry_mode,
		NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN,
	)
	assert_eq(
		navigation_polygon.source_geometry_group_name,
		&"workstation_navigation_source",
	)
	assert_eq(
		navigation_polygon.parsed_geometry_type,
		NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS,
	)
	assert_eq(navigation_polygon.parsed_collision_mask, 1)
	assert_eq(navigation_polygon.agent_radius, 20.0)
	assert_eq(navigation_polygon.get_outline_count(), 1)
	assert_true(navigation_polygon.get_polygon_count() > 1)

	var navigation_vertices := navigation_polygon.get_vertices()
	for cell in workstations.get_used_cells():
		var workstation_center := workstations.position + workstations.map_to_local(cell)
		var center_is_navigable := false
		for polygon_index in navigation_polygon.get_polygon_count():
			var polygon_vertices := PackedVector2Array()
			for vertex_index in navigation_polygon.get_polygon(polygon_index):
				polygon_vertices.append(navigation_vertices[vertex_index])
			if Geometry2D.is_point_in_polygon(workstation_center, polygon_vertices):
				center_is_navigable = true
				break
		assert_false(
			center_is_navigable,
			"Workstation at %s must be excluded from navigation." % cell,
		)


func test_workstation_and_sources_expose_npc_task_contracts() -> void:
	var board := track(CUTTING_BOARD_SCENE.instantiate()) as StaticBody2D
	var potato_source := track(POTATO_CONTAINER_SCENE.instantiate()) as StaticBody2D
	var knife_source := track(KNIFE_CONTAINER_SCENE.instantiate()) as StaticBody2D
	var publisher := board.get_node_or_null("WorkstationTaskPublisher") as Node2D
	var potato_item_source := potato_source.get_node_or_null("NpcItemSource") as Node2D
	var knife_item_source := knife_source.get_node_or_null("NpcItemSource") as Node2D

	assert_true(publisher != null)
	assert_true(potato_item_source != null)
	assert_true(knife_item_source != null)
	if publisher == null or potato_item_source == null or knife_item_source == null:
		return

	assert_eq(
		publisher.get_script().resource_path,
		"res://src/WorkstationTaskPublisher.cs",
	)
	assert_eq(publisher.get("FetchTask"), FETCH_TASK)
	assert_eq(publisher.get("ActionTask"), PROCESS_TASK)
	assert_eq(publisher.get("RequestedItem"), POTATO_DEFINITION)
	assert_eq(FETCH_TASK.get("Kind"), 0)
	assert_eq(PROCESS_TASK.get("Kind"), 1)
	assert_eq(FETCH_TASK.get("RequiredTags"), [&"kitchen"])
	assert_eq(PROCESS_TASK.get("RequiredTags"), [&"kitchen"])
	var fetch_failures: Array = FETCH_TASK.get("FailureOptions")
	var process_failures: Array = PROCESS_TASK.get("FailureOptions")
	assert_eq(fetch_failures.size(), 1)
	if fetch_failures.size() == 1:
		assert_eq(int(fetch_failures[0].get("Mode")), 0)
	assert_true(
		process_failures.is_empty(),
		"Processing must not permit nonsensical wrong-tool failures.",
	)
	assert_eq(potato_item_source.get("ItemDefinition"), POTATO_DEFINITION)
	assert_eq(knife_item_source.get("ItemDefinition"), KNIFE_DEFINITION)
	assert_eq(potato_item_source.position, Vector2(64, 0))
	assert_eq(knife_item_source.position, Vector2(0, 64))


func test_cutting_board_composes_transfer_process_and_socket() -> void:
	var board := track(CUTTING_BOARD_SCENE.instantiate()) as StaticBody2D
	var socket := board.get_node_or_null("PickupSocket")
	var target := board.get_node_or_null("InteractionTarget") as Area2D

	assert_true(socket != null)
	assert_true(target != null)
	if socket == null or target == null:
		return

	assert_eq(socket.get_script().resource_path, "res://src/PickupSocket.cs")
	assert_eq(socket.get("NpcApproachOffset"), Vector2(0, 72))
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
	var request := target.get_node("RequestTaskAction")
	assert_eq(request.get_script().resource_path, "res://src/RequestWorkstationTaskAction.cs")
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


func test_oven_composes_automatic_cooking_workstation() -> void:
	var oven := track(OVEN_SCENE.instantiate()) as StaticBody2D
	assert_true(oven != null)
	if oven == null:
		return

	assert_eq(oven.collision_layer, 1)
	assert_eq(oven.collision_mask, 0)
	var sprite := oven.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	assert_true(sprite != null)
	if sprite != null:
		assert_eq(sprite.animation, &"idle")
		assert_eq(sprite.sprite_frames.get_frame_count(&"idle"), 1)
		assert_eq(sprite.sprite_frames.get_frame_count(&"cooking"), 2)
		assert_eq(sprite.sprite_frames.get_animation_speed(&"cooking"), 3.0)
		var cooking_frame := sprite.sprite_frames.get_frame_texture(&"cooking", 0) as AtlasTexture
		assert_true(cooking_frame != null)
		if cooking_frame != null:
			assert_eq(cooking_frame.atlas.resource_path, "res://assets/sprites/oven/oven-Sheet.png")
			assert_eq(cooking_frame.region, Rect2(64, 0, 64, 128))

	var socket := oven.get_node_or_null("PickupSocket") as Node2D
	var transfer := oven.get_node_or_null("InteractionTarget/TransferItemAction") as Node
	var controller := oven.get_node_or_null("OvenCookingController") as Node
	assert_true(socket != null)
	assert_true(transfer != null)
	assert_true(controller != null)
	if transfer != null:
		assert_eq(transfer.get_script().resource_path, "res://src/SlotTransferAction.cs")
		assert_eq(transfer.get("SocketPath"), NodePath("../../PickupSocket"))
	if controller != null:
		assert_eq(controller.get_script().resource_path, "res://src/OvenCookingController.cs")
		var cook_recipe := controller.get("Recipe") as Resource
		assert_true(cook_recipe != null)
		if cook_recipe != null:
			assert_eq(cook_recipe.resource_path, "res://resources/recipes/cook.tres")
			assert_eq(float(cook_recipe.get("Duration")), 10.0)
			assert_eq(cook_recipe.get("RequiredTool"), null)
			var cook_transformation := cook_recipe.get("Transformation") as Resource
			assert_true(cook_transformation != null)
			if cook_transformation != null:
				assert_eq(cook_transformation.get("Id"), &"cook")
				assert_eq(
					cook_transformation.get("FallbackMaterial").resource_path,
					"res://resources/materials/cooked_brown_black.tres",
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


func test_carrot_container_supplies_the_carrot_scene() -> void:
	var container := track(CARROT_CONTAINER_SCENE.instantiate()) as StaticBody2D

	assert_true(container != null)
	if container == null:
		return

	var texture := container.get_node("Sprite2D").texture as Texture2D
	assert_true(texture != null)
	if texture != null:
		assert_eq(texture.resource_path, "res://assets/sprites/carrot_container/carrot_container.png")
	var action := container.get_node("InteractionTarget/PickupContainerAction")
	assert_eq(action.get("PickupScene").resource_path, "res://scenes/carrot_item.tscn")
	assert_eq(action.get("AcceptedItem"), CARROT_DEFINITION)
	assert_eq(container.get_node("NpcItemSource").get("ItemDefinition"), CARROT_DEFINITION)


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

	assert_eq(source.get_scene_tiles_count(), 4)
	assert_eq(workstations.get_cell_atlas_coords(Vector2i(1, 6)), Vector2i.ZERO)
	assert_eq(workstations.get_cell_atlas_coords(Vector2i(10, 4)), Vector2i.ZERO)
	assert_eq(workstations.get_cell_atlas_coords(Vector2i(11, 4)), Vector2i.ZERO)
	var container_tile_id := workstations.get_cell_alternative_tile(Vector2i(1, 6))
	var board_tile_id := workstations.get_cell_alternative_tile(Vector2i(10, 4))
	var knife_container_tile_id := workstations.get_cell_alternative_tile(Vector2i(11, 4))
	assert_eq(source.get_scene_tile_scene(container_tile_id), POTATO_CONTAINER_SCENE)
	assert_eq(source.get_scene_tile_scene(board_tile_id), CUTTING_BOARD_SCENE)
	assert_eq(source.get_scene_tile_scene(knife_container_tile_id), KNIFE_CONTAINER_SCENE)
	assert_eq(source.get_scene_tile_scene(3), CARROT_CONTAINER_SCENE)
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
	var carrot_container := level.get_node_or_null("CarrotContainer") as StaticBody2D
	assert_true(carrot_container != null)
	if carrot_container != null:
		assert_eq(carrot_container.position, Vector2(96, 302))
		assert_eq(
			carrot_container.get_node("InteractionTarget/PickupContainerAction").get("AcceptedItem"),
			CARROT_DEFINITION,
		)
	var oven := level.get_node_or_null("Oven") as StaticBody2D
	assert_true(oven != null)
	if oven != null:
		assert_eq(oven.position, Vector2(800, 302))


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
