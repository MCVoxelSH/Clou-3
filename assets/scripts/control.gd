extends Node3D

#REMINDER using navigation obstacles might be another solution to fix roofs being included in the navmesh 
#REMINDER using nodepath instead of nodes might be useful for accessing nodes like interactable objects
#REMINDER add navigation obstacles for interactables
#FIXME when quickly going back and forth while an actor goes through a door the replay gets scewed
#FIXME stair checks get skipped when using the skip backwards or forwards buttons
#I disabled skip_to_start_or_end because of this and instead enabled "skipping steps" for the slider and froze the frame for a moment, this works pretty well right now aswell 
#FIXME when going through doors then scrolling back and the door suddenly is not open anymore the system doesn't account for this case yet
#REMINDER I was currently working on timed switches, they probably aren't fleshed out yet, I am pretty sure it has problems like the one that doors had with fast rewinding and fast forwarding at the exact point in time where the object toggles

const FPS:= 24.0

@export var debug_mode = false
@onready var engine_speed:float = Engine.physics_ticks_per_second
@export var engine_speed_overwrite:float = 60.0

@export var play = false
#@export execute_plan = false
#@export load_replay = false

@export var burglary_target:NodePath

@export var min_loot = 0

#rewind and play forwards
var backwards = false
var forwards = false

var newpoint:bool
	
var ticks = 0
const Character = preload("res://assets/scripts/character.gd")

@onready var active_burglar = $Burglar1
@onready var camera_base = $CameraBase
@onready var spring_arm = $CameraBase/SpringArm3D
@onready var spring_arm_length_before_zoom_in = spring_arm.spring_length
var zoom_in_spring_arm_length = 1.5
var _camera: Camera3D
@onready var tool_path = "/Bag/SubViewport/Camera/"

@onready var hover_over_camera = $SubViewportContainer/SubViewport/HoverOverCamera
var hover_over_timer = 0.0
@onready var subviewport_container = $SubViewportContainer

@onready var audio_player = $AudioStreamPlayer

@onready var burglar_switcher = $BurglarSwitcher
#@onready var _robot := $RobotBase as Character

var active_burglar_index = 1
var number_of_burglars = 0
var number_of_guards = 0
@export var selected_car:Node3D

var guards_are_recording = false

var clicks = 0
var counter = 0
var _cam_rotation_x := 0.0
var _cam_rotation_y := 0.0

var highlighted_object:Node3D = null
var selected_tool:Node3D = null

var burglar_moved = false

var was_backwards = false		
var was_forwards = false

var previous_slider_value = 0

var recording = false
var pause = true
var play_until_ticks = -1

var query_set_target_position = false
var closest_point_on_navmesh_for_query = Vector3.ZERO

var timescale = 1.0
var actual_timescale = 1.0

var object_parent_node:String = ""

var object_durability = 10000

var noise_threshold = 500.0
#current loudest sound made by burglar
var max_loudness = 0.0

var cash = 0

var was_caught = false
var was_success = false
var caught_message = ""
var previous_caught_message = ""

var debug_file = FileAccess.open("user://debug.txt", FileAccess.WRITE)

@export_flags_3d_physics var left_click_collision_layers 

var first_person_mode = false

var direction_changed = false

var skip_to_start_or_end = false
#var debug_file2 = FileAccess.open("user://debug2.txt", FileAccess.WRITE)

#decides wether to play idle anim or not
var play_idle_anim_rng = RandomNumberGenerator.new()

func _ready() -> void:
	
	play_idle_anim_rng.randomize()
	#connect signals
	$PauseMenu/CloseMissionMenu.button_up.connect(_on_close_mission_menu_button_up)
	$PauseMenu/QuitMission.button_up.connect(_on_quit_mission_button_up)
	$PauseMenu/RestartMission.button_up.connect(_on_restart_mission_button_up)
	$PauseMenu/LoadPlan.button_up.connect(_on_load_plan_button_up)
	$PauseMenu/SavePlan.button_up.connect(_on_save_plan_button_up)
	$PauseMenu/ExecutePlan.button_up.connect(_on_execute_plan_button_up)
	$PauseMenu/QuitMission/QuitMissionConfirmationDialog.confirmed.connect(_on_quit_mission_confirmation_dialog_confirmed_button_up)
	$PauseMenu/QuitMission/QuitMissionConfirmationDialog.canceled.connect(_on_quit_mission_confirmation_dialog_canceled_button_up)


	
	if(!OS.has_feature("editor")):
		debug_mode = false
	
	if(debug_mode):
		$DebugSphere.visible = true
	
	if(Global.execute_plan):
		play = true
		play_music("res://assets/Clou original files/Audio/Music/Track04.ogg")
	#else:
		#play_music("res://assets/Clou original files/Audio/Music/Track03.ogg")
	if(play):
		pause = false
		
		
	for actor in get_tree().get_nodes_in_group("Actor"):
		if(!actor.is_guard):
			number_of_burglars += 1
			actor.filepath_addon = str(number_of_burglars)
			var mesh = actor.mesh_root.duplicate()
			mesh.set_script(load("res://assets/Scenes/Items/item.gd"))
			var area = actor.burglar_area.duplicate()
			area.input_ray_pickable = true
			area.mouse_entered.connect(mesh._on_area_3d_mouse_entered)
			area.mouse_exited.connect(mesh._on_area_3d_mouse_exited)
			mesh.add_child(area)
			mesh.add_to_group("burglar_in_burglar_switcher")
			
			for c in mesh.get_all_children(mesh):
				if(c is MeshInstance3D):
					var count = c.get_surface_override_material_count()
					for i in range(count):
						var mesh_material = c.get_active_material(i).duplicate()
						mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
						c.set_surface_override_material(i, mesh_material)
						c.layers = 2
						
							
			mesh.scale *= 0.4
			mesh.visible = false
			burglar_switcher.get_child(0).get_child(0).add_child(mesh)
		else:
			number_of_guards += 1
			actor.filepath_addon = str(number_of_burglars + number_of_guards)
	
		if(actor.is_guard):
			if(actor.record_guard):
				guards_are_recording = true
			
		actor.load_replay()
		

		
	#if(play):
		#$SliderBackground/HSlider.set_min(0.0)
	var child_node = $CameraBase
	#child_node.update_camera()
	remove_child(child_node)
	active_burglar.add_child(child_node)
	_camera = get_node(active_burglar.name+"/CameraBase/SpringArm3D/Camera3D")
	
	#since burglars are outside everytime we can call this method at the start
	enable_spring_arm()		
	floor_visibility_check.change_visibility(active_burglar, false)
		
func _process(delta: float) -> void:

	if(selected_tool):	
		selected_tool.global_position = _camera.project_position(get_viewport().get_mouse_position(), 3.0)
	
	if(debug_mode):
		if(Input.is_action_just_pressed("debug_speed_toggle")):
			if(engine_speed != engine_speed_overwrite):
				engine_speed = engine_speed_overwrite 
			else:
				engine_speed = 60.0
			change_game_speed(previous_slider_value)
				
	if(active_burglar.is_guard):
		if(active_burglar.record_guard || debug_mode):
			if(Input.is_action_just_released("switch_to_next_interaction")):
				active_burglar.selected_interaction += 1
		
			if(Input.is_action_just_released("switch_to_previous_interaction")):
				active_burglar.selected_interaction -= 1
				
			if(Input.is_action_just_released("finalize_guard_replay")):
				active_burglar.finalize_guard_replay = true
	
	if(Input.is_action_just_pressed("first_person_mode")):
		spring_arm_length_before_zoom_in = spring_arm.spring_length
		spring_arm.spring_length = 0.0
		first_person_mode = true

	if(Input.is_action_just_released("first_person_mode")):
		spring_arm.spring_length = spring_arm_length_before_zoom_in
		first_person_mode = false

	if(!burglar_switcher.shown):
		if(Input.is_action_just_released("ui_focus_next")):
			switch_to_actor(active_burglar_index + 1)
		if(Input.is_action_just_pressed("switch_to_burglar1")):
			switch_to_actor(1)
		if(Input.is_action_just_pressed("switch_to_burglar2")):
			switch_to_actor(2)		
		if(Input.is_action_just_pressed("switch_to_burglar3")):
			switch_to_actor(3)		
		if(Input.is_action_just_pressed("switch_to_burglar4")):
			switch_to_actor(4)		
				
	
	if(Input.is_action_just_pressed("fast_forward")):
		#REMINDER need to change this later, this is just a temporary solution
		#selected_tool = active_burglar.bag.get_child(0)
		pass
	
			
	if(Input.is_action_just_pressed("rewind")):
		#REMINDER need to change this later, this is just a temporary solution
		#selected_tool = null
		pass

func _physics_process(delta: float) -> void:
	
	if(active_burglar.is_guard):
		if(active_burglar.finalize_guard_replay):
			active_burglar.set_target_position(active_burglar.start_pos,true)
			pause = false
			play = false
			active_burglar.finalize_guard_replay = false
		#if(query_set_target_position):
			#active_burglar.set_target_position(closest_point_on_navmesh_for_query,true)
			#query_set_target_position = false
	
	#TODO I disabled it because it didn't work anymore, maybe I want to reenable it later if I fix it
	if(Global.load_replay):
		#var highest_ticks = 0
		#for actor in get_tree().get_nodes_in_group("Actor"):
			#if(actor.replay.size() > 0 && !actor.is_guard):
				#if(actor.replay[actor.replay.size()-1][0] > highest_ticks && !actor.is_guard):
					#highest_ticks = actor.replay[actor.replay.size()-1][0]
				#
		#pass
		#while(ticks != highest_ticks):
			#do_replay()
		Global.load_replay = false
		
			
	#FIXME this is not currently working aswell as in line 324
	if(play_until_ticks != -1):
		if(ticks == play_until_ticks):
			play_until_ticks = -1
			_on_h_slider_value_changed(0.0)
			pause_recording()
			RenderingServer.render_loop_enabled = true
			return
								
	
	if(!pause):
		while(true):
		#print("ticks before doing replay: " + str(ticks))
			do_replay()	
			#REMINDER I changed this from !pause to true, does this cause issues
			if(!pause):
				update_interactables(delta)
				resume_animations()	
				#if(active_burglar.is_waiting):
					#
					#var found_index = 0
					#for i in range(0,ticks):
						#if(i == active_burglar.waiting_positions.size()):
							#break
						##REMINDER changed from ticks + 2
						#if(active_burglar.waiting_positions[i][0] == ticks):
							#found_index = i
					#var object_being_waited_for = get_node(active_burglar.waiting_positions[found_index][1])
					#print(active_burglar.name + " waiting at id " + str(active_burglar.id) + ", backwards: " + str(backwards) + ", ticks: " + str(ticks) + ", waiting for object: " + object_being_waited_for.name +", anim position: " + str(object_being_waited_for.anim_player.current_animation_position) + " with slider value: " + str(previous_slider_value) + ", playing: "+ str(object_being_waited_for.anim_player.is_playing()))
					#if (ticks ==  1138 && object_being_waited_for.anim_player.current_animation_position * 2.0 == 1.0):
						#breakpoint
						##debug_previous_animation_position = object_being_waited_for.anim_player.current_animation_position
				#else:
					#print(active_burglar.name + " waiting at id " + str(active_burglar.id) + ", backwards: " + str(backwards)+ ", ticks: " + str(ticks))		
				 
			else:
				pause_animations()
			
			if(skip_to_start_or_end && ticks == play_until_ticks):
				skip_to_start_or_end = false
				
			if(!skip_to_start_or_end):
				break
	else:
		pause_animations()
	
				
	#if(!active_burglar/NavigationAgent3D.is_navigation_finished()):
		#ticks +=1
		
	
		#_robot.set_target_position(active_burglar.replay[currentid][1],false)
		

