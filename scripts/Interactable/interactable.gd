#FIXME scrubbing forwards and backwards during animation doesn't work correctly, the playback direction is not the right one

extends Node3D

@export var is_breakable = false

@export_enum("Lock", "Safe", "Alarm", "none") var lock_type
@export_enum("Door", "Window", "Switch", "Container","Loot","other", "Car") var object_type
@export_enum("Wood", "Metal", "Glass") var object_material

@export var damage = 0

#I object was damaged by a damaging tool
var damaged = false

var anim_player
var current_time_in_anim = 0.0

var door_closed_at_ticks = []

var append = false

var close_door = false

var index = -1

var previous_animation_position = 0.0

var previous_animation_dir = 0.0

@export var flip_axis = false

@export var related_object:Node3D

var previous_animation_speed = 1.0



var opening_time:int = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	if(object_type != 4 && object_type != 5  && object_type != 6):
		anim_player = $AnimationPlayer
		anim_player.set_auto_capture(false)
		#REMINDER update animation only in physics step 
		anim_player.callback_mode_process = 2
		#anim_player.callback_mode_method = 1
		
		anim_player.current_animation = "Action"
		#do I need to make this longer like before (add a factor like 1.1 to it?)
		#FIXME for less physics ticks this results in less opening_time which makes no sense, I kinda fixed this with the constant 60.0
		opening_time = ceil(anim_player.current_animation_length * 60.0) #* Engine.physics_ticks_per_second)
		anim_player.pause()
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	
	#if(damage == 0):
		#damaged = false
	

	if(anim_player):
		
		if(anim_player.is_playing()):
			if(get_parent().get_parent().backwards):
				anim_player.advance(1.0/60.0)
				#REMINDER this fixes an issue, but maybe it causes others
				if(anim_player.current_animation_position == anim_player.current_animation_length):
					anim_player.pause()
			else:
				anim_player.advance(1.0/60.0)
			#print(str(get_parent().get_parent().ticks) + ", " + str(anim_player.current_animation_position) + ", " + str(get_parent().get_parent().backwards)+ ", " + str(anim_player.get_playing_speed()))
			
	
		
		if(anim_player.current_animation_position != 0.0):
			if(related_object && (object_type == 0 || object_type == 1)):
				disable_floor()
		
		if(anim_player.current_animation_position == 0.0 && previous_animation_position != 0):
			if(!get_node("/root/Control").active_burglar.inside):
				if(related_object && (object_type == 0 || object_type == 1)):
					enable_floor()
			close_door = false
		if(close_door && ! get_parent().get_parent().pause):
			anim_player.play_backwards("Action")
			close_door = false
			
		#anim_player.speed_scale = Engine.time_scale
		if(!get_parent().get_parent().pause):
			#REMINDER think about the addition of *actual_timescale here
			previous_animation_dir = (anim_player.current_animation_position - previous_animation_position)*get_node("/root/Control").actual_timescale #get_parent().get_parent().actual_timescale  * anim_player.get_playing_speed()
	if(anim_player && (object_type == 0 ||  object_type == 1)):
		if(is_breakable && anim_player.current_animation_position == anim_player.current_animation_length && !get_parent().get_parent().pause):
			var min_distance= INF
			for actor in get_tree().get_nodes_in_group("Actor"):
				if(!actor.is_guard):
					if (global_position.distance_squared_to(actor.global_position) < min_distance):
						min_distance = global_position.distance_squared_to(actor.global_position)
			
			if(min_distance > 10 && is_breakable && (get_parent().get_parent().burglar_moved || get_parent().get_parent().play || get_parent().get_parent().load_replay || get_parent().get_parent().forwards|| get_parent().get_parent().active_burglar.is_opening) && !get_parent().get_parent().backwards && !get_parent().get_parent().was_backwards && !get_parent().get_parent().pause):
				close_door = true
				append = true
				
	if(anim_player && (object_type == 0 ||  object_type == 1)):	
		if(previous_animation_position != 0.0 && anim_player.current_animation_position == 0.0  && !get_parent().get_parent().pause && !get_parent().get_parent().backwards && append):
			append_door_opening("backwards")
			append = false
			
	if(anim_player && (object_type == 0 ||  object_type == 1)):	
		if(previous_animation_position != anim_player.current_animation_length  && anim_player.current_animation_position == anim_player.current_animation_length  && !get_parent().get_parent().pause && !get_parent().get_parent().backwards):
			append_door_opening("forwards")
	
	#TODO this whole thing doesnt work yet	
	if(door_closed_at_ticks.size() > 0 && (object_type == 0 ||  object_type == 1)):	
		if(get_parent().get_parent().ticks == door_closed_at_ticks[index][0] && get_parent().get_parent().backwards):
			if(door_closed_at_ticks[index][1] == "backwards"):
				anim_player.play("Action")
				door_closed_at_ticks.remove_at(index)
				index -=1
		if(get_parent().get_parent().ticks == door_closed_at_ticks[index][0] && get_parent().get_parent().backwards): #+opening_time
			if(door_closed_at_ticks[index][1] == "forwards"):
				anim_player.play_backwards("Action")
				door_closed_at_ticks.remove_at(index)
				index -=1
			
	
	if(anim_player):	
		if(!get_parent().get_parent().pause):
			previous_animation_position = anim_player.current_animation_position			

