extends Node3D

@export var is_breakable := false

@export_enum("Lock", "Safe", "Alarm", "none") var lock_type
@export_enum("Door", "Window", "Switch", "Container","Loot","other", "Car", "Camera", "Alarm") var object_type
@export_enum("Wood", "Metal", "Glass") var object_material


var ANIMATIONS :Dictionary

@export var damage := 0

#I object was damaged by a damaging tool
var damaged := false

var anim_player:AnimationPlayer
var current_time_in_anim := 0.0
var current_animation_clip := ""
var current_animation_clip_length := 0.0

var door_closed_at_ticks = []

var append := false

var close_door := false

var index := -1

var previous_animation_position := 0.0
var previous_animation_dir := 1
var animation_name := ""

@export var related_objects: Array[Node3D] = []
var related_objects_string_array = []

var is_being_hovered_over
var was_being_hovered_over := false
var previous_index = 0

var was_opened_by_burglar := false

var previous_animation_speed := 1.0

var opening_time := 0.0

var camera_pos_node:Node3D

#calculates the rest time at the end of the animation that is usually smaller than the normal animation "step size"
var animation_rest_time := 0.0

var base_albedos = []

var floor_disabled = false

@export var interaction_point: Vector3
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	var end := 0
	
	match object_type:
		0: end = 4
		1: end = 8
		2: end = 8
		
	ANIMATIONS = {
	"open": {"start": 0, "end": end, "loop": false},
	"use": {"start": 0, "end": end, "loop": false}
	}
	
	for c in get_all_children(self):
		if(c is MeshInstance3D):
			var array = []
			var count = c.get_surface_override_material_count()
			for i in range(count):
				var mesh_material = c.get_active_material(i).duplicate()
				array.append(mesh_material.albedo_color)
			base_albedos.append(array)

	
	if(get_node_or_null("CameraPosNode")):
		camera_pos_node = $CameraPosNode
	
	#if(related_objects):
		#for path in related_objects:
			#related_objects_string_array.append(get_node(path).get_path())
		
	
	pass # Replace with function body.
	if(object_type != 4 && object_type != 5  && object_type != 6 && object_type != 8):
		for c in get_all_children(self):
			if (c is AnimationPlayer):
				anim_player = c
		anim_player.set_auto_capture(false)
		#REMINDER update animation only in physics step 
		anim_player.callback_mode_process = 2
		#anim_player.callback_mode_method = 1
		
		var anim_list = anim_player.get_animation_list()
	
		if anim_list.size() > 0:
			anim_player.current_animation = anim_list[0]
			animation_name = anim_player.current_animation
			
		current_animation_clip = "open"
		if current_animation_clip == "":
			return
	
		var clip = ANIMATIONS[current_animation_clip]
		current_animation_clip_length = clip.end / get_node("/root/Control/").FPS 
		#do I need to make this longer like before (add a factor like 1.1 to it?)
		#FIXME for less physics ticks this results in less opening_time which makes no sense, I kinda fixed this with the constant 60.0
		opening_time = current_animation_clip_length * Engine.physics_ticks_per_second * 1.1
		anim_player.pause()
		
		var sum = 0.0
		var delta = 0.0
		var counter = 0
		while(sum < current_animation_clip_length):
			counter += 1
			delta = current_animation_clip_length - sum
			sum = move_toward(sum, current_animation_clip_length, 1.0/60.0)
		animation_rest_time = delta
	
		
	
func _process(_delta):
	pass
func _physics_process(delta: float) -> void:
	
	if Engine.is_editor_hint():
		return

	var control = get_node("/root/Control")
	#REMINDER this was a quick fix, maybe I should make it more efficient, since right now it double checks this
	if(anim_player):
		if anim_player.current_animation_position != 0.0 && was_opened_by_burglar:
			if related_objects && (object_type == 0 || object_type == 1):
				if !floor_disabled:
					disable_floor()
					floor_disabled = true
	
	if(is_being_hovered_over):
		was_being_hovered_over = true
		control.hover_over_timer += delta
		if(control.hover_over_timer > related_objects.size()):
			control.hover_over_timer = 0.0
		var index = int(floor(control.hover_over_timer))
		
		if(previous_index != index):
			var i := 0
			for c in get_all_children(related_objects[previous_index]):
				if(c.owner.name != "Spotlight" && c.name != "Spotlight"):
					if(c is MeshInstance3D):
						var count = c.get_surface_override_material_count()
						for j in range(count):
							var mesh_material = c.get_active_material(j).duplicate()
							c.set_surface_override_material(j, mesh_material)
							mesh_material.albedo_color = base_albedos[i][j] * 1.0
						i += 1	
		
		previous_index = index
		
		var i := 0
		for c in get_all_children(related_objects[index]):
			if(c.owner.name != "Spotlight" && c.name != "Spotlight"):
				if(c is MeshInstance3D):
					var count = c.get_surface_override_material_count()
					for j in range(count):
						var mesh_material = c.get_active_material(j).duplicate()
						c.set_surface_override_material(j, mesh_material)
						mesh_material.albedo_color = base_albedos[i][j] * 2.0
					i += 1
			
		control.hover_over_camera.global_transform = related_objects[index].camera_pos_node.global_transform
		get_node("/root/Control/SubViewportContainer/SubViewport/CurrentObject").size = Vector2.ZERO
		get_node("/root/Control/SubViewportContainer/SubViewport/CurrentObject").text = str(index+1) + "/" + str(related_objects.size()) 
	elif(was_being_hovered_over):
		
		for obj in related_objects:
			var i := 0	
			for c in get_all_children(obj):
				if(c.owner.name != "Spotlight" && c.name != "Spotlight"):
					if(c is MeshInstance3D):
						var count = c.get_surface_override_material_count()
						for j in range(count):
							var mesh_material = c.get_active_material(j).duplicate()
							c.set_surface_override_material(j, mesh_material)
							mesh_material.albedo_color = base_albedos[i][j] * 1.0
						i += 1
						