func _unhandled_input(event: InputEvent):
	
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_WHEEL_UP && !active_burglar.is_zoomed_onto_object && !active_burglar.bag.shown && !burglar_switcher.shown:
		
		var camera_offset = 0.5
		
		if(get_node(active_burglar.name+"/CameraBase/SpringArm3D").spring_length > 3):
			get_node(active_burglar.name+"/CameraBase/SpringArm3D").spring_length -= camera_offset
		
		if(selected_tool):	
			selected_tool.global_position = get_viewport().get_camera_3d().project_position(event.global_position, 3.0)
		
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_WHEEL_DOWN && !active_burglar.is_zoomed_onto_object && !active_burglar.bag.shown && !burglar_switcher.shown:
		
		#var camera_offset = get_node(active_burglar.name+"/CameraBase").position - get_node(active_burglar.name+"/CameraBase/SpringArm3D/Camera3D").position
		
		var camera_offset = -0.5
		
		if(get_node(active_burglar.name+"/CameraBase/SpringArm3D").spring_length < 15):
			get_node(active_burglar.name+"/CameraBase/SpringArm3D").spring_length -= camera_offset

		if(selected_tool):	
			selected_tool.global_position = get_viewport().get_camera_3d().project_position(event.global_position, 3.0)
	
	#REMINDER this is for when selecting an option while hovering over an interactable
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
		
		if(Global.execute_plan || !recording || active_burglar.bag.shown || burglar_switcher.shown || burglar_switcher.shown):
			return
		
		if(active_burglar.replay.size() > 0):
			if(active_burglar.replay[active_burglar.id][2] == "moveinsidecar"):
				return
		
		var closest_point_on_navmesh:Vector3
		
		if(highlighted_object != null):
			if(!highlighted_object.is_in_group("Item")):
				
				var dir:Vector3= GlobalFunctions.get_interaction_forward(highlighted_object)
				
				#var modifier = 1
				#
				if(highlighted_object.object_type == 0 || highlighted_object.object_type == 1 || highlighted_object.object_type == 4 || highlighted_object.object_type == 6):
					if (abs(dir.x) == 1.0):
						if(active_burglar.global_position.x < highlighted_object.global_position.x):
							dir *= -1
					else:
						if(active_burglar.global_position.z > highlighted_object.global_position.z):
							dir *= -1
				#
				#if(highlighted_object.object_type == 1):
				#####if(closest_point_on_navmesh.z)
					#if(active_burglar.inside):
						#closest_point_on_navmesh = highlighted_object.global_position - highlighted_object.global_transform.basis.z 
					#else:
						#closest_point_on_navmesh = highlighted_object.global_position + highlighted_object.global_transform.basis.z
				#else:#if(highlighted_object.object_type != 0 && highlighted_object.object_type != 1):
				
				 
				if(highlighted_object.object_type != 6):
					closest_point_on_navmesh = highlighted_object.global_position + dir
				else:
					closest_point_on_navmesh = highlighted_object.global_position + dir

				active_burglar.set_target_position(closest_point_on_navmesh,true)
				pause = false
				play = false
				
				$InteractionButtons.visible = false
				
				highlighted_object = null
				if(selected_tool):
					selected_tool.visible = false
					selected_tool.area.process_mode = ProcessMode.PROCESS_MODE_INHERIT
					selected_tool = null

	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		
		if(active_burglar.bag.shown || burglar_switcher.shown):
			return
		
		if(highlighted_object != null && active_burglar.bag.shown):
			active_burglar.bag.shown = false

		if(Global.execute_plan || !recording || active_burglar.bag.shown || burglar_switcher.shown):
			return

		#_on_h_slider_value_changed(1.0)
	
		if(active_burglar.replay.size() > 0):
			if(active_burglar.replay[active_burglar.id][2] == "moveinsidecar"):
				return
			
			if (play_until_ticks != -1):
				return
			if((active_burglar.replay[active_burglar.id][2] == "open" || active_burglar.replay[active_burglar.id][2] == "use" || active_burglar.replay[active_burglar.id][2] == "movethroughwindow") && (active_burglar.replay[active_burglar.id][0] == -1 || active_burglar.id != active_burglar.maxid -1) && active_burglar.replay[active_burglar.id][0] != ticks):
				play_until_ticks = ticks - 1
				for i in range (active_burglar.id, active_burglar.replay.size()):
					if(active_burglar.replay[i][2] == "open" || active_burglar.replay[active_burglar.id][2] == "use" || active_burglar.replay[active_burglar.id][2] == "movethroughwindow"):
						play_until_ticks += 1
							
				_on_play_button_button_up()
				return				
#						

		if(highlighted_object != null):
			if(!highlighted_object.is_in_group("Item")):
				pause = true
				pause_animations()
				play = false
				if(!active_burglar.is_guard):
					if(!selected_tool):	
							$InteractionButtons.visible = true
							$InteractionButtons.global_position = get_viewport().get_camera_3d().unproject_position(highlighted_object.global_position)
					active_burglar.selected_interaction = 1
			else:
				selected_tool = highlighted_object
				active_burglar.bag.shown = false
		
		var closest_point_on_navmesh:Vector3
		
		if(true):
			
					# Get closest point on navmesh for the current mouse cursor position.
			var mouse_cursor_position = event.position
			
			
			var space_state = get_world_3d().direct_space_state
			
			var camera_ray_length := 1000.0
						
			var query = PhysicsRayQueryParameters3D.create(_camera.global_position,_camera.global_position + _camera.project_ray_normal(mouse_cursor_position) * camera_ray_length)
			
			for a in get_tree().get_nodes_in_group("Actor"):
				query.exclude = [a]
	
			query.collision_mask = left_click_collision_layers
			
			var result = space_state.intersect_ray(query)#actor.ray.get_collider()	
			var pos
			
			if(result):
				pos = result.position
			else:
				pos = active_burglar.global_position
				
		
			#var camera_ray_start := _camera.project_ray_origin(mouse_cursor_position)
			#var camera_ray_end := camera_ray_start + _camera.project_ray_normal(mouse_cursor_position) * camera_ray_length

			closest_point_on_navmesh = NavigationServer3D.map_get_closest_point(
				get_world_3d().navigation_map,
				pos
				)
		
			
		
		if(highlighted_object == null):
			if(active_burglar.is_zoomed_onto_object):
				active_burglar.is_zoomed_onto_object = false
				for object in get_tree().get_nodes_in_group("Interactable"):
					if(object.object_type != 4):
						if(object.object_type == 0):
							get_node(str(object.get_path())+"/Door/Area3D").process_mode = Node.PROCESS_MODE_INHERIT
						elif(object.object_type == 1):
							get_node(str(object.get_path())+"/Area3D").process_mode = Node.PROCESS_MODE_INHERIT
						else:
							get_node(str(object.get_path())+"/Area3D").process_mode = Node.PROCESS_MODE_INHERIT
				camera_base.global_position = active_burglar.camera_position_before_zoom_onto_object
				camera_base.global_rotation = active_burglar.camera_rotation_before_zoom_onto_object
				spring_arm.spring_length = spring_arm_length_before_zoom_in
				if(active_burglar.replay[active_burglar.id][2] != "moveinsidecar"):
					active_burglar.mesh_root.visible = true
				return
					
			
		#query_set_target_position = true
		#closest_point_on_navmesh_for_query = closest_point_on_navmesh
		if(highlighted_object == null):
			active_burglar.set_target_position(closest_point_on_navmesh,true)
			if(debug_mode):
				$DebugSphere.global_position = closest_point_on_navmesh
			pause = false
			play = false
		

	elif (event is InputEventMouseMotion):
		if(((event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE + MOUSE_BUTTON_MASK_RIGHT)) || first_person_mode)  && !active_burglar.is_zoomed_onto_object):
			if(!active_burglar.bag.shown && !burglar_switcher.shown):
				_cam_rotation_x -= event.relative.x * 0.005
				_cam_rotation_y += event.relative.y * 0.005
				
				_cam_rotation_y = clamp(_cam_rotation_y, -.3,.75)
				
				get_node(active_burglar.name+"/CameraBase").rotation.y = _cam_rotation_x
				get_node(active_burglar.name+"/CameraBase").rotation.x = _cam_rotation_y
				
				#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			#else:
				#if(!first_person_mode):
					#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)			


	