func _on_area_3d_mouse_entered() -> void:

	for c in get_children():
		if(c is MeshInstance3D):
			var mesh_material = c.get_active_material(0).duplicate()
			c.set_surface_override_material(0, mesh_material)
			mesh_material.albedo_color *= 2
	get_node("/root/Control").highlighted_object = self
	if(object_type == 2):
		get_node("/root/Control").hover_over_camera.global_transform = related_object.camera_pos_node.global_transform
		get_node("/root/Control").subviewport_container.visible = true
		
	#print(get_parent().name)

func _on_area_3d_mouse_exited() -> void:

	for c in get_children():
		if(c is MeshInstance3D):
			var mesh_material = c.get_active_material(0).duplicate()
			c.set_surface_override_material(0, mesh_material)
			mesh_material.albedo_color *= .5
	if(!Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		get_node("/root/Control").highlighted_object = null
	if(object_type == 2):
		get_node("/root/Control").subviewport_container.visible = false
	#print(get_parent().highlighted_object)
	
func append_door_opening(direction:String):
		var array = []
		#if(!door_closed_at_ticks.is_empty()):
			#if(door_closed_at_ticks[index][0]== get_parent().get_parent().ticks):
				#return
		array.append(get_parent().get_parent().ticks)
		#if(get_parent().get_parent().backwards):
			#array.append(direction)
		#else:
		array.append(direction)
		door_closed_at_ticks.append(array)
		index +=1	


func _on_inside_check_area_entered(area: Area3D) -> void:
	if(area.get_parent().is_in_group("Actor")):
		area.get_parent().inside = true
		disable_floor()
	
func _on_outside_check_area_entered(area: Area3D) -> void:
	if(area.get_parent().is_in_group("Actor")):
		area.get_parent().inside = false
		enable_floor()
	
func enable_floor():
		get_node("/root/Control/NavigationRegion3D/"+related_object.name+"/Roof").set_deferred("disabled", false)
		get_node("/root/Control/NavigationRegion3D/"+related_object.name+"/Roof").set_deferred("visible", true)
		for c in get_node("/root/Control/NavigationRegion3D/"+related_object.name+"/Roof").get_children():
			c.set_deferred("disabled", false)
			for ch in c.get_children():
				ch.set_deferred("disabled", false)
		
	
func disable_floor():
		get_node("/root/Control/NavigationRegion3D/"+related_object.name+"/Roof").set_deferred("disabled", true)
		get_node("/root/Control/NavigationRegion3D/"+related_object.name+"/Roof").set_deferred("visible", false)
		for c in get_node("/root/Control/NavigationRegion3D/"+related_object.name+"/Roof").get_children():
			c.set_deferred("disabled", true)
			for ch in c.get_children():
				ch.set_deferred("disabled", true)
		

		
		
