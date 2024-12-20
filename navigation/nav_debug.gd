extends Node2D
@export var show_navigation: bool = true
@export var draw_color: Color = Color(0.2, 0.8, 0.2, 0.3)

func _draw() -> void:
	if not show_navigation:
		return

	# Get all navigation polygons
	var nav_polys = []
	for child in get_tree().get_nodes_in_group("navigation"):
		if child is NavigationRegion2D:
			var nav_poly = child.navigation_polygon
			if nav_poly:
				nav_polys.append(nav_poly)

	# Draw each navigation polygon
	for nav_poly in nav_polys:
		for i in nav_poly.get_polygon_count():
			var vertices = nav_poly.get_vertices()
			var polygon = nav_poly.get_polygon(i)

			# Convert polygon indices to Vector2 points
			var points = PackedVector2Array()
			for idx in polygon:
				if idx < vertices.size():
					points.push_back(vertices[idx])

			if points.size() >= 3:  # Need at least 3 points for a polygon
				draw_colored_polygon(points, draw_color)

				# Optionally draw outline for better visibility
				for j in points.size():
					var start = points[j]
					var end = points[(j + 1) % points.size()]
					draw_line(start, end, draw_color.darkened(0.3), 2.0)

func _process(_delta: float) -> void:
	queue_redraw()

# Optional: Add these helper methods for debugging
func dump_navigation_info() -> void:
	print("\n=== Navigation Debug Info ===")
	var nav_regions = get_tree().get_nodes_in_group("navigation")
	print("Found %d navigation regions" % nav_regions.size())

	for region in nav_regions:
		if region is NavigationRegion2D:
			var nav_poly = region.navigation_polygon
			if nav_poly:
				print("\nNavigation Polygon Info:")
				print("- Vertex count: ", nav_poly.get_vertices().size())
				print("- Polygon count: ", nav_poly.get_polygon_count())
				print("- Outline count: ", nav_poly.get_outline_count())

				# Check navigation map
				var map_rid = region.get_navigation_map()
				print("\nNavigation Map Info:")
				print("- Map RID valid: ", map_rid.is_valid())
				print("- Map active: ", NavigationServer2D.map_is_active(map_rid))
			else:
				print("Region has no navigation polygon!")

func test_paths() -> void:
	var nav_region = get_tree().get_first_node_in_group("navigation") as NavigationRegion2D
	if not nav_region:
		print("No navigation region found!")
		return

	var map_rid = nav_region.get_navigation_map()
	var viewport_rect = get_viewport_rect()
	var center = viewport_rect.size / 2

	print("\n=== Path Testing ===")
	var test_points = [
		Vector2(100, 100),
		center + Vector2(100, 0),
		center + Vector2(0, 100),
		center - Vector2(100, 100)
	]

	for end_point in test_points:
		var path = NavigationServer2D.map_get_path(
			map_rid,
			center,
			end_point,
			true
		)
		print("\nTesting path to ", end_point)
		print("- Path exists: ", path.size() > 0)
		print("- Path length: ", path.size())