func do_replay():
	
	check_success()
	
	#for interactable in get_tree().get_nodes_in_group("Interactable"):
		#interactable.process_interactable()
		
		
	#if(pause):
		#for object in get_tree().get_nodes_in_group("Interactable"):
			#if(object.anim_player):
				#object.anim_player.pause()
	#else:
		#for object in get_tree().get_nodes_in_group("Interactable"):
			#if(object.anim_player):
				#object.play_animation("Action", false)
		
	
	burglar_moved = false
		
	#check_and_fix_id()
				
	
	if(!backwards):
		for actor in get_tree().get_nodes_in_group("Actor"):
			if(!was_backwards):#actor.replay.size() > 0 &&
				if(actor.id < actor.maxid):
					if(actor.id < actor.replay.size()-1):
						#TODO think about the >=, I changed it from == so that when a burglar is late they also move
						if(((ticks >= actor.replay[actor.id][0] || actor.replay[actor.id][0] == -1) && !was_forwards)|| (actor.is_guard && (ticks%(actor.max_ticks+1) >=  actor.replay[actor.id][0]) || (-1 ==  actor.replay[actor.id][0]))):
							if(actor == active_burglar && !forwards):
								burglar_moved = true
							#print("id: " + str(active_burglar.id))
							if(!actor.is_opening && !actor.is_waiting):
								actor.id += 1
								actor.last_ticks = ticks	
								if(actor.id == 222):
									pass
								#if(!actor.last_ticks.is_empty()):
									#if(forwards && actor.last_ticks[actor.last_ticks_index+1] == ticks):
										#actor.last_ticks_index += 1
					
			
									
		
		
		if(burglar_moved || forwards || play):
			for actor in get_tree().get_nodes_in_group("Actor"):
				if((actor != active_burglar && actor.maxid > actor.currentid)||(forwards || play) && actor.id != actor.maxid):
					actor.currentid = actor.id
					
		
	if(backwards):
		for obj in get_tree().get_nodes_in_group("Interactable"):
			obj.replay_door_animation()
			
	#REMINDER I split this and unsplit it again, hopefully it doesn't cause issues, then I can merge it again		
	if(!pause):
		if(backwards && ticks > 0):
			ticks -= 1
		elif((burglar_moved || play || Global.load_replay || forwards|| active_burglar.is_opening || active_burglar.is_waiting) && !backwards && !was_backwards):
			ticks += 1
		else:
			pause_recording()
	#TODO is this correct?
	else:
		pause_animations()
			
	#print_current_position_info()			
	
	
	#if($RobotBase.replay.size() > 0 && id!= currentid):
		#if($RobotBase.global_position == $RobotBase.replay[id][1]):
			#if(!backwards):
				#currentid +=1
			#else:
				#currentid -=1
	#print(delta)
	
	#FIXME this was commented out, but is probably important
	#if(active_burglar.id >= active_burglar.replay.size()):
		#active_burglar.id = active_burglar.replay.size()-1
		#if(active_burglar.id < 0):
			#active_burglar.id = 0
	max_loudness = 0.0
	
	#main part, this is where according to the current actor id (index in replay array) actions are performed
	for actor in get_tree().get_nodes_in_group("Actor"):		
		actor.progress_bar.visible = false
		
		if(((actor.id < actor.maxid) || (backwards && actor.id < actor.maxid))  && actor.id != -1):
			
			#TODO hmm
			#if(!backwards && !forwards && !play && !load_replay):#actor.replay[actor.id][0]!= ticks):
				#actor.replay[actor.id][0]= ticks
				
				
			#var CMP_EPSILON = 0.00001
			
	#
			#var from = active_burglar.global_position
			#var to:Vector3
			#var vec:Vector3
			#if(true): 
				#to = active_burglar.replay[active_burglar.id][1]
				#vec = to
				##print("distance: " +str((to - from).length()))
	#
			#var ministep:Vector3
			#if(true):
				#newpoint = false
				##print("to: " +str(to))
				#while(vec != from):
					#
					#var diff = from - vec
					#var length = diff.length()
					#
					#ministep = from - vec
					##print("ministep length: " + str(ministep.length()))
					#
					#vec = from if length <= active_burglar.character_speed || length < CMP_EPSILON else vec + diff / length * active_burglar.character_speed
					#
					##print("vec: " + str(vec))
					##active_burglar.global_position = vec
					##pass
				#active_burglar.global_position -= ministep
			#else:
			if(actor.name == "Burglar1"):
				pass
			
					
			if(backwards):
				replay_backwards(actor)
			#forward direction		
			else:
				replay_forwards(actor)
				

			
			#if(actor.object_that_is_being_interacted_with):
				#print(actor.name + ", object in interaction: " + actor.object_that_is_being_interacted_with.name)
			
	#if((backwards && ticks > 0) || active_burglar.id != active_burglar.currentid && active_burglar.id != -1):		
		#counter += 1
		#if(!backwards):
			##for actor in get_tree().get_nodes_in_group("Actor"):
				##if(actor != active_burglar):
					##actor.currentid +=1
			#ticks +=1
		#else:
			#ticks -=1
		if(!actor.replay.is_empty()):
			if(ticks != actor.replay[actor.id][0] && actor.replay[actor.id][0] != -1):
				if(actor.anim_player):	
					if(!pause):
						actor.previous_animation_position = actor.anim_player.current_animation_position
						#if(play_idle_anim_rng.randi_range(1,1000) > 999):
						if(backwards):
							actor.play_animation("idle", true, true)
						else:
							actor.play_animation("idle", false, true)
		else:
			#if(play_idle_anim_rng.randi_range(1,1000) > 999):
			if(backwards):
				actor.play_animation("idle", true, true)
			else:
				actor.play_animation("idle", false, true)
							
	for actor in get_tree().get_nodes_in_group("Actor"):
		if(actor.replay.size()>0):
			if(backwards && actor.id != -1): #&&  actor.global_position.is_equal_approx(actor.replay[actor.id][1])):
				#backwards = false
				#newpoint = true
				#print("id: " + str(active_burglar.id))
				#print("ticks: " + str(ticks))
				#active_burglar.currentid +=1
				#active_burglar.id += 0
				#if(actor.replay[actor.id][0] >= ticks):
					#while(actor.replay[actor.id][0] != ticks-1 && actor.id != -1):
						#actor.id -=1
						#actor.currentid -=1
				
						
				#TODO is <= correct or is == better?
				if(ticks <= actor.last_ticks && (ticks <= actor.replay[actor.id][0] -1 || actor.replay[actor.id][0] == -1)||(actor.is_guard && ((ticks%(actor.max_ticks+1) <=  actor.replay[actor.id][0] -1) || (-1 ==  actor.replay[actor.id][0])))):#(ticks == actor.replay[actor.id][0] || actor.replay[actor.id][0] == -1)

					if(actor.name == "Burglar1"):
						if(actor.id == 620):
							pass
						pass#print(actor.last_ticks)
					if(!actor.is_opening &&  !actor.is_waiting && actor.id != 0 && actor.currentid != 0):

						actor.id -= 1

						actor.currentid -= 1
	
					#else:
						#if(actor.name != "Burglar3"):
							#print("name: " + actor.name)
							#print("value at id " + str(actor.id) + ": "+ str(actor.replay[actor.id][0]))
							#print("ticks: "+ str(ticks))
							
					

	
	
	$NoiseLevelProgessBar.visible = false		
			
	for actor in get_tree().get_nodes_in_group("Actor"):
		if (actor.progress_bar.visible):
			$NoiseLevelProgessBar.visible = true
			

	if(forwards && active_burglar.id == active_burglar.maxid-1 && !play):

		was_forwards = true
		forwards = false
		pause = true
		pause_animations()
	
	for actor in get_tree().get_nodes_in_group("Actor"):
		
		if(!backwards && !actor.replay.is_empty()):
			if(typeof(actor.replay[actor.id][1]) == TYPE_VECTOR3 || actor.id == actor.maxid - 1 ):
				var found_changed_ticks = find_changed_ticks_at_current_ticks(actor)
				if(((actor.id == actor.maxid - 1 && actor.replay[actor.id][0] == -1) || (found_changed_ticks && actor.replay[actor.id][0] != actor.last_ticks)) && (actor.replay[actor.id][0] != actor.last_ticks || actor == active_burglar)):
					#print(str(found_changed_ticks) + ", " + str(actor.id) + ", " + str(actor.maxid - 1) + ", " + str(actor.replay[actor.id][0]) + ", " + str(actor.last_ticks))
					actor.last_ticks = ticks
					if(actor.replay[actor.id][0] == -1 || (found_changed_ticks && actor.replay[actor.id][0] < ticks)):
						if(!found_changed_ticks):
							actor.changed_replay_ids.append(actor.id)
						elif(actor.replay[actor.id][0] != -1 && actor.replay[actor.id][0] != ticks):
							if(actor.id != actor.maxid -1):
								actor.replay[actor.id +1][0] = ticks + actor.replay[actor.id +1][0]-actor.replay[actor.id][0]
						actor.replay[actor.id][0] = ticks
						if(actor == active_burglar && actor.id == actor.maxid - 1 ):
							if(!play && ! Global.execute_plan):
								pause_recording()
				
		if(actor.is_guard):	
			if(actor.id == actor.maxid -1 && !actor.record_guard):
				actor.id = 0
				actor.currentid = 0
			
		if(actor.is_guard && actor.id == 0 && ticks > 1 && backwards):
			actor.id = actor.maxid -1
			actor.currentid = actor.maxid -1

			#print("ticks: " + str(ticks))	
	
	
		if(active_burglar.finished_working):
			#pause
			if(!backwards && !forwards && !play):
				pause_recording()
			#REMINDER think this through
			active_burglar.finished_working = false
			
	#if(burglar_moved):

		
func print_current_position_info():
	#print("active actor: " + active_burglar.name)
	for actor in get_tree().get_nodes_in_group("Actor"):
		if(actor.name == "Burglar1"):	#|| actor.name == "Burglar4" 
			if(!pause):
				if(backwards):
					debug_file.store_line("backwards: ")
				else:
					debug_file.store_line("forwards: ")
			else:
				debug_file.store_line("pause: ")
			debug_file.store_line("name: " + actor.name + ",ticks: "+str(ticks)+ ",id: "+str(actor.id)+ ",position: " +str(actor.position) + ",is waiting: " + str(actor.is_waiting) + ", " + str(actor.replay[actor.id][2]))
			
			for interactable in get_tree().get_nodes_in_group("Interactable"):
				if(interactable.anim_player):
					if(interactable.name == "Door2"):
						debug_file.store_line(interactable.name + ": " + str(interactable.anim_player.current_animation_position))
		#print("id: " + str(active_burglar.id))
		#print("current id: " + str(active_burglar.currentid))
		#print("counter: " + str(counter))	

	
func check_and_fix_id():
	#if(active_burglar.id >= active_burglar.replay.size()):
		#active_burglar.id -= active_burglar.replay.size()-1
	if(active_burglar.id < 0):
		active_burglar.id = 0
	
	#while(active_burglar.id < ticks):
		#active_burglar.id +=1


