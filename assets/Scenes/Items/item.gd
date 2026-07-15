extends Node3D

@onready var area:Area3D

var base_albedos = []
@onready var base_rotation = global_rotation
@onready var current_rotation = 0.0

var speed = 1.25

@export_enum("Tool", "Loot", "other") var item_type

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for c in get_all_children(self):
		if(c is Area3D):
			area = c
			
		if(c is MeshInstance3D):
			var count = c.get_surface_override_material_count()
			for i in range(count):
				var mesh_material = c.get_active_material(i).duplicate()
				c.set_surface_override_material(i, mesh_material)
				mesh_material.disable_receive_shadows = true
				base_albedos.append(mesh_material.albedo_color)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#if(get_parent().visible):
	#global_rotation = get_node("/root/Control")._camera.global_rotation
	if(visible):
		current_rotation -= delta * speed
		if(get_node("/root/Control").selected_tool != self):
			rotation.y = current_rotation
		else:
			global_rotation = get_node("/root/Control")._camera.global_rotation
			rotate_object_local(Vector3.UP, current_rotation)


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
					mesh_material.albedo_color = base_albedos[i]

					
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
