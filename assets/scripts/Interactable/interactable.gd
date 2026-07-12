#FIXME scrubbing forwards and backwards during animation doesn't work correctly, the playback direction is not the right one

extends Node3D

@export var is_breakable = false

@export_enum("Lock", "Safe", "Alarm", "none") var lock_type
@export_enum("Door", "Window", "Switch", "Container","Loot","other", "Car", "Camera", "Alarm") var object_type
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

var previous_animation_dir = 1

@export var related_objects = []
var related_objects_string_array = []

var is_being_hovered_over

var was_opened_by_burglar = false

var previous_animation_speed = 1.0

var opening_time = 0.0

var camera_pos_node:Node3D

#calculates the rest time at the end of the animation that is usually smaller than the normal animation "step size"
var animation_rest_time = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if(get_node_or_null("CameraPosNode")):
		camera_pos_node = $CameraPosNode
	
	for path in related_objects:
		related_objects_string_array.append(get_node(path).get_path())
		
	
	pass # Replace with function body.
	if(object_type != 4 && object_type != 5  && object_type != 6 && object_type != 8):
		anim_player = $AnimationPlayer
		anim_player.set_auto_capture(false)
		#REMINDER update animation only in physics step 
		anim_player.callback_mode_process = 2
		#anim_player.callback_mode_method = 1
		
		anim_player.current_animation = "Action"
		#do I need to make this longer like before (add a factor like 1.1 to it?)
		#FIXME for less physics ticks this results in less opening_time which makes no sense, I kinda fixed this with the constant 60.0
		opening_time = anim_player.current_animation_length * 60.0
		anim_player.pause()
		
		var sum = 0.0
		var delta = 0.0
		var counter = 0
		while(sum < anim_player.current_animation_length):
			counter += 1
			delta = anim_player.current_animation_length - sum
			sum = move_toward(sum, anim_player.current_animation_length, 1.0/60.0)
		animation_rest_time = delta
		
		
func _physics_process(delta: float) -> void:
	if(is_being_hovered_over):
		get_node("/root/Control").hover_over_timer += delta
		if(get_node("/root/Control").hover_over_timer > related_objects.size()):
			get_node("/root/Control").hover_over_timer = 0.0
		var index = int(floor(get_node("/root/Control").hover_over_timer))
		get_node("/root/Control").hover_over_camera.global_transform = get_node(str(related_objects[index])).camera_pos_node.global_transform
		get_node("/root/Control/SubViewportContainer/SubViewport/CurrentObject").size = Vector2.ZERO
		get_node("/root/Control/SubViewportContainer/SubViewport/CurrentObject").text = str(index+1) + "/" + str(related_objects.size()) 

func update_interactable(delta):
	
	#if(damage == 0):
		#damaged = false
	
			#print(str(get_node("/root/Control").ticks) + ", " + str(anim_player.current_animation_position) + ", " + str(get_node("/root/Control").backwards)+ ", " + str(anim_player.get_playing_speed()))
			
	
	if(anim_player):
		
		if(anim_player.current_animation_position != 0.0 && was_opened_by_burglar):
			if(related_objects && (object_type == 0 || object_type == 1)):
				disable_floor()
		
		if(anim_player.current_animation_position == 0.0 && previous_animation_position != 0 && was_opened_by_burglar):
			#was_opened_by_burglar = false
			if(!get_node("/root/Control").active_burglar.inside):
				if(related_objects && (object_type == 0 || object_type == 1)):
					enable_floor()
					
			close_door = false
		if(close_door && !get_node("/root/Control").pause):
			play_animation("Action", true, true, get_stack())
			close_door = false
			
		#anim_player.speed_scale = Engine.time_scale
		#if(!get_node("/root/Control").pause):
	
	
	if(anim_player && (object_type == 0 ||  object_type == 1)):
		if(is_breakable && anim_player.current_animation_position == anim_player.current_animation_length && !get_node("/root/Control").pause):
			var min_distance= INF
			for actor in get_tree().get_nodes_in_group("Actor"):
				if((actor.is_guard && !was_opened_by_burglar) || (!actor.is_guard && was_opened_by_burglar)):
					if (global_position.distance_squared_to(actor.global_position) < min_distance):
						min_distance = global_position.distance_squared_to(actor.global_position)
			
			
			if(min_distance > 10 && is_breakable && (get_node("/root/Control").burglar_moved || get_node("/root/Control").play || Global.load_replay || get_node("/root/Control").forwards|| get_node("/root/Control").active_burglar.is_opening) && !get_node("/root/Control").backwards && !get_node("/root/Control").was_backwards && !get_node("/root/Control").pause):
				close_door = true
				append = true
				
	if(anim_player && (object_type == 0 ||  object_type == 1)):	
		if(previous_animation_position != 0.0 && anim_player.current_animation_position == 0.0  && !get_node("/root/Control").pause && !get_node("/root/Control").backwards && append):
			append_door_opening("backwards")
			append = false
			
	if(anim_player && (object_type == 0 ||  object_type == 1)):	
		if(previous_animation_position != anim_player.current_animation_length  && anim_player.current_animation_position == anim_player.current_animation_length  && !get_node("/root/Control").pause && !get_node("/root/Control").backwards):
			append_door_opening("forwards")
			
			
	if(anim_player):	
		if(!get_node("/root/Control").pause):
			previous_animation_position = anim_player.current_animation_position			