func _on_h_slider_value_changed(value: float) -> void:
	
		
	if(burglar_switcher.shown || active_burglar.bag.shown):
		$SliderBackground/HSlider.set_value_no_signal(previous_slider_value)
		return
	#if(selected_tool):
		#$SliderBackground/HSlider.set_value_no_signal(previous_slider_value)
		#return
	
	#REMINDER HMMMM
	#if(!execute_plan && play):
		#pause_recording()
	#
	#if(abs(value - previous_slider_value) > 1):
		#if(value < previous_slider_value):
			#value = previous_slider_value - 1
		#else:
			#value = previous_slider_value + 1
		#$SliderBackground/HSlider.set_value_no_signal(value) 
		#
	change_game_speed(value)
	#if((previous_slider_value > 0 && value < 0)|| (previous_slider_value < 0 && value > 0)):
		#$SliderBackground/HSlider.value = 0
		#value = 0
	if((value < 0 && !backwards) || (value >= 0 && backwards)):
		direction_changed = true
		
		var nodes = (
		get_tree().get_nodes_in_group("Interactable")
		+ get_tree().get_nodes_in_group("Actor")
		)

		for node in nodes:
			if(node.anim_player):
				if(node.anim_player.is_active()):
					node.previous_animation_dir *= -1

	if(active_burglar.is_zoomed_onto_object):
		active_burglar.is_zoomed_onto_object = false
		for object in get_tree().get_nodes_in_group("Interactable"):
			if(object.object_type != 4):
				if(object.object_type == 0):
					get_node(str(object.get_path())+"/Door/Area3D").process_mode = Node.PROCESS_MODE_INHERIT
				elif(object.object_type == 1):
					get_node(str(object.get_path())+"/Area3D").process_mode = Node.PROCESS_MODE_INHERIT
				else:
					get_node(str(object.get_path())+"/Area3D").process_mode = Node.PROCESS_MODE_INHERIT
		camera_base.global_position = active_burglar.camera_position_before_zoom_onto_object
		camera_base.global_rotation = active_burglar.camera_rotation_before_zoom_onto_object
		spring_arm.spring_length = spring_arm_length_before_zoom_in
		active_burglar.mesh_root.visible = true
	
	#value went from negative to 0 or above
	if(value >= 0 && previous_slider_value < 0 && backwards):
		if(!Global.execute_plan):
			backwards = false
			for actor in get_tree().get_nodes_in_group("Actor"):
				actor.currentid =actor.id#+=1
				actor.id += 0
				if(actor.id <= -1):
					actor.id = 0
					actor.currentid = 0
					
					
				
	#value changed to positive 	
	if(value > 0 && previous_slider_value <= 0 && active_burglar.id != active_burglar.maxid -1):
		if(!Global.execute_plan):
			was_forwards = false
			was_backwards = false
			forwards = true
			backwards = false
			pause = false
			resume_animations()
	
	#value went from positive to 0 or below
	if(value <= 0 && previous_slider_value > 0 &&!backwards):
		if(!Global.execute_plan):
			was_forwards = true
			forwards = false
		
		

	#value changed to negative
	if(value < 0 && previous_slider_value >= 0 && !backwards && ticks > 0):
		if(!Global.execute_plan):
			was_forwards = false
			was_backwards = true
			#for actor in get_tree().get_nodes_in_group("Actor"):
				#lines changed from -2 and -1 before, introduces some bugs probably
				#actor.currentid = actor.id- 1#-=1
				#actor.id -= 1
			backwards = true
			forwards = false
			pause = false
			#for actor in get_tree().get_nodes_in_group("Actor"):
				#actor.is_waiting = false
			resume_animations()
				
	
		
	
	#if(active_burglar.id != active_burglar.maxid):
		#pause = false
		
	if(value == 0 && !Global.execute_plan && !play):
		pause_recording()
		pause_animations()
		forwards = false
		backwards = false
	
	previous_slider_value = value


func _on_play_button_button_up() -> void:
		
	if(!burglar_switcher.shown):
		#REMINDER I just changed this first line an kept the rest the same, so didn't think this through yet
		play = !play
		pause = false
		was_backwards = false
		was_forwards = false


func _on_pause_button_button_up() -> void:
	
	if(!burglar_switcher.shown):
		recording = !recording
		
		if(!recording):
			$PauseButton.set_button_icon(load("res://assets/Textures/GUI/Record_Button.png"))
			pause_recording()
		else:
			$PauseButton.set_button_icon(load("res://assets/Textures/GUI/Pause_Button.png"))
	

func pause_recording():
	if(play_until_ticks == -1):
		if(!Global.execute_plan):
			play = false
			pause = true
			pause_animations()
				
func rotate_actor(actor,offset):	
	offset.y = 0

	if(not get_node(actor.name + "/Robot").global_position.is_equal_approx(get_node(actor.name + "/Robot").global_position - offset)):
		actor.mesh_root.look_at(actor.mesh_root.global_position + offset, Vector3.UP)
			
func check_if_door_is_being_walked_through_backwards():
	pass

func pause_animations():
	
	var nodes = (
	get_tree().get_nodes_in_group("Interactable")
	+ get_tree().get_nodes_in_group("Actor")
	)

	for node in nodes:
		if(node.anim_player):
			if(node.anim_player.get_playing_speed() != 0.0):
				node.previous_animation_speed = node.anim_player.get_playing_speed()
				node.anim_player.pause()
			
func resume_animations():
	
	var nodes = (
	get_tree().get_nodes_in_group("Interactable")
	+ get_tree().get_nodes_in_group("Actor")
	)
	
	for node in nodes:
		if(node.anim_player):
			if(node.previous_animation_position == node.anim_player.current_animation_position && node.anim_player.is_animation_active() && node.anim_player.current_animation_position != 0.0 && node.anim_player.current_animation_position != node.current_animation_clip_length && node.current_animation_clip != ""):#&& !node.anim_player.is_playing()
				if(!backwards):
					#var play_backwards = false if node.previous_animation_dir > 0 else true
					if (node.previous_animation_dir > 0):
						node.play_animation(node.current_animation_clip, false, true)
					elif(node.previous_animation_dir < 0):
						node.play_animation(node.current_animation_clip, true, true) #node.anim_player.play("Action",-1,1,backwards)
				#FIXME this is not working currently when alternatign between forwards and backwards play the animation doesn't always play in the correct direction, this is why the door also doesn't play the animation when opening backwards
				#if(node.previous_animation_position < node.anim_player.current_animation_position):
				#print("sign = " + str(sign(node.previous_animation_speed)))
				else:
					#var play_backwards = false if node.previous_animation_dir > 0 else true
					if (node.previous_animation_dir > 0):
						node.play_animation(node.current_animation_clip, false, true)
					elif(node.previous_animation_dir < 0):
						node.play_animation(node.current_animation_clip, true, true) #node.anim_player.play("Action",-1,1,backwards)	
					#else:
						#node.play_animation("Action", true)
				#else:
					#if(node.previous_animation_position < node.anim_player.current_animation_position):
						#node.play_animation("Action", false)
					#else:
						#node.play_animation("Action", true)
				#else:
					#node.play_animation("Action", true)
					
func push_ticks_forward_while_waiting(actor):
	for i in range(actor.replay.size()-1-actor.id):
			##actor.change_ticks = true
			actor.replay[actor.id+i][0] += 1
			
func check_if_there_are_last_ticks_in_the_future_infront(actor):
	for i in range(actor.last_ticks.size()-1, -1,-1):
		if(actor.last_ticks[i] > ticks):
			actor.last_ticks.remove_at(i)
			actor.last_ticks_index -= 1

func caught(message):
	caught_message = message
	if(typeof(caught_message)!= TYPE_BOOL):
		if(previous_caught_message != caught_message):
			print(caught_message) 
		was_caught = true
		previous_caught_message = caught_message

func check_success():
	var all_burglars_are_in_car = true
	for actor in get_tree().get_nodes_in_group("Actor"):
		if(!actor.is_guard):
			if(!actor.replay.is_empty()):
				if(!actor.replay[actor.id][2] == "moveinsidecar"):
					all_burglars_are_in_car = false
			else:
				all_burglars_are_in_car = false
					
	if(all_burglars_are_in_car && cash >= min_loot):
		was_success = true
		print_caught_message("you won!")
		play_music("res://assets/Clou original files/Audio/SFX/Sfx_Burglary_Success.wav")
		
func enable_spring_arm():
	spring_arm.collision_mask = 1|2
	
func disable_spring_arm():
	spring_arm.collision_mask = 32

func update_interactables(delta):	
	
	var nodes = (
	get_tree().get_nodes_in_group("Interactable")
	+ get_tree().get_nodes_in_group("Actor")
	)	
	for node in nodes:
		if(node.anim_player):
			if(node.anim_player.is_playing()):
				if(get_node("/root/Control").backwards):
					#REMINDER this and line 1421 is work in progress, maybe the logic is not correct
					#if(node.previous_animation_dir > 0):
						#if(node.anim_player.current_animation_position == node.current_animation_clip_length):
							#node.anim_player.advance(node.animation_rest_time)
						#else:
							#node.anim_player.advance(1.0/node.opening_time)
					#elif(node.previous_animation_dir < 0):
					if(node.is_in_group("Actor")):
						if(node.current_animation_clip == "move"):
							node.anim_player.advance(delta)
						else:
							node.anim_player.advance(delta)
					else:
						node.anim_player.advance(delta)
					#REMINDER this fixes an issue, but maybe it causes others
					if(node.anim_player.current_animation_position == node.current_animation_clip_length):
						node.anim_player.pause()
				else:
					#if(node.previous_animation_dir < 0):
						#if(node.anim_player.current_animation_position == node.current_animation_clip_length):
							#node.anim_player.advance(node.animation_rest_time)
						#else:
							#node.anim_player.advance(1.0/node.opening_time)
					#elif(node.previous_animation_dir > 0):
					if(node.is_in_group("Actor")):
						if(node.current_animation_clip == "move"):
							node.anim_player.advance(delta)
						else:
							node.anim_player.advance(delta)
					else:
						node.anim_player.advance(delta)
	
		#if(node.was_opened_by_burglar):
			#print(active_burglar.name + " waiting at position " + str(active_burglar.global_position) + ", id: " + str(active_burglar.id))
			#print(node.name + ", ticks: " + str(ticks) + ", anim position: " + str(node.anim_player.current_animation_position) + " with slider value: " + str(previous_slider_value))
	
		if(node.is_in_group("Interactable")):
			node.update_interactable(delta)
				
		
				#REMINDER think about the addition of *actual_timescale here
				#node.previous_animation_dir = (node.anim_player.current_animation_position - node.previous_animation_position)*actual_timescale #get_node("/root/Control").actual_timescale  * anim_player.get_playing_speed()

func print_caught_message(message):
	if(!backwards):
		if(message):
			caught(message)
			if(Global.execute_plan):
				$CaughtMessage.visible = true
				$CaughtMessage.text = message
				play_music("res://assets/Clou original files/Audio/SFX/Sfx_Alarm_Siren.wav")
				get_tree().paused = true
				

func change_game_speed(value: float):	
	if(value != 0):
		#for i in range (0,abs(previous_slider_value),+1):	
		#TODO think about "<0", is this correct or should it be "<=" maybe?
		if(Global.execute_plan && floor(value) <=0):
			actual_timescale = 1.0
			Engine.time_scale = 1.0
		else:
			actual_timescale = floor(value)
			Engine.time_scale = max(1.0,abs(floor(value)))
			timescale = Engine.time_scale
		Engine.physics_ticks_per_second = engine_speed * Engine.time_scale
	else:
		actual_timescale = 1.0
		Engine.time_scale = 1.0
		Engine.physics_ticks_per_second = engine_speed * Engine.time_scale
		
func is_waiting(actor:Node3D):
	var actual_ticks = ticks
	#if (!backwards):
		#actual_ticks += 1
	#else:
		#actual_ticks -= 1
	if(actor.waiting_positions.size() > 0):
		var found_waiting_position = false
		for i in range(0,actual_ticks):
			if(i == actor.waiting_positions.size()):
				break
			#REMINDER changed from ticks + 2
			if(actor.waiting_positions[i][0] == actual_ticks):
				found_waiting_position = true
		if(!found_waiting_position):
			return false
		else:
			return true

