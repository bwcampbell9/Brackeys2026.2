@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

const NavIslandFilter := preload("res://scripts/nav_island_filter.gd")

const LEVEL_SCENES := [
	preload("res://scenes/level_1.tscn"),
	preload("res://scenes/level_2.tscn"),
]
const NAVIGATION_SOURCE_GROUP := &"workstation_navigation_source"
const REQUIRED_TILE_LAYERS := [
	"RoomTiles",
	"Rug",
	"Table_Chairs",
	"collision_hack",
	"Workstations",
]
const KITCHEN_REGION_PATH := "NavigationRegion2D"

# Side-table map cells and the Table_Chairs atlas source/tiles they reference.
# Collision for these tiles must live in the reusable TileSet source, not in a
# per-scene collision_hack exception.
const SIDE_TABLE_SOURCE_ID := 4
const SIDE_TABLE_CELLS := [
	Vector2i(0, 11),
	Vector2i(0, 13),
	Vector2i(13, 11),
	Vector2i(13, 13),
]
const SIDE_TABLE_ATLAS := [
	Vector2i(14, 10),
	Vector2i(15, 10),
]

# Deterministic probe points in navigation-region-local space.
const REACHABLE_FLOOR := [Vector2(448, 300), Vector2(448, 620)]
const TABLE_INTERIOR := [Vector2(448, 780), Vector2(300, 760), Vector2(600, 760)]
# The disconnected bake island that used to pollute Level 1's kitchen navmesh.
const LEVEL_1_FORMER_ISLAND := Vector2(672, 296)


func suite_name() -> String:
	return "level_navigation"


func _kitchen_geometry(level: Node) -> Dictionary:
	var region := level.get_node_or_null(KITCHEN_REGION_PATH) as NavigationRegion2D
	assert_true(region != null, "%s must expose kitchen %s." % [level.name, KITCHEN_REGION_PATH])
	if region == null:
		return {}
	var nav_poly := region.navigation_polygon
	assert_true(nav_poly != null, "%s kitchen region must have a baked NavigationPolygon." % level.name)
	if nav_poly == null:
		return {}
	return {
		"vertices": nav_poly.get_vertices(),
		"polygons": NavIslandFilter.polygons_of(nav_poly),
	}


func test_every_tilemap_layer_contributes_to_navigation() -> void:
	for packed_scene: PackedScene in LEVEL_SCENES:
		var level := track(packed_scene.instantiate())
		for layer_name: String in REQUIRED_TILE_LAYERS:
			var layer := level.get_node_or_null(layer_name) as TileMapLayer
			assert_true(layer != null, "%s must contain %s." % [level.name, layer_name])
			if layer != null:
				assert_true(
					layer.is_in_group(NAVIGATION_SOURCE_GROUP),
					"%s/%s must contribute to the navigation bake."
					% [level.name, layer_name],
				)


func test_navigation_regions_do_not_hide_their_npcs() -> void:
	for packed_scene: PackedScene in LEVEL_SCENES:
		var level := track(packed_scene.instantiate())
		for region_path: String in [
			"NavigationRegion2D",
			"CustomersNavigationRegion2D",
		]:
			var region := level.get_node_or_null(region_path) as NavigationRegion2D
			assert_true(region != null, "%s must contain %s." % [level.name, region_path])
			if region != null:
				assert_true(
					region.visible,
					"%s/%s must remain visible so its NPC children render."
					% [level.name, region_path],
				)


