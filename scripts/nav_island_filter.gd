@tool
extends RefCounted
## Deterministic post-bake navigation geometry utility.
##
## Godot's source-geometry bake produces every geometrically valid polygon
## island inside the outer source bounds, including disconnected components
## that sit inside enclosed collision obstacles (e.g. a table interior). Those
## islands are unreachable at runtime but still pollute the stored
## NavigationPolygon. This helper detects and removes such islands by keeping
## only the connected components reachable from known walkable seed points.
##
## Pure and idempotent: filtering already-clean geometry is a no-op, and running
## it twice yields the same result, so rebakes stay deterministic.

## Builds polygon adjacency from shared undirected edges and returns the list of
## connected components as arrays of polygon indices.
static func compute_components(polygons: Array) -> Array:
	var edge_to_polys := {}
	for pi in range(polygons.size()):
		var poly: PackedInt32Array = polygons[pi]
		var n := poly.size()
		for k in range(n):
			var a := poly[k]
			var b := poly[(k + 1) % n]
			var key := Vector2i(min(a, b), max(a, b))
			if not edge_to_polys.has(key):
				edge_to_polys[key] = []
			edge_to_polys[key].append(pi)
	var adjacency := {}
	for pi in range(polygons.size()):
		adjacency[pi] = {}
	for key in edge_to_polys:
		var shared: Array = edge_to_polys[key]
		for i in range(shared.size()):
			for j in range(i + 1, shared.size()):
				adjacency[shared[i]][shared[j]] = true
				adjacency[shared[j]][shared[i]] = true
	var seen := {}
	var components := []
	for start in range(polygons.size()):
		if seen.has(start):
			continue
		var stack := [start]
		seen[start] = true
		var comp := []
		while not stack.is_empty():
			var cur = stack.pop_back()
			comp.append(cur)
			for nb in adjacency[cur]:
				if not seen.has(nb):
					seen[nb] = true
					stack.append(nb)
		components.append(comp)
	return components

## Number of connected components in the polygon set.
static func count_components(polygons: Array) -> int:
	return compute_components(polygons).size()

## Standard even-odd point-in-polygon test.
static func point_in_polygon(p: Vector2, pts: PackedVector2Array) -> bool:
	var inside := false
	var n := pts.size()
	var j := n - 1
	for i in range(n):
		var pi := pts[i]
		var pj := pts[j]
		if ((pi.y > p.y) != (pj.y > p.y)) and \
				(p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside

## Whether a point lies inside any polygon of the geometry.
static func is_navigable(point: Vector2, vertices: PackedVector2Array, polygons: Array) -> bool:
	for poly in polygons:
		var pts := PackedVector2Array()
		for idx in poly:
			pts.append(vertices[idx])
		if point_in_polygon(point, pts):
			return true
	return false

## Returns filtered {"vertices", "polygons"} keeping only components that contain
## at least one of the reachable seed points. Vertices are compacted and
## reindexed. When every component is reachable the geometry is returned
## unchanged (aside from index compaction, which is a no-op if already dense).
static func filter_to_reachable(vertices: PackedVector2Array, polygons: Array, seeds: PackedVector2Array) -> Dictionary:
	var components := compute_components(polygons)
	var kept_flags := {}
	for comp in components:
		var reachable := false
		for pi in comp:
			var pts := PackedVector2Array()
			for idx in polygons[pi]:
				pts.append(vertices[idx])
			for seed in seeds:
				if point_in_polygon(seed, pts):
					reachable = true
					break
			if reachable:
				break
		if reachable:
			for pi in comp:
				kept_flags[pi] = true
	var kept_polys := []
	for pi in range(polygons.size()):
		if kept_flags.has(pi):
			kept_polys.append(polygons[pi])
	var used := []
	var used_set := {}
	for poly in kept_polys:
		for idx in poly:
			if not used_set.has(idx):
				used_set[idx] = true
				used.append(idx)
	used.sort()
	var remap := {}
	var new_vertices := PackedVector2Array()
	for new_idx in range(used.size()):
		var old_idx: int = used[new_idx]
		remap[old_idx] = new_idx
		new_vertices.append(vertices[old_idx])
	var new_polygons := []
	for poly in kept_polys:
		var np := PackedInt32Array()
		for idx in poly:
			np.append(remap[idx])
		new_polygons.append(np)
	return {"vertices": new_vertices, "polygons": new_polygons}

## Convenience: read a NavigationPolygon's polygons into a plain Array.
static func polygons_of(nav_poly: NavigationPolygon) -> Array:
	var result := []
	for i in range(nav_poly.get_polygon_count()):
		result.append(nav_poly.get_polygon(i))
	return result