func switch_to_actor(index: int):

	if(selected_tool):
		selected_tool.visible = false
		selected_tool.area.process_mode = ProcessMode.PROCESS_MODE_INHERIT
		selected_tool = null
	
	if(!Global.execute_plan):
		play = false
		pause = true
		pause_animations()
	var child_node = get_node(active_burglar.name + "/CameraBase")
	active_burglar.remove_child(child_node)
	active_burglar_index = index
	if(active_burglar_index > number_of_burglars+number_of_guards):
		active_burglar_index = 1
		
	if((guards_are_recording || debug_mode) && active_burglar_index > number_of_burglars):
		while(!get_node("Burglar"+str(active_burglar_index)).record_guard && !debug_mode):
			active_burglar_index += 1
	else:
		if(active_burglar_index > number_of_burglars):
			active_burglar_index = 1
	active_burglar = get_node("Burglar"+str(active_burglar_index))
	active_burglar.add_child(child_node)
	_camera = get_node(active_burglar.name+"/CameraBase/SpringArm3D/Camera3D")
	
	floor_visibility_check.change_visibility(active_burglar, false)
	if(active_burglar.inside):
		disable_spring_arm()
	else:
		enable_spring_arm()		


func _on_skip_to_start_button_button_up() -> void:
	if(pause && !burglar_switcher.shown):
		_on_h_slider_value_changed(-100.0)
		play_until_ticks = 0
		RenderingServer.render_loop_enabled = false
		#skip_to_start_or_end = true

func _on_skip_to_end_button_button_up() -> void:
	if(active_burglar.id != active_burglar.maxid -1 && active_burglar.maxid != 0  && pause && !burglar_switcher.shown):
		if(active_burglar.replay[active_burglar.replay.size()-1][0] != -1):
			_on_play_button_button_up()
			_on_h_slider_value_changed(100.0)
			play_until_ticks = active_burglar.replay[active_burglar.replay.size()-1][0]
			RenderingServer.render_loop_enabled = false
	#skip_to_start_or_end = true


func _on_skip_to_previous_action_button_button_up() -> void:
	if(active_burglar.id != 0  && pause && !burglar_switcher.shown):
		_on_h_slider_value_changed(-100.0)
		for i in range(active_burglar.id -1, -1, -1):
			if(active_burglar.replay[i][0] != -1  && i != active_burglar.id - 1):
				play_until_ticks = active_burglar.replay[i][0]
				RenderingServer.render_loop_enabled = false
				break
		#skip_to_start_or_end = true


func _on_skip_to_next_action_button_button_up() -> void:
	if(active_burglar.id != active_burglar.maxid -1 && active_burglar.maxid != 0 && pause && !burglar_switcher.shown):
		_on_play_button_button_up()
		_on_h_slider_value_changed(100.0)
		for i in range(active_burglar.id + 1, active_burglar.maxid, 1):
			if(active_burglar.replay[i][0] != -1 && i != active_burglar.id + 1):
				play_until_ticks = active_burglar.replay[i][0]
				RenderingServer.render_loop_enabled = false
				break
		#skip_to_start_or_end = true

func find_changed_ticks_at_current_ticks(actor:Node3D):
	if(!actor.replay.is_empty()):
		for id in actor.changed_replay_ids:
			if(id == actor.id && actor.replay):
				return true
		return false


func _on_load_plan_button_up() -> void:
	get_tree().paused = false
	Global.load_replay = true
	Global.execute_plan = false
	get_tree().reload_current_scene()
	
func _on_execute_plan_button_up() -> void:
	get_tree().paused = false
	Global.execute_plan = true
	Global.load_replay = false
	get_tree().reload_current_scene()

func _on_restart_mission_button_up() -> void:
	get_tree().paused = false
	Global.load_replay = false
	Global.execute_plan = false
	get_tree().reload_current_scene()

func _on_quit_mission_button_up() -> void:
	if(!Global.execute_plan):
		$PauseMenu/QuitMission/QuitMissionConfirmationDialog.visible = true
	else:
		quit_plan()
	
func _on_quit_mission_confirmation_dialog_confirmed_button_up():
	_on_save_plan_button_up()	
	quit_plan()

func _on_quit_mission_confirmation_dialog_canceled_button_up():
	quit_plan()
	
func _on_save_plan_button_up() -> void:
	for actor in get_tree().get_nodes_in_group("Actor"):
		if(!actor.is_guard && !guards_are_recording):
			actor.save_replay()
		elif(actor.is_guard && actor.record_guard):
			actor.save_replay()

func _on_close_mission_menu_button_up() -> void:
	$PauseMenu.visible = false
	get_tree().paused = false
		
func quit_plan():
	debug_file.close()
	get_tree().quit()
	
func _on_bag_button_up() -> void:
	
	if(burglar_switcher.shown):
		return
	
	var vertical_cell_size = 128
	var horizontal_cell_size = 256
	var index = 0
	if(active_burglar.bag.process_mode == PROCESS_MODE_DISABLED):
		active_burglar.bag.process_mode = PROCESS_MODE_INHERIT
		active_burglar.bag.mouse_filter = SubViewportContainer.MOUSE_FILTER_STOP
	else:
		active_burglar.bag.process_mode = PROCESS_MODE_DISABLED
		active_burglar.bag.mouse_filter = SubViewportContainer.MOUSE_FILTER_IGNORE
	if(!active_burglar.bag.shown):
		if(selected_tool):
			selected_tool.visible = false
			selected_tool.area.process_mode = ProcessMode.PROCESS_MODE_INHERIT
		selected_tool = null
	active_burglar.bag.shown = !active_burglar.bag.shown
	
	var total_width = 4
	
	for c in active_burglar.bag.get_child(0).get_child(0).get_children():
		if(c != selected_tool && c.is_in_group("Item")):
			var spacing: float = 1.5
			var start_offset = -total_width

			# Calculate the current item's distance from the center
			var horizontal_distance = start_offset + (index%6 * spacing)
			c.global_position = Vector3(horizontal_distance / 1.75,1.1+ -1.0 * floor(index/6),-2.5)
			c.global_rotation = Vector3.ZERO
			#c.global_rotation.z = deg_to_rad(-5)
			c.visible = !c.visible
			index += 1
		elif(!c.is_in_group("Item")):
			c.global_position = Vector3(0.0,0.0, -3.5)
			#c.global_rotation = _camera.global_rotation
			c.visible = !c.visible
		


func _on_burglar_switcher_button_up() -> void:
	
	if(active_burglar.bag.shown):
		return
	
	if(recording):
		_on_pause_button_button_up()
		
	var index = 0
	
	if(burglar_switcher.process_mode == PROCESS_MODE_DISABLED):
		burglar_switcher.process_mode = PROCESS_MODE_INHERIT
		burglar_switcher.mouse_filter = SubViewportContainer.MOUSE_FILTER_STOP
	else:
		burglar_switcher.process_mode = PROCESS_MODE_DISABLED
		burglar_switcher.mouse_filter = SubViewportContainer.MOUSE_FILTER_IGNORE
		
	burglar_switcher.shown = !burglar_switcher.shown

	# 1. Get the camera component
	var cam = get_viewport().get_camera_3d()
	# 2. Get screen-aligned directions (Right and Forward relative to the player's view)
	var cam_right = cam.global_transform.basis.x.normalized()
	var cam_up = cam.global_transform.basis.y.normalized()
	var cam_forward = cam.global_transform.basis.z.normalized()
	

	# 3. Calculate the center anchor point in world space
	#var center_anchor = cam.project_position(burglar_switcher.get_child(0).position, 5.5)

	var spacing: float = 1.5 
	var total_width = (burglar_switcher.get_child(0).get_child(0).get_child_count() - 2) * spacing

	for c in burglar_switcher.get_child(0).get_child(0).get_children():
		if(c.is_in_group("burglar_in_burglar_switcher")):
			var start_offset = -total_width / 2.0

			# Calculate the current item's distance from the center
			var horizontal_distance = start_offset + (index * spacing)

			# 4. Use global_position and offset it along the camera's local axes
			# Push along cam_right for horizontal spacing, and slightly along cam_forward to prevent clipping
			#c.global_position = center_anchor + (cam_right * horizontal_distance) + (cam_forward * 0.5) + cam_up
			c.position = Vector3(horizontal_distance, -0.5, -1.0)
			#c.global_rotation = _camera.global_rotation
			index += 1
		else:
			# Use the same anchor point for the background/quad elements
			c.global_position = Vector3(0.0, 0.0, -1.5)
			#c.global_rotation = _camera.global_rotation
			c.scale.x = total_width * 1.5
				
		c.visible = !c.visible

func play_music(name: String):
	audio_player.stream = load(name)
	audio_player.play()

func object_occupied(actor:Node3D, object):
	if(object):
		for other in get_tree().get_nodes_in_group("Actor"):
			if(other != actor):
				if(other.object_that_is_being_interacted_with == object):
					return true
	return false

