extends Node3D

@onready var area:Area3D

var base_albedos = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for c in get_all_children(self):
		if(c is Area3D):
			area = c
			
		if(c is MeshInstance3D):
			var count = c.get_surface_override_material_count()
			for i in range(count):
				var mesh_material = c.get_active_material(i).duplicate()
				base_albedos.append(mesh_material.albedo_color)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(get_parent().visible):
		rotation.y += 3.0 * delta


func _on_area_3d_mouse_entered() -> void:
	
	if(get_node("/root/Control").selected_tool != self):	
		for c in get_all_children(self):
			if(c is MeshInstance3D):
					var count = c.get_surface_override_material_count()
					for i in range(count):
						var mesh_material = c.get_active_material(i).duplicate()
						c.set_surface_override_material(i, mesh_material)
						mesh_material.albedo_color = base_albedos[i]*2
					
		get_node("/root/Control").highlighted_object = self	
				
		if(get_node("/root/Control/InteractionButtons").visible):
			return
					
		
	#print(get_parent().name)

func _on_area_3d_mouse_exited() -> void:

	for c in get_all_children(self):
		if(c is MeshInstance3D):
				var count = c.get_surface_override_material_count()
				for i in range(count):
					var mesh_material = c.get_active_material(i).duplicate()
					c.set_surface_override_material(i, mesh_material)
					mesh_material.albedo_color = base_albedos[i]*0.5

					
	if(get_node("/root/Control/InteractionButtons").visible):
		return				
	if(!Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		get_node("/root/Control").highlighted_object = null

	#print(get_parent().highlighted_object)

func get_all_children(node):
	var nodes : Array = []

	for N in node.get_children():

		if N.get_child_count() > 0:

			nodes.append(N)

			nodes.append_array(get_all_children(N))

		else:

			nodes.append(N)

	return nodes	