func update_interactable(delta):
	
	var control = get_node("/root/Control")
	var anim_position := 0.0
	
	if anim_player:
		anim_position = anim_player.current_animation_position
	#if(damage == 0):
		#damaged = false
	
			#print(str(get_node("/root/Control").ticks) + ", " + str(anim_position) + ", " + str(control.backwards)+ ", " + str(anim_player.get_playing_speed()))
			
	
	
	if(anim_player):
		
		if anim_position != 0.0 && was_opened_by_burglar:
			if related_objects && (object_type == 0 || object_type == 1):
				if !floor_disabled:
					disable_floor()
					floor_disabled = true
		
		if anim_position == 0.0 && previous_animation_position != 0.0:
			if !control.active_burglar.inside:
				if related_objects && (object_type == 0 || object_type == 1):
					if(floor_disabled):
						enable_floor()
						floor_disabled = false
					
			close_door = false
		if(close_door && !control.pause):
			play_animation(animation_name, true, true)
			close_door = false
			
		#anim_player.speed_scale = Engine.time_scale
		#if(!control.pause):
	
	
	
	if(anim_player && (object_type == 0 ||  object_type == 1)):
		if(is_breakable && anim_position == current_animation_clip_length && !control.pause):
			var min_distance= INF
			for actor in get_tree().get_nodes_in_group("Actor"):
				if((actor.is_guard && !was_opened_by_burglar) || (!actor.is_guard && was_opened_by_burglar)):
					if (global_position.distance_squared_to(actor.global_position) < min_distance):
						min_distance = global_position.distance_squared_to(actor.global_position)
			
			
			if(min_distance > 10 && is_breakable && (control.burglar_moved || control.play || Global.load_replay || control.forwards|| control.active_burglar.is_opening) && !control.backwards && !control.was_backwards && !control.pause):
				close_door = true
				append = true
	
	
				
	if(anim_player && (object_type == 0 ||  object_type == 1)):	
		if(previous_animation_position != 0.0 && anim_position == 0.0  && !control.pause && !control.backwards && append):
			append_door_opening("backwards")
			append = false
	
	
			
	if(anim_player && (object_type == 0 ||  object_type == 1)):	
		if(previous_animation_position != current_animation_clip_length  && anim_position == current_animation_clip_length  && !control.pause && !control.backwards):
			append_door_opening("forwards")
			
	
	
	
	if current_animation_clip == "":
		return
	
	var clip = ANIMATIONS[current_animation_clip]

	if (anim_position * get_node("/root/Control/").FPS >= clip.end && previous_animation_dir == 1) || (previous_animation_dir == -1 && anim_position *  get_node("/root/Control/").FPS <= clip.start):
		if clip.loop:
			if(!get_node("/root/Control/").backwards):
				anim_player.seek(clip.start / get_node("/root/Control/").FPS, true)
			else:
				anim_player.seek(clip.end /  get_node("/root/Control/").FPS, true)
		else:
			anim_player.pause()
			current_animation_clip = ""			

	
			
	if(anim_player):	
		if(!control.pause):
			previous_animation_position = anim_position	

func _on_area_3d_mouse_entered() -> void:
	
	if(!get_node("/root/Control").active_burglar.bag.shown):
		if(self != get_node("/root/Control").selected_tool):
			var i = 0
			for c in get_all_children(self):
				if(c is MeshInstance3D):
					var count = c.get_surface_override_material_count()
					for j in range(count):
						var mesh_material = c.get_active_material(j).duplicate()
						c.set_surface_override_material(j, mesh_material)
						mesh_material.albedo_color = base_albedos[i][j] * 2.0
					i+=1
						
						
			if(get_node("/root/Control/InteractionButtons").visible):
				return
						
			get_node("/root/Control").highlighted_object = self
			if(object_type == 2 || object_type == 8):
				get_node("/root/Control").subviewport_container.visible = true
				is_being_hovered_over = true
				
		#print(get_parent().name)