func replay_backwards(actor:Node3D):
	var offset:Vector3
	var found_door_or_window := false
	var found_window := false
	var window_is_occupied := false
	var found_waiting_position := false
	if((typeof(actor.replay[actor.id][1]) == TYPE_STRING || typeof(actor.replay[actor.id][1]) == TYPE_STRING_NAME) && (ticks <= actor.replay[actor.id][0] || actor.replay[actor.id][0] == -1)): 
		if(actor.replay[actor.id][2] == "use"):
			if(object_occupied(actor, get_node(str(actor.replay[actor.id][1])))):
				actor.object_that_is_being_interacted_with = null
			else:
				actor.object_that_is_being_interacted_with = get_node(str(actor.replay[actor.id][1]))
			#get_node(str(actor.replay[actor.id][1])).anim_player.current_animation = "Action"
			if(actor.replay[actor.id][3]== "last" && get_node(str(actor.replay[actor.id][1])).anim_player.current_animation_position == get_node(str(actor.replay[actor.id][1])).current_animation_clip_length):
				get_node(str(actor.replay[actor.id][1])).play_animation(get_node(str(actor.replay[actor.id][1])).animation_name, true, true)
			elif(actor.replay[actor.id][3]== "last" && get_node(str(actor.replay[actor.id][1])).anim_player.current_animation_position == 0.0):
				get_node(str(actor.replay[actor.id][1])).play_animation(get_node(str(actor.replay[actor.id][1])).animation_name, false, true)
			if(actor.replay[actor.id][3] == "last"):
				if(actor.replay[actor.id][0] == ticks + 1 or actor.replay[actor.id][0] == -1):
					get_node(str(actor.replay[actor.id][1])).append_switch_timer(ticks)
					for related_object in get_node(str(actor.replay[actor.id][1])).related_objects:
						#is camera or light barrier
						if(related_object.object_type == 7):
							related_object.toggle_power_state()
						#is alarm
						if(related_object.object_type == 8):
							related_object.is_off = false	
		if(actor.replay[actor.id][2]== "takeend"):
			if(!get_node(str(actor.replay[actor.id][1])).visible):
				get_node(str(actor.replay[actor.id][1])).process_mode = Node.PROCESS_MODE_ALWAYS
				get_node(str(actor.replay[actor.id][1])).visible = true
				cash -= get_node(str(actor.replay[actor.id][1])).value
				actor.current_carrying_weight -= get_node(str(actor.replay[actor.id][1])).weight
				actor.bag.get_child(0).get_child(0).remove_child(actor.bag.get_child(0).get_child(0).get_child(actor.bag.get_child(0).get_child(0).get_child_count()-1))
				selected_car.current_load -= get_node(str(actor.replay[actor.id][1])).weight
		else:
			var object:Node3D
			object = get_node(str(actor.replay[actor.id][1]))
			offset = actor.global_position - get_node(str(actor.replay[actor.id][1])).global_position
			rotate_actor(actor,offset)
			#if(object.lock_type != 3):
			if(!object_occupied(actor, object)):
				if(actor.is_waiting):
					actor.is_waiting = false
					#REMINDER I disabled this without testing, maybe it is needed
					#actor.id += 1
					#actor.currentid = actor.id +1
				if(actor.replay[actor.id][2] == "break"):
					var tool = get_node(actor.name+tool_path+str(actor.replay[actor.id][4]))
					if(tool.tool_efficencies[object.lock_type]):
						if(object.damage == 0):
							actor.finished_working = true
							actor.progress_bar.visible = false
						else:
							actor.finished_working = false
						if(!actor.finished_working):
							if(!object_occupied(actor, object)):
								actor.object_that_is_being_interacted_with = object
							else:
								actor.object_that_is_being_interacted_with = null
								
							actor.progress_bar.visible = true
							var guard_that_hears_the_most:Node3D
							for guard in get_tree().get_nodes_in_group("Actor"):
								if (guard.is_guard):
									var loudness = (10000.0/((guard.global_position.distance_to(object.global_position))* (1.0/guard.hearing)))* (tool.loudness[object.object_material]/100.0)
									if(loudness > max_loudness):
										max_loudness = loudness
										guard_that_hears_the_most = guard				
									$NoiseLevelProgessBar.value = max_loudness
									
							if($NoiseLevelProgessBar.value > noise_threshold):
								$NoiseLevelProgessBar.get("theme_override_styles/fill").bg_color = Color(1,0,0)
							else:
								$NoiseLevelProgessBar.get("theme_override_styles/fill").bg_color = Color(0,1,0)
							#TODO do this stuff
							#var guard_that_hears_the_most:Node3D
							actor.progress_bar.value = object.damage
							object.damage -= actor.replay[actor.id][3]
							if(object.damage <= 0):
								object.damage = 0
								object.damaged = false
							actor.progress_bar.value = object.damage
							#print("backwards, actor.progress_bar.value: " +str(actor.progress_bar.value)+" at id" + str(actor.id) + " at ticks" + str(ticks))
					else: 
						actor.show_text_bubble("That won't work")
				elif(actor.replay[actor.id][2] == "open"):
					#TODO I disabled most of this, is this a good idea?
					if(object_occupied(actor, object) && (object.anim_player.current_animation_position != 0.0 && object.anim_player.current_animation_position != object.current_animation_clip_length)):
						actor.object_that_is_being_interacted_with = null
						actor.show_text_bubble("someone is already working here!")
					else:
						actor.object_that_is_being_interacted_with = object
					#get_node(str(actor.replay[actor.id][1])).anim_player.current_animation = "Action"
					#TODO ??? why does it check for object type 1 and 2, I added to allow it when going through windows from the inside, does it work?
						if(get_node(str(actor.replay[actor.id][1])).damage == object_durability || actor.is_guard): #&& get_node(str(actor.replay[actor.id][1])).object_type != 0 &&get_node(str(actor.replay[actor.id][1])).object_type != 1):
							if(actor.replay[actor.id][3]== "last" && get_node(str(actor.replay[actor.id][1])).anim_player.current_animation_position == 0.0):#if(get_node(str(actor.replay[actor.id][1])).anim_player.is_playing()): 
								get_node(str(actor.replay[actor.id][1])).play_animation(get_node(str(actor.replay[actor.id][1])).animation_name, false, true)
							elif(actor.replay[actor.id][3]== "last"):
								if(get_node(str(actor.replay[actor.id][1])).object_type != 0):
									get_node(str(actor.replay[actor.id][1])).play_animation(get_node(str(actor.replay[actor.id][1])).animation_name, true, true)
						#REMINDER what is this for?
						elif(get_node(str(actor.replay[actor.id][1])).damage != object_durability && !(get_node(str(actor.replay[actor.id][1])).object_type == 1 && actor.inside)):
							actor.show_text_bubble("the object is locked!")
						#get_node(str(actor.replay[actor.id][1])).anim_player.advance(-delta)
				#actor.is_opening = true
	elif(typeof(actor.replay[actor.id][1]) == TYPE_VECTOR3):
		
				
		if(actor.replay[actor.id][2] != "moveinsidecar"):
			actor.mesh_root.visible = true
				
		if(actor.replay[actor.id][2] == "movethroughwindow"):
			found_window = true
			var found_object = get_node(str(actor.replay[actor.id][3]))
			if(actor.id == actor.maxid-1):
				actor.object_that_is_being_interacted_with = null
			elif(actor.replay[actor.id + 1][2] != "movethroughwindow"):
				actor.object_that_is_being_interacted_with = null
			else:
				if(!object_occupied(actor, found_object)):
					actor.object_that_is_being_interacted_with = found_object
				else:
					actor.object_that_is_being_interacted_with = null
		else:
			actor.object_that_is_being_interacted_with = null
		
		actor.text_bubble.visible = false
		#REMINDER I commented this out, dunno if it is needed
		#if(actor.is_waiting):
			#actor.is_waiting = false
			#actor.id -=1
			#actor.currentid = actor.id- 1
		actor.finished_working = false
		#actor.is_opening = false
		
		
		for i in range(actor.id, 0, -1):
			if(typeof(actor.replay[i][1]) == TYPE_VECTOR3):
				if(!(actor.global_position.is_equal_approx(actor.replay[i][1]))):
					offset = actor.replay[i][1] - actor.mesh_root.global_position
					break
			else:
				offset = actor.replay[actor.id][1] - actor.mesh_root.global_position
				break
		
		var move = true
		var space_state = get_world_3d().direct_space_state
		
		var query:PhysicsRayQueryParameters3D
		
		var found_index = -1
		
		if(actor.id != actor.replay.size()-1):
			#if(typeof(actor.replay[actor.id+1][1]) == TYPE_VECTOR3):
			if(actor.waiting_positions.size() > 0):
				for i in range(0,ticks):
					if(i == actor.waiting_positions.size()):
						break
					#REMINDER changed from ticks + 2
					if(actor.waiting_positions[i][0] == ticks):
						found_waiting_position = true
						found_index = i
				if(found_waiting_position):
					#query = PhysicsRayQueryParameters3D.create(actor.global_position,actor.replay[actor.id+1][1])
					#query.collide_with_areas = true
					#for a in get_tree().get_nodes_in_group("Actor"):
						#query.exclude = [a]
					#query.set_collide_with_bodies(false)
					found_door_or_window = true								
					#print(backwards)
					#print("found door at " + str(ticks) + " ticks" + "\n" + " while on position " +  str(actor.global_position))
						
						
				
		actor.ray.force_raycast_update()
		#var result = space_state.intersect_ray(query)#actor.ray.get_collider()	
		#if(result):
			##TODO currently it seems like actors arent correctly filtered out, so this might block the door from being detected in some cases
			#if(result.collider.get_parent().get_parent().is_in_group("Interactable")):
				#if(result.collider.get_parent().get_parent().is_breakable && result.collider.get_parent().get_parent().object_type == 0):
					#found_door_or_window = true
		if(found_door_or_window):
			if(actor.waiting_positions.size() > 0):
				var object_being_waited_for = get_node(actor.waiting_positions[found_index][1])
				if((object_being_waited_for.damage == object_durability && !actor.is_guard) || (actor.is_guard && !object_being_waited_for.was_opened_by_burglar)):
					#if(get_node(actor.waiting_positions[actor.waiting_positions.size()-1][1]).anim_player.current_animation_position != 0 && get_node(actor.waiting_positions[actor.waiting_positions.size()-1][1]).anim_player.is_playing):
					#actor.is_opening = true
					if(actor.waiting_positions.size()> 0):
						actor.is_waiting = true
						move = false
						#print("waiting...\n")
					actor.waiting_positions.pop_back()
					#debug_file.store_line(str(ticks) + " ," + str(backwards))
				
					#FIXME this was not thought through
					
		
		if(move):	
			if(actor.is_waiting):
				actor.is_waiting = false
				#actor.id -=1
				#actor.currentid = actor.id- 1
			#actor.is_opening = false
			actor.is_opening = false		
			actor.global_position = actor.replay[actor.id][1]
			rotate_actor(actor,offset)
		actor.progress_bar.visible = false
		#$NoiseLevelProgessBar.visible = false
	

		
	if(actor.anim_player):	
		if(!actor.replay.is_empty()):
			if(!(ticks != actor.replay[actor.id][0] && actor.replay[actor.id][0] != -1)):
				if(!pause):
					actor.previous_animation_position = actor.anim_player.current_animation_position
					var play_open_anim := false
					if(found_door_or_window):
						if(found_window and get_node(actor.replay[actor.id][3]).anim_player.current_animation_position != get_node(actor.replay[actor.id][3]).current_animation_clip_length):
							play_open_anim = true
						elif(!found_window  and get_node(actor.replay[actor.id][1].anim_player).current_animation_position != get_node(actor.replay[actor.id][1]).current_animation_clip_length):
							play_open_anim = true
					if(play_open_anim):
						actor.play_animation("open", true, true)
					else:
						if(found_waiting_position):
							actor.play_animation("idle", true, true)
						else:
							actor.play_animation(actor.replay[actor.id][2], true, true)

	
