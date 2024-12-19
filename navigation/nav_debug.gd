extends Node2D

@export var show_navigation: bool = true
@export var draw_color: Color = Color(0.2, 0.8, 0.2, 0.3)

func _draw():
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
			var polygon = nav_poly.get_polygon(i)
			draw_colored_polygon(polygon, draw_color)

func _process(_delta):
	queue_redraw()