func _on_area_3d_mouse_exited() -> void:
	
	if(!get_node("/root/Control").active_burglar.bag.shown):
		var i = 0
		for c in get_all_children(self):
			if(c is MeshInstance3D):
				var count = c.get_surface_override_material_count()
				for j in range(count):
					var mesh_material = c.get_active_material(j).duplicate()
					c.set_surface_override_material(j, mesh_material)
					mesh_material.albedo_color = base_albedos[i][j]
				i+=1
						
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
		if(area.owner == get_node("/root/Control").active_burglar):
			get_node("/root/Control").disable_spring_arm()
		if(area.get_parent() == get_node("/root/Control").active_burglar):
			if(!floor_disabled):
				disable_floor()
				floor_disabled = true
	
func _on_outside_check_area_entered(area: Area3D) -> void:
	if(area.get_parent().is_in_group("Actor")):
		area.get_parent().inside = false
		if(area.owner == get_node("/root/Control").active_burglar):
			get_node("/root/Control").enable_spring_arm()
		if(area.get_parent() == get_node("/root/Control").active_burglar):
			if(!floor_disabled):
				disable_floor()
				floor_disabled = true
			
func replay_door_animation():	
	#TODO this whole thing doesnt work yet	
	if(get_node("/root/Control").backwards): 
		if(door_closed_at_ticks.size() > 0 && (object_type == 0 ||  object_type == 1)):	
			#if(get_node("/root/Control").ticks == door_closed_at_ticks[door_closed_at_ticks.size()-1][0]):
				#print("backwards? " + str(owner.backwards))	
			if(get_node("/root/Control").ticks == door_closed_at_ticks[door_closed_at_ticks.size()-1][0] && door_closed_at_ticks[door_closed_at_ticks.size()-1][1] == "backwards"):
				play_animation(animation_name, false, true)
				door_closed_at_ticks.erase(door_closed_at_ticks.back())
				index -=1
			elif(get_node("/root/Control").ticks < door_closed_at_ticks[door_closed_at_ticks.size()-1][0] && door_closed_at_ticks[door_closed_at_ticks.size()-1][1] == "backwards"):
				play_animation(animation_name, false, true)
				anim_player.advance(1.0/get_node("/root/Control").FPS)
				door_closed_at_ticks.erase(door_closed_at_ticks.back())
				index -=1
			elif(get_node("/root/Control").ticks == door_closed_at_ticks[door_closed_at_ticks.size()-1][0] && door_closed_at_ticks[door_closed_at_ticks.size()-1][1] == "forwards"): #+opening_time
				play_animation(animation_name, true, true)
				door_closed_at_ticks.erase(door_closed_at_ticks.back())
				index -=1
			elif(get_node("/root/Control").ticks < door_closed_at_ticks[door_closed_at_ticks.size()-1][0] && door_closed_at_ticks[door_closed_at_ticks.size()-1][1] == "forwards"):
				play_animation(animation_name, true, true)
				anim_player.advance(1.0/get_node("/root/Control").FPS)
				door_closed_at_ticks.erase(door_closed_at_ticks.back())
				index -=1		
				
				
	
func enable_floor():
	for i in range (get_node("/root/Control").active_burglar.current_floor, related_objects[0].number_of_floors +1):
		#get_node(str(related_objects[0])+"/Inside/Floor"+str(i)).cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_ON
		for c in get_all_children(get_node(str(related_objects[0].get_path())+"/Inside/Floor"+str(i))):
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
	for i in range (get_node("/root/Control").active_burglar.current_floor +1, related_objects[0].number_of_floors +1):
		#get_node(str(related_objects[0])+"/Inside/Floor"+str(i)).cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		for c in get_all_children(get_node(str(related_objects[0].get_path())+"/Inside/Floor"+str(i))):
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
	
func play_animation(name:String, backwards:bool, save_anim_direction:bool):
	
	current_animation_clip = "open"
	
	var clip = ANIMATIONS[current_animation_clip]
	current_animation_clip_length = clip.end / get_node("/root/Control/").FPS
	
	
	if(!backwards):
		anim_player.play(animation_name)
		if(save_anim_direction):	
			previous_animation_dir = 1
	else:
		anim_player.play_backwards(animation_name)
		if(save_anim_direction):
			previous_animation_dir = -1
			#
	#var line = "Line:" + str(frame[0]["line"])
	#var source = "Source:" + frame[0]["source"]
	#var function = "Function:" + frame[0]["function"]
	#print("%s - %s - %s" % [source,function,line])