func replay_forwards(actor:Node3D):
	var offset:Vector3
	var found_door_or_window := false
	var found_window := false
	var window_is_occupied := false
	if((typeof(actor.replay[actor.id][1]) == TYPE_STRING ||typeof(actor.replay[actor.id][1]) == TYPE_STRING_NAME) && (ticks >= actor.replay[actor.id][0] || actor.replay[actor.id][0] == -1)):
		var object = get_node(str(actor.replay[actor.id][1]))
		if(actor.replay[actor.id][2] == "use"):
			if(object_occupied(actor, object)):
				actor.object_that_is_being_interacted_with = null
			else:
				actor.object_that_is_being_interacted_with = object
				if(actor.replay[actor.id][3]== "first" && object.anim_player.current_animation_position == 0.0):
					object.play_animation(object.animation_name, false, true)
					#get_node(str(actor.replay[actor.id][1])).append_door_opening("forwards")
				if(actor.replay[actor.id][3]== "first" && object.anim_player.current_animation_position == object.current_animation_clip_length):
						object.play_animation(object.animation_name, true, true)
				if(actor.replay[actor.id][3]== "last"):
					if(actor.replay[actor.id][0] == ticks or actor.replay[actor.id][0] == -1):
						object.append_switch_timer(ticks)
						for related_object in object.related_objects:
							#is camera or light barrier
							if(related_object.object_type == 7):
								related_object.toggle_power_state()
							#is alarm
							if(related_object.object_type == 8):
								related_object.is_off = true	
						#get_node(str(actor.replay[actor.id][1])).append_door_opening("backwards")		
		if(actor.replay[actor.id][2] == "takeend"):
			var can_pick_up = true
			if(!get_node(str(actor.replay[actor.id][1])).visible):
				can_pick_up = false
				#actor.show_text_bubble("someone already picked it up")
			if((actor.current_carrying_weight + get_node(str(actor.replay[actor.id][1])).weight) > actor.max_capacity):
				can_pick_up = false
				if(get_node(str(actor.replay[actor.id][1])).visible):
					actor.show_text_bubble("it doesn't fit in my bag anymore")
			if((selected_car.current_load + get_node(str(actor.replay[actor.id][1])).weight) > selected_car.max_capacity):
				can_pick_up = false
				if(get_node(str(actor.replay[actor.id][1])).visible):
					actor.show_text_bubble("it doesn't fit in the car anymore")
			if(can_pick_up):
				cash += get_node(str(actor.replay[actor.id][1])).value
				actor.current_carrying_weight += get_node(str(actor.replay[actor.id][1])).weight
				selected_car.current_load += get_node(str(actor.replay[actor.id][1])).weight
				get_node(str(actor.replay[actor.id][1])).visible = false
				create_item_from_interactable(get_node(str(actor.replay[actor.id][1])), actor)
				get_node(str(actor.replay[actor.id][1])).process_mode = Node.PROCESS_MODE_DISABLED
				
		else:
		#FIXME this needs to be changed for loot as it is can be a child of interactables
			object = get_node(str(actor.replay[actor.id][1]))
			offset = actor.global_position - object.global_position
			rotate_actor(actor, offset)
			if(true):#object.lock_type != 3):
				if(actor.replay[actor.id][2] == "break"):
					var tool = get_node(actor.name+tool_path+str(actor.replay[actor.id][4]))
					#if tool efficiency is not 0 for this object
					if(tool.tool_efficencies[object.lock_type]):
						for alarm in get_tree().get_nodes_in_group("Alarm"):
							if(alarm.damage != object_durability && !alarm.is_off):
								for obj_path in alarm.related_objects_string_array:
									if(str(obj_path) == str(actor.replay[actor.id][1])):
										print_caught_message("caught by " +alarm.name)
						if(!object_occupied(actor, object) && object.damage != object_durability):
							actor.finished_working = false
							if(!actor.finished_working):
								if(!object_occupied(actor, object)):
									actor.object_that_is_being_interacted_with = object
								else:
									actor.is_waiting = true
									actor.object_that_is_being_interacted_with = null
								
								#TODO this has to probably be adjusted for multiple burglars, so that the actual loudest value is shown
								actor.progress_bar.visible = true
								var guard_that_hears_the_most:Node3D
								for guard in get_tree().get_nodes_in_group("Actor"):
									if (guard.is_guard):
										var loudness = (10000.0/((guard.global_position.distance_to(object.global_position))* (1.0/guard.hearing)))* (tool.loudness[object.object_material]/100.0)
										if(loudness > max_loudness):
											max_loudness = loudness
											guard_that_hears_the_most = guard	
														
										$NoiseLevelProgessBar.value = max_loudness
											
								if($NoiseLevelProgessBar.value > noise_threshold):
									if(guard_that_hears_the_most):
										$NoiseLevelProgessBar.get("theme_override_styles/fill").bg_color = Color(1,0,0)
										print_caught_message("you have been heard by " + guard_that_hears_the_most.unique_name + " at " + $TimerLabel.get_time_as_string())
								else:
									$NoiseLevelProgessBar.get("theme_override_styles/fill").bg_color = Color(0,1,0)
								actor.progress_bar.value = object.damage
								object.damage += actor.replay[actor.id][3]
								object.damaged = get_node(actor.name+tool_path+str(actor.replay[actor.id][4])).damaging	
								if(object.damage > object_durability):
									object.damage = object_durability
								actor.progress_bar.value = object.damage
								#print("forwards, actor.progress_bar.value: " +str(actor.progress_bar.value)+" at id" + str(actor.id) + " at ticks" + str(ticks))
								if(actor.progress_bar.value == object_durability):
									actor.progress_bar.visible = false
						else:
							if(object.damage != object_durability):
								actor.show_text_bubble("someone is already working here!")
							else:
								actor.finished_working = true
							#for i in range(actor.replay.size()-1-actor.id):
								###actor.change_ticks = true
								#actor.replay[actor.id+i][0] += 1
					else:
						actor.show_text_bubble("That won't work")
				#TODO this is currently skipped, aka the first tick is skipped
				elif(actor.replay[actor.id][2] == "open"):
					if(get_node(str(actor.replay[actor.id][1])).damage == 10000 || actor.is_guard || (get_node(str(actor.replay[actor.id][1])).object_type == 1 && actor.inside)):
						#get_node(str(actor.replay[actor.id][1])).anim_player.current_animation = "Action"
						if(object_occupied(actor,object) && (object.anim_player.current_animation_position != 0.0 && object.anim_player.current_animation_position != object.current_animation_clip_length)):
							actor.object_that_is_being_interacted_with = null
						else:
							actor.object_that_is_being_interacted_with = object 
							if(actor.replay[actor.id][3]== "first" && get_node(str(actor.replay[actor.id][1])).anim_player.current_animation_position == 0.0):
								object.play_animation(object.animation_name, false, true)
								if(!actor.is_guard):
									get_node(str(actor.replay[actor.id][1])).was_opened_by_burglar = true
								else:
									get_node(str(actor.replay[actor.id][1])).was_opened_by_burglar = false
								#get_node(str(actor.replay[actor.id][1])).append_door_opening("forwards")
							#TODO add object closing when open
							elif(actor.replay[actor.id][3]== "first" && get_node(str(actor.replay[actor.id][1])).anim_player.current_animation_position == get_node(str(actor.replay[actor.id][1])).current_animation_clip_length && (get_node(str(actor.replay[actor.id][1])).object_type == 0 || get_node(str(actor.replay[actor.id][1])).object_type == 3)):
									get_node(str(actor.replay[actor.id][1])).play_animation(get_node(str(actor.replay[actor.id][1])).animation_name, true, true)
									#get_node(str(actor.replay[actor.id][1])).append_door_opening("backwards")		
							#elif(get_node(str(actor.replay[actor.id][1])).anim_player.current_animation_position == get_node(str(actor.replay[actor.id][1])).current_animation_clip_length):
						#if door is already open or being opened while trying to go trough it, delete the opening record
						#TODO this is not working currently
						#elif(is_object_occupied || get_node(str(actor.replay[actor.id][1])).anim_player.current_animation_position == get_node(str(actor.replay[actor.id][1])).current_animation_clip_length):
							#for i in range(25):
								#actor.replay.remove_at(actor.id)
							#actor.maxid -= 25
							#for i in range(actor.replay.size()-actor.id):
								##actor.replay.remove_at(actor.id+i)
								##FIXME this whole code in this section is very questionable, I didn't think about it very much
								#actor.replay[actor.id + i][0] = ticks +i +1
							#TODO this fixes some issues (the id being to low for the burglar to move) but introduces others
							#actor.id += 1
					else:
						actor.show_text_bubble("the object is locked!")
						#get_node(str(actor.replay[actor.id][1])).anim_player.advance(delta)
		
				elif(actor.replay[actor.id][2] == "inspect"):
					if(!play && !Global.load_replay && !forwards && !actor.is_guard):
						if(get_node(str(actor.replay[actor.id][1])).object_type == 4):
							actor.show_text_bubble(get_node(str(actor.replay[actor.id][1])).unique_name + "\nvalue: " + str(get_node(str(actor.replay[actor.id][1])).value) + "$" + "\nweight: " + str(get_node(str(actor.replay[actor.id][1])).weight) + "kg")
						elif(get_node(str(actor.replay[actor.id][1])).anim_player.current_animation_position == get_node(str(actor.replay[actor.id][1])).current_animation_clip_length):
							actor.is_zoomed_onto_object = true
							for obj in get_tree().get_nodes_in_group("Interactable"):
								if(obj.object_type != 4):
									if(obj.object_type == 0):
										get_node(str(obj.get_path())+"/Door/Area3D").process_mode = Node.PROCESS_MODE_DISABLED
									#elif(obj.object_type == 1):
										#get_node(obj.name+"/Area3D").process_mode = Node.PROCESS_MODE_DISABLED
									else:
										get_node(str(obj.get_path())+"/Area3D").process_mode = Node.PROCESS_MODE_DISABLED
										
							if(!camera_base.global_position.is_equal_approx(get_node(str(actor.replay[actor.id][1])).zoom_in_position.global_position)):
								actor.camera_position_before_zoom_onto_object = camera_base.global_position
								actor.camera_rotation_before_zoom_onto_object = camera_base.global_rotation
								spring_arm_length_before_zoom_in = spring_arm.spring_length
							spring_arm.spring_length = zoom_in_spring_arm_length
							camera_base.global_position = get_node(str(actor.replay[actor.id][1])).zoom_in_position.global_position
							camera_base.global_rotation = get_node(str(actor.replay[actor.id][1])).zoom_in_position.global_rotation
							active_burglar.mesh_root.visible = false
							
						else:
							actor.show_text_bubble("The object is not opened!")
					elif(actor.is_guard):
						#TODO not done, need to differnetiate two interaction types
						if(!get_node(str(actor.replay[actor.id][1])).visible):
							print_caught_message("missing object found at " + str(ticks)+" by "+ actor.unique_name)
						if(get_node(str(actor.replay[actor.id][1])).damaged):
							print_caught_message("opened object found at " + str(ticks)+" by "+ actor.unique_name)
				elif(actor.replay[actor.id][2] == "look at"):
					if(get_node(str(actor.replay[actor.id][1])).damage > 0):
							print_caught_message("damaged object found at " + str(ticks)+" by "+ actor.unique_name)
	
	elif(typeof(actor.replay[actor.id][1]) == TYPE_VECTOR3):
		
		if(actor.replay[actor.id][2] == "moveinsidecar"):
			actor.mesh_root.visible = false
		else:
			actor.mesh_root.visible = true			
		
		actor.text_bubble.visible = false
		actor.finished_working = false
		offset = actor.mesh_root.global_position - actor.replay[actor.id][1]
		
		var space_state = get_world_3d().direct_space_state
			
		var query = PhysicsRayQueryParameters3D.create(actor.global_position,actor.replay[actor.id][1])
		query.collide_with_areas = true
		for a in get_tree().get_nodes_in_group("Actor"):
			query.exclude = [a]
		#query.set_collide_with_bodies(false)
		
		var move = true
		
		var found_object:Node3D
			
		actor.ray.force_raycast_update()
		var result = space_state.intersect_ray(query)#actor.ray.get_collider()	
		
		var found_waiting_position = false
		
		var found_index = -1
		
		#for i in range(0,ticks):
			#if(i == actor.waiting_positions.size()):
				#break
			#if(actor.waiting_positions[i][0] == ticks):
				##print("found waiting position at " + str(ticks))
				#found_waiting_position = true
				#found_index = i
		
		if(result):
			#TODO currently it seems like actors arent correctly filtered out, so this might block the door from being detected in some cases
			if(result.collider.get_parent().get_parent().is_in_group("Interactable")):
				if(result.collider.get_parent().get_parent().is_breakable && result.collider.get_parent().get_parent().object_type == 0):
					found_door_or_window = true
					found_object = result.collider.get_parent().get_parent()
					#print(backwards)
					#print("found door at " + str(ticks) + " ticks" + "\n" + " while on position " + str(actor.global_position))
		
		if(found_waiting_position):
			found_door_or_window = true
			found_object = get_node(actor.waiting_positions[found_index][1])
		
		if(actor.replay[actor.id][2] == "movethroughwindow"):
			found_window = true
			found_object = get_node(str(actor.replay[actor.id][3]))
			window_is_occupied = object_occupied(actor, found_object)
			if(get_node(actor.replay[actor.id][3]).anim_player.current_animation_position != get_node(actor.replay[actor.id][3]).current_animation_clip_length || window_is_occupied):
				found_door_or_window = true

			if(actor.id == actor.maxid-1):
				actor.object_that_is_being_interacted_with = null
			elif(actor.replay[actor.id + 1][2] != "movethroughwindow"):
				actor.object_that_is_being_interacted_with = null
			else:
				if(!object_occupied(actor, found_object)):
					actor.object_that_is_being_interacted_with = found_object
				else:
					actor.object_that_is_being_interacted_with = null
		else:
			actor.object_that_is_being_interacted_with = null
		

		if(found_door_or_window):
			#print("found door at: " + str(ticks))
			var object_is_passable = false
			if(actor.is_guard):
				object_is_passable = true
			if(found_object.damage == object_durability):
				object_is_passable = true
			elif(found_object.object_type == 1):
				if(actor.replay[actor.id][4] == true):
					object_is_passable = true
				
			if(object_is_passable):							
				if((!found_object.anim_player.is_playing() && found_object.anim_player.current_animation_position != found_object.current_animation_clip_length) || found_waiting_position):
					#print("playing animation at ticks " + str(ticks) + " and id " + str(active_burglar.id))
					found_object.play_animation(found_object.animation_name, false, true)
					if(found_waiting_position):
						found_object.anim_player.seek(actor.waiting_positions[found_index][2])
					if(!actor.is_guard):
						found_object.was_opened_by_burglar = true
					else:
						found_object.was_opened_by_burglar = false
					#found_object.append_door_opening("forwards")
					#actor.is_opening = true
					actor.is_waiting = true
					#print("waiting...\n")
					var add_waiting_position = true
					for i in range(0,ticks):
						if(i == actor.waiting_positions.size()):
							break
						if(actor.waiting_positions[i][0] >= ticks%(actor.max_ticks+1)):
							add_waiting_position = false
							break
						if(actor.waiting_positions[i][0] == ticks%(actor.max_ticks+1)):
							add_waiting_position = false
					
					if (add_waiting_position):
						var array = []
						array.append(ticks)
						array.append(found_object.get_path())
						array.append(found_object.anim_player.current_animation_position)
						actor.waiting_positions.append(array.duplicate())
						#print("added waiting position for actor "+ actor.name + " while at position " + str(actor.global_position) + ", id: " + str(actor.id))
						
					move = false
					#var array = []
					#array.append(ticks)
					#array.append(actor.global_position)
					#actor.replay.insert(actor.id,array)
					#TODO need to check if the ticks have already been moved
					#TODO I commented this out to test setting it to is_waiting instead etc.
					#for i in range(actor.replay.size()-1-actor.id):
						#if(actor.replay[actor.id][0] == ticks || actor.change_ticks):
							#actor.change_ticks = true
							#actor.replay[actor.id+i][0] += 1
					#actor.maxid +=1
					#debug_file.store_line(str(ticks) + " ," + str(backwards))
					
						
				elif(found_object.anim_player.current_animation_position != found_object.current_animation_clip_length || window_is_occupied):
					#actor.is_opening = true
					#debug_file.store_line(str(ticks) + " ," + str(backwards))
					if(found_waiting_position):
						found_object.anim_player.seek(actor.waiting_positions[found_index][2])
					#var compute = true
					#if(actor.waiting_positions.size() == 0):
						#compute = true
					#if (ticks != actor.waiting_positions[actor.waiting_positions.size()-1][0]):
						#compute = true
					#for i in range(0,actor.waiting_positions.size()):
						#if(actor.waiting_positions[i][0]== ticks):
							#print("ticks at index " + str(i)+ " do already exist")
							#actor.waiting_positions.remove_at(i)
							#break
					
					var add_waiting_position = true
					for i in range(0,ticks):
						if(i == actor.waiting_positions.size()):
							break
						if(actor.waiting_positions[i][0]== ticks):
							add_waiting_position = false
					
					if (add_waiting_position):
						var array = []
						array.append(ticks)
						array.append(found_object.get_path())
						array.append(found_object.anim_player.current_animation_position)
						actor.waiting_positions.append(array.duplicate())
					
					actor.is_waiting = true
					move = false
					#var array = []
					#array.append(ticks)
					#array.append(actor.globafensterl_position)
					#actor.replay.insert(actor.id,array)
					#TODO need to check if the ticks have already been moved
					#TODO I commented this out to test setting it to is_waiting instead etc.
					#for i in range(actor.replay.size()-1-actor.id):
						#if(actor.replay[actor.id][0] == ticks || actor.change_ticks):
							#actor.change_ticks = true
							#actor.replay[actor.id+i][0] += 1
					#actor.maxid +=1
				elif(found_object.anim_player.current_animation_position == found_object.current_animation_clip_length):
					#if(actor.change_ticks):
					pass
			else:
				actor.show_text_bubble("the object is locked!")
				#push_ticks_forward_while_waiting(actor)
				move = false
				#REMINDER this is probably not optimal, but actors need to be stopped from proceeding in some cases meaning the id (index) should not change
				actor.is_waiting = true
				if(!forwards && !play):
					#REMINDER this solution is not optimal, if you go press play or fast forward and then rewind the actor will move through doors
					if(actor == active_burglar):
						pause_recording()
				#if(actor == active_burglar):
					#pause = true
					#pause_animations()
					
		
		if(move):
			if(actor.is_waiting):
				actor.is_waiting = false
				#REMINDER I disabled this without testing, maybe it is needed
				#actor.id += 1
				#actor.currentid = actor.id + 1
			if(actor.change_ticks):
				actor.change_ticks = false
				#if(!actor.is_opening):
					#actor.id +=1
					#actor.currentid = actor.id + 1
			if(actor.is_opening):
				actor.is_opening = false
				actor.id +=1
				actor.currentid = actor.id + 1
			actor.global_position = actor.replay[actor.id][1]
			rotate_actor(actor,offset)
	
		actor.progress_bar.visible = false
		#TODO how should I code this
		#$NoiseLevelProgessBar.visible = false
	
	if(actor.anim_player):	
		if(!actor.replay.is_empty()):
			if(!(ticks != actor.replay[actor.id][0] && actor.replay[actor.id][0] != -1)):
				if(!pause):
					actor.previous_animation_position = actor.anim_player.current_animation_position
					var play_open_anim := false
					if(found_door_or_window):
						if(found_window and get_node(actor.replay[actor.id][3]).anim_player.current_animation_position != get_node(actor.replay[actor.id][3]).current_animation_clip_length):
							play_open_anim = true
						elif(!found_window  and (typeof(actor.replay[actor.id][1]) == TYPE_VECTOR3 or get_node(actor.replay[actor.id][1].anim_player).current_animation_position != get_node(actor.replay[actor.id][1]).current_animation_clip_length)):
							play_open_anim = true
					if(play_open_anim):
						actor.play_animation("open", false, true)
					else:
						if(window_is_occupied):
							actor.play_animation("idle", false, true)
						else:
							actor.play_animation(actor.replay[actor.id][2], false, true)
		
