@tool

var _my_button_pressed = false

@export_tool_button("Redraw line") var redraw_line_tool_button = _my_button_pressed

func create_bounding_box():
	pass
	
func _bounding_box(node : Node) -> AABB:
	var ab : AABB = AABB()
	if node is VisualInstance3D:
		ab = node.get_aabb()
		
	for child in node.get_children():
		var cb = _bounding_box(child)
		ab = ab.merge(cb)
		
	return node.transform * ab