func _on_area_3d_mouse_entered() -> void:
	
	if(self != get_node("/root/Control").selected_tool):	
		for c in get_all_children(self):
			if(c is MeshInstance3D):
					var count = c.get_surface_override_material_count()
					for i in range(count):
						var mesh_material = c.get_active_material(i).duplicate()
						c.set_surface_override_material(i, mesh_material)
						mesh_material.albedo_color *= 2.0
					
					
		if(get_node("/root/Control/InteractionButtons").visible):
			return
					
		get_node("/root/Control").highlighted_object = self
		if(object_type == 2 || object_type == 8):
			get_node("/root/Control").subviewport_container.visible = true
			is_being_hovered_over = true
			
	#print(get_parent().name)

func _on_area_3d_mouse_exited() -> void:
	
	for c in get_all_children(self):
		if(c is MeshInstance3D):
				var count = c.get_surface_override_material_count()
				for i in range(count):
					var mesh_material = c.get_active_material(i).duplicate()
					c.set_surface_override_material(i, mesh_material)
					mesh_material.albedo_color *= 0.5
					
	if(get_node("/root/Control/InteractionButtons").visible):
		return				
	if(!Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		get_node("/root/Control").highlighted_object = null
		get_node("/root/Control").subviewport_container.visible = false
		is_being_hovered_over = false
	if(object_type == 2 || object_type == 8):
		get_node("/root/Control").subviewport_container.visible = false
		is_being_hovered_over = false
		get_node("/root/Control").hover_over_timer = 0.0
	#print(get_parent().highlighted_object)
	
func append_door_opening(direction:String):
		var array = []
		#if(!door_closed_at_ticks.is_empty()):
			#if(door_closed_at_ticks[index][0]== get_node("/root/Control").ticks):
				#return
		array.append(get_node("/root/Control").ticks)
		#if(get_node("/root/Control").backwards):
			#array.append(direction)
		#else:
		array.append(direction)
		door_closed_at_ticks.append(array)
		index +=1	


func _on_inside_check_area_entered(area: Area3D) -> void:
	if(area.get_parent().is_in_group("Actor")):
		area.get_parent().inside = true
		if(area.owner == owner.active_burglar):
			get_node("/root/Control").disable_spring_arm()
		if(area.get_parent() == get_node("/root/Control").active_burglar):
			disable_floor()
	
func _on_outside_check_area_entered(area: Area3D) -> void:
	if(area.get_parent().is_in_group("Actor")):
		area.get_parent().inside = false
		if(area.owner == owner.active_burglar):
			get_node("/root/Control").enable_spring_arm()
		if(area.get_parent() == get_node("/root/Control").active_burglar):
			disable_floor()
			
func replay_door_animation():	
	#TODO this whole thing doesnt work yet	
	if(get_node("/root/Control").backwards): 
		if(door_closed_at_ticks.size() > 0 && (object_type == 0 ||  object_type == 1)):	
			#if(get_node("/root/Control").ticks == door_closed_at_ticks[door_closed_at_ticks.size()-1][0]):
				#print("backwards? " + str(owner.backwards))	
			if(get_node("/root/Control").ticks == door_closed_at_ticks[door_closed_at_ticks.size()-1][0] && door_closed_at_ticks[door_closed_at_ticks.size()-1][1] == "backwards"):
				play_animation("Action", false, true, get_stack())
				door_closed_at_ticks.erase(door_closed_at_ticks.back())
				index -=1
			elif(get_node("/root/Control").ticks < door_closed_at_ticks[door_closed_at_ticks.size()-1][0] && door_closed_at_ticks[door_closed_at_ticks.size()-1][1] == "backwards"):
				play_animation("Action", false, true, get_stack())
				anim_player.advance(1.0/30.0)
				door_closed_at_ticks.erase(door_closed_at_ticks.back())
				index -=1
			elif(get_node("/root/Control").ticks == door_closed_at_ticks[door_closed_at_ticks.size()-1][0] && door_closed_at_ticks[door_closed_at_ticks.size()-1][1] == "forwards"): #+opening_time
				play_animation("Action", true, true, get_stack())
				door_closed_at_ticks.erase(door_closed_at_ticks.back())
				index -=1
			elif(get_node("/root/Control").ticks < door_closed_at_ticks[door_closed_at_ticks.size()-1][0] && door_closed_at_ticks[door_closed_at_ticks.size()-1][1] == "forwards"):
				play_animation("Action", true, true, get_stack())
				anim_player.advance(1.0/30.0)
				door_closed_at_ticks.erase(door_closed_at_ticks.back())
				index -=1		
				
				
	
func enable_floor():
	for i in range (get_node("/root/Control").active_burglar.current_floor, get_node("/root/Control").number_of_floors +1):
		get_node(str(related_objects[0])+"/Floor"+str(i)).cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_ON
		for c in get_all_children(get_node(str(related_objects[0])+"/Floor"+str(i))):
			if(c.name != "Spotlight"):
				if(c.is_in_group("Interactable")):
					if(c.object_type == 4):
						continue
				c.set_deferred("visible", true)
				
				if(c is CollisionObject3D):
					c.collision_layer = 1
		
		#get_node(str(related_objects[0])+"/Floor"+str(i)).process_mode = Node.PROCESS_MODE_ALWAYS
		
			#for c in get_all_children(get_node(str(related_objects[0])+"/Floor"+str(i))):
				#if(c is MeshInstance3D):
					#c.ShadowCastingSetting = MeshInstance3D.SHADOW_CASTING_SETTING_ON
		#for c in get_node(str(related_objects[0])+"/Floor").get_children():
			#c.set_deferred("disabled", false)
			#for ch in c.get_children():
				#ch.set_deferred("disabled", false)
		#
	
func disable_floor():
	for i in range (get_node("/root/Control").active_burglar.current_floor +1, get_node("/root/Control").number_of_floors +1):
		get_node(str(related_objects[0])+"/Floor"+str(i)).cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		for c in get_all_children(get_node(str(related_objects[0])+"/Floor"+str(i))):
			if(c.name != "Spotlight"):
				if(c.is_in_group("Interactable")):
					if(c.object_type == 4):
						continue
				c.set_deferred("visible", false)
		
				if(c is CollisionObject3D):
					c.collision_layer = 2
					
		#get_node(str(related_objects[0])+"/Floor"+str(i)).process_mode = Node.PROCESS_MODE_DISABLED

		#for c in get_node(str(related_objects[0])+"/Floor").get_children():
			#for ch in c.get_children():
				#ch.set_deferred("disabled", true)
			#c.set_deferred("disabled", true)
		#get_node(str(related_objects[0])+"/Floor").set_deferred("disabled", true)

func get_all_children(node):
	var nodes : Array = []

	for N in node.get_children():

		if N.get_child_count() > 0:

			nodes.append(N)

			nodes.append_array(get_all_children(N))

		else:

			nodes.append(N)

	return nodes
	
func play_animation(name:String, backwards:bool, save_anim_direction:bool, frame):
	if(!backwards):
		anim_player.play("Action")
		if(save_anim_direction):	
			previous_animation_dir = 1
	else:
		anim_player.play_backwards("Action")
		if(save_anim_direction):
			previous_animation_dir = -1
			#
	#var line = "Line:" + str(frame[0]["line"])
	#var source = "Source:" + frame[0]["source"]
	#var function = "Function:" + frame[0]["function"]
	#print("%s - %s - %s" % [source,function,line])
	