func create_item_from_interactable(interactable:Node3D, actor:Node3D):
	
			var item = interactable.duplicate()
			for c in item.get_all_children(item):
				if(c is MeshInstance3D):
					c.layers = 1 << 2 | 1
				if(c is StaticBody3D):
					item.remove_child(c)
			item.set_script(load("res://assets/Scenes/Items/item.gd"))
			item.remove_from_group("Interactable")
			item.add_to_group("Item")
			item.scale *= 4
			item.visible = actor.bag.shown
			item.item_type = 1
			item.process_mode = Node.PROCESS_MODE_PAUSABLE
			item._ready()
			actor.bag.get_child(0).get_child(0).add_child(item)
				
#global_position = global_position.move_toward(next_position, delta * character_speed)

# Make the robot look at the direction we're traveling.
# Clamp y to 0 so the robot only looks left and right, not up/down.

#offset.x *= -1

#if(backwards || play):

#func get_aabb_global_endpoints(mesh_instance: MeshInstance3D) -> Array:
	#if	not	is_instance_valid(mesh_instance):
		#return	[]
#
	#var	mesh:	Mesh = mesh_instance.mesh
	#if	not	mesh:
		#return	[]
#
	#var	aabb:AABB = mesh.get_aabb()
	#var	global_endpoints:=	[]
	#for	i	in	range(8):
		#var	local_endpoint:	Vector3	=	aabb.get_endpoint(i)
		#var	global_endpoint:	Vector3	=	mesh_instance.to_global(local_endpoint)
		#global_endpoints.push_back(global_endpoint)
	#return	global_endpoints
