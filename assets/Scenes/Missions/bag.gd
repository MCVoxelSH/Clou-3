extends SubViewportContainer

var shown = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	size = Vector2(2560, 1440)
	mouse_filter =  MOUSE_FILTER_IGNORE



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_released():

		if(get_node("/root/Control").highlighted_object != null):
			if(get_node("/root/Control").highlighted_object.is_in_group("Item")):
				if(get_node("/root/Control").selected_tool != get_node("/root/Control").highlighted_object):
					get_node("/root/Control").selected_tool = get_node("/root/Control").highlighted_object
					get_node("/root/Control").highlighted_object = null
					get_node("/root/Control")._on_bag_button_up()
					get_node("/root/Control").active_burglar.bag.shown = false
					#get_node("/root/Control").selected_tool._on_area_3d_mouse_exited()
					get_node("/root/Control").selected_tool.area.process_mode = ProcessMode.PROCESS_MODE_DISABLED
					return
					#selected_tool.area.mouse_entered.disconnect(selected_tool._on_mouse_entered)
			elif(get_node("/root/Control").highlighted_object.is_in_group("burglar_in_burglar_switcher")):
				var index = 0
				for child in get_node("/root/Control").burglar_switcher.get_child(0).get_child(0).get_children():
					if(child == get_node("/root/Control").highlighted_object):
						get_node("/root/Control").switch_to_actor(index)
						get_node("/root/Control")._on_burglar_switcher_button_up()
						get_node("/root/Control").highlighted_object = null
						return
					index += 1			
