extends Node3D

@onready var spotlight = $Spotlight
@onready var area = $Spotlight/Area3D
var anim_player:AnimationPlayer

@export var range = 50.0

@export_enum("Door", "Window", "Switch", "Container","Loot","other", "Car", "CameraOrLaser", "Alarm") var object_type

var camera_pos_node:Node3D

var base_albedos: Array = []

var base_rotation_y:float

var objects_in_sight_of_camera:Array

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	camera_pos_node = $CameraPosNode
	base_rotation_y = rotation_degrees.y
	
	for c in get_children():
		if(c is AnimationPlayer):
			anim_player = c
			anim_player.current_animation = "Take 001"
			break
	
	for c in GlobalFunctions.get_all_children(self):
		if(c is MeshInstance3D):
			var array = []
			var count = c.get_surface_override_material_count()
			for i in range(count):
				var mesh_material = c.get_active_material(i).duplicate()
				array.append(mesh_material.albedo_color)
			base_albedos.append(array)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_area_entered(area: Area3D) -> void:
	
	
	if(objects_in_sight_of_camera.find(area.get_parent())== -1 && (area.get_parent().is_in_group("Interactable")|| area.get_parent().is_in_group("Actor"))): #|| body_area.get_parent().is_in_group("Actor"))):
		objects_in_sight_of_camera.append(area.get_parent())
	
	if(area.get_parent().is_in_group("Actor") && !get_node("/root/Control/").backwards):
		if(!area.get_parent().is_guard):
			var space_state = get_world_3d().direct_space_state
								
			var query = PhysicsRayQueryParameters3D.create(spotlight.global_position,area.global_position)
			#query.collision_mask = guard_sight_check_collision_mask
			query.collide_with_areas = true
			query.exclude = [self.area]
			
			var result = space_state.intersect_ray(query)#actor.ray.get_collider()	
			if(result):
				if(result.collider.get_parent().is_in_group("Actor")):
					get_node("/root/Control").print_caught_message(area.get_parent().name + " caught at " +str(get_node("/root/Control/").ticks) + " by " + name)
	
 
func _on_area_3d_area_exited(area):
	#if(!get_node("/root/Control").backwards):
	var index = objects_in_sight_of_camera.find(area.get_parent())
	if(index != -1):
		objects_in_sight_of_camera.remove_at(index)

func _physics_process(delta: float) -> void:
	
	if(anim_player):
		#anim_player.seek(float(get_node("/root/Control").ticks % int(anim_player.current_animation_length * 60)) / 60.0, true)
		rotation_degrees.y =  base_rotation_y + acos(sin(get_node("/root/Control").ticks /range))/(PI/2.0) * range
		
	if(!get_node("/root/Control").backwards):
		
		for object in objects_in_sight_of_camera:
			if(object.get_parent().is_in_group("Actor") && !get_node("/root/Control/").backwards):
				if(!object.get_parent().is_guard):
					var space_state = get_world_3d().direct_space_state
										
					var query = PhysicsRayQueryParameters3D.create(spotlight.global_position,object.global_position)
					#query.collision_mask = guard_sight_check_collision_mask
					query.collide_with_areas = true
					query.exclude = [self.area]
					
					var result = space_state.intersect_ray(query)#actor.ray.get_collider()	
					if(result):
						if(result.collider.get_parent().is_in_group("Actor")):
							get_node("/root/Control").print_caught_message(object.get_parent().name + " caught at " +str(get_node("/root/Control/").ticks) + " by " + name)
		
func toggle_power_state() -> void:
	if(area.process_mode == Node.PROCESS_MODE_DISABLED):
		turn_on_power()
	else:
		turn_off_power()

func turn_on_power() -> void:
	area.process_mode = Node.PROCESS_MODE_INHERIT
	spotlight.visible = true	
	
func turn_off_power() -> void:
	area.process_mode = Node.PROCESS_MODE_DISABLED
	spotlight.visible = false	
