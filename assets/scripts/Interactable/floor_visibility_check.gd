extends Node3D

@export var related_objects = []
@export var floor = 0

func _ready() -> void:
	related_objects.append(get_node("/root/Control").burglary_target)

func enable_floor():
	for i in range (get_node("/root/Control").active_burglar.current_floor, get_node("/root/Control").get_node(related_objects[0]).number_of_floors + 1):
		#get_node("/root/Control/"+str(get_node("/root/Control").burglary_target)+"/Inside/Floor"+str(i)).cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_ON
		for c in get_all_children(get_node("/root/Control/"+str(get_node("/root/Control").burglary_target)+"/Inside/Floor"+str(i))):
			if(c.name != "Spotlight"):
				if(c.is_in_group("Interactable")):
					if(c.object_type == 4):
						continue
				c.set_deferred("visible", true)
				
			if(c is CollisionObject3D):
				c.collision_layer = 1
				
		#get_node("/root/Control/NavigationRegion3D/"+get_node("/root/Control").burglary_target.name+"/Floor"+str(i)).process_mode = Node.PROCESS_MODE_ALWAYS
		
		#for c in get_node("/root/Control/NavigationRegion3D/"+related_objects[0]+"/Floor").get_children():
			#c.set_deferred("disabled", false)
			#for ch in c.get_children():
				#ch.set_deferred("disabled", false)
		#
	
func disable_floor():
	if(!(get_node("/root/Control").active_burglar.inside)):
		return
	for i in range (get_node("/root/Control").active_burglar.current_floor + 1, get_node("/root/Control").get_node(str(related_objects[0])).number_of_floors + 1):
		#get_node("/root/Control/NavigationRegion3D/"+get_node("/root/Control").burglary_target.name+"Inside/Floor"+str(i)).cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		for c in get_all_children(get_node("/root/Control/"+str(get_node("/root/Control").burglary_target)+"/Inside/Floor"+str(i))):
			if(c.name != "Spotlight"):
				if(c.is_in_group("Interactable")):
					if(c.object_type == 4):
						continue
				c.set_deferred("visible", false)
		
			if(c is CollisionObject3D):
				c.collision_layer = 2
		
		#get_node("/root/Control/NavigationRegion3D/"+get_node("/root/Control").burglary_target.name+"/Floor"+str(i)).process_mode = Node.PROCESS_MODE_DISABLED
		
		#for c in get_node("/root/Control/NavigationRegion3D/"+related_objects[0]+"/Floor").get_children():
			#for ch in c.get_children():
				#ch.set_deferred("disabled", true)
			#c.set_deferred("disabled", true)
			
		#get_node("/root/Control/NavigationRegion3D/"+related_objects[0]+"/Floor").set_deferred("disabled", true)


func _on_area_3d_area_entered(area: Area3D) -> void:
	change_visibility(area.get_parent(),true)
	
func get_all_children(node):
	var nodes : Array = []

	for N in node.get_children():

		if N.get_child_count() > 0:

			nodes.append(N)

			nodes.append_array(get_all_children(N))

		else:

			nodes.append(N)

	return nodes

func change_visibility(node, set_floor:bool):
	if(node.is_in_group("Actor")):
		if(set_floor):
			node.current_floor = floor
		for actor in get_tree().get_nodes_in_group("Actor"):
			if(true):#actor.is_guard):
				if(actor.current_floor != get_node("/root/Control").active_burglar.current_floor):
					var mesh = actor.get_child(0)
					for c in GlobalFunctions.get_all_children(mesh):
						if(c is MeshInstance3D && c.name != "Plane"):
							for i in range(c.get_surface_override_material_count()):
								var mesh_material = c.get_active_material(i).duplicate()
								c.set_surface_override_material(i, mesh_material)
								mesh_material.transparency = 1
								mesh_material.albedo_color.a = 0
				else:
					var mesh = actor.get_child(0)
					for c in GlobalFunctions.get_all_children(mesh):
						#REMINDME this is questionable and might cause issues later, if any other object should be name "Plane"
						if(c is MeshInstance3D && c.name != "Plane"):
							for i in range(c.get_surface_override_material_count()):
								var mesh_material = c.get_active_material(i).duplicate()
								c.set_surface_override_material(i, mesh_material)
								mesh_material.transparency = 0
								mesh_material.albedo_color.a = 1
		if(node == get_node("/root/Control").active_burglar):
			enable_floor()
			disable_floor()