func test_side_tables_carry_reusable_tileset_collision() -> void:
	for packed_scene: PackedScene in LEVEL_SCENES:
		var level := track(packed_scene.instantiate())
		var layer := level.get_node_or_null("Table_Chairs") as TileMapLayer
		assert_true(layer != null, "%s must contain Table_Chairs." % level.name)
		if layer == null:
			continue
		var tile_set := layer.tile_set
		assert_true(tile_set != null, "%s Table_Chairs must use a TileSet." % level.name)
		if tile_set == null:
			continue
		var source := tile_set.get_source(SIDE_TABLE_SOURCE_ID) as TileSetAtlasSource
		assert_true(source != null, "TileSet must expose side-table atlas source %d." % SIDE_TABLE_SOURCE_ID)
		if source == null:
			continue
		# Reusable collision must be authored on the shared atlas tiles.
		for atlas: Vector2i in SIDE_TABLE_ATLAS:
			var tile_data := source.get_tile_data(atlas, 0)
			assert_true(tile_data != null, "Side-table tile %s must exist in the atlas." % atlas)
			if tile_data != null:
				assert_gt(
					tile_data.get_collision_polygons_count(0),
					0,
					"Side-table tile %s must carry TileSet collision (not a collision_hack exception)." % atlas,
				)
		# The side-table cells must reference those reusable atlas tiles.
		for cell: Vector2i in SIDE_TABLE_CELLS:
			assert_eq(
				layer.get_cell_source_id(cell),
				SIDE_TABLE_SOURCE_ID,
				"%s side-table cell %s must use the shared atlas source." % [level.name, cell],
			)
			assert_contains(
				SIDE_TABLE_ATLAS,
				layer.get_cell_atlas_coords(cell),
				"%s side-table cell %s must reference a side-table tile." % [level.name, cell],
			)


func test_kitchen_navmesh_has_no_disconnected_island() -> void:
	for packed_scene: PackedScene in LEVEL_SCENES:
		var level := track(packed_scene.instantiate())
		var geometry := _kitchen_geometry(level)
		if geometry.is_empty():
			continue
		assert_eq(
			NavIslandFilter.count_components(geometry["polygons"]),
			1,
			"%s kitchen navmesh must be a single connected component (no unreachable island)." % level.name,
		)


func test_table_interior_is_not_navigable() -> void:
	for packed_scene: PackedScene in LEVEL_SCENES:
		var level := track(packed_scene.instantiate())
		var geometry := _kitchen_geometry(level)
		if geometry.is_empty():
			continue
		for point: Vector2 in TABLE_INTERIOR:
			assert_false(
				NavIslandFilter.is_navigable(point, geometry["vertices"], geometry["polygons"]),
				"%s must not have navmesh inside the enclosed table at %s." % [level.name, point],
			)
		if level.scene_file_path.ends_with("level_1.tscn"):
			assert_false(
				NavIslandFilter.is_navigable(
					LEVEL_1_FORMER_ISLAND, geometry["vertices"], geometry["polygons"]
				),
				"Level 1 must not restore the disconnected counter island at %s." % LEVEL_1_FORMER_ISLAND,
			)


func test_reachable_floor_remains_navigable() -> void:
	for packed_scene: PackedScene in LEVEL_SCENES:
		var level := track(packed_scene.instantiate())
		var geometry := _kitchen_geometry(level)
		if geometry.is_empty():
			continue
		for point: Vector2 in REACHABLE_FLOOR:
			assert_true(
				NavIslandFilter.is_navigable(point, geometry["vertices"], geometry["polygons"]),
				"%s reachable floor at %s must stay navigable." % [level.name, point],
			)


func test_representative_layer_obstacles_are_carved() -> void:
	for packed_scene: PackedScene in LEVEL_SCENES:
		var level := track(packed_scene.instantiate())
		var region := level.get_node_or_null(KITCHEN_REGION_PATH) as NavigationRegion2D
		var geometry := _kitchen_geometry(level)
		if region == null or geometry.is_empty():
			continue
		# Side tables (Table_Chairs source-4 obstacles) must be carved out.
		var table_layer := level.get_node_or_null("Table_Chairs") as TileMapLayer
		for cell: Vector2i in SIDE_TABLE_CELLS:
			var world := table_layer.to_global(table_layer.map_to_local(cell))
			var local: Vector2 = region.to_local(world)
			assert_false(
				NavIslandFilter.is_navigable(local, geometry["vertices"], geometry["polygons"]),
				"%s side-table obstacle at cell %s must be carved from the navmesh." % [level.name, cell],
			)
		# Every Workstations obstacle cell must be carved out.
		var workstations := level.get_node_or_null("Workstations") as TileMapLayer
		var carved := 0
		var total := 0
		for cell: Vector2i in workstations.get_used_cells():
			total += 1
			var world := workstations.to_global(workstations.map_to_local(cell))
			var local: Vector2 = region.to_local(world)
			if not NavIslandFilter.is_navigable(local, geometry["vertices"], geometry["polygons"]):
				carved += 1
		assert_eq(
			carved,
			total,
			"%s: all %d Workstations obstacle cells must be carved from the navmesh." % [level.name, total],
		)
