extends Marker3D


const Line3D = preload("res://assets/scripts/line3d.gd")

var finalize_guard_replay = false
#Which interaction was selected while interacting with an object
@export_enum("Talk", "Interact", "Inspect", "none", "Look at", "Break") var selected_interaction

@export var character_speed := 10.0
@export var max_capacity = 40.0
var currently_carrying_weight = 0.0
@export var show_path := true
@export var is_guard = false
@export var record_guard = false
var filepath_addon = ""
var replay:Array = []
var parts:Array = []

var id = 0
var currentid = 0
#seems to be the same as the array size, so basically id should always be < max id
var maxid = 0
var current_floor = 0

#is actor inside a building?
@export var starts_inside = false
var inside = false

##Locks, safes and alarms skills
@export var skills:Array[int] = [0,0,0]

@onready var _nav_agent := $NavigationAgent3D as NavigationAgent3D

var _nav_path_line : Line3D

@onready var progress_bar = $ProgressBar
@onready var text_bubble = $TextBubble
@onready var burglar_area = $Area3D

var object_that_is_being_interacted_with:Node3D = null

var finished_working = false

var is_opening = false

var is_waiting = false

var is_zoomed_onto_object = false

@onready var ray = $Robot/RayCast3D
#var area:Node3D

var camera_position_before_zoom_onto_object:Vector3
var camera_rotation_before_zoom_onto_object:Vector3

#is there a door so the move commands should be pushed forward?
var change_ticks = false

var pickup_time = 25

var maxticks = 0

var objects_in_sight_of_guard:Array

@export var unique_name = ""

#how well the guard can hear
@export var hearing = 0.0

#positions where burglar waited
var waiting_positions = []

var last_ticks = 0

var check_last_ticks = false

var last_ticks_index = -1

@onready var mesh = $Robot

@onready var start_pos = mesh.global_position

@export_flags_3d_physics var guard_sight_check_collision_mask

func _ready():
	
	$TextBubble.visible = false
	if(starts_inside):
		inside = true
	#last_ticks.append(0)
	#if(is_guard):
		#area = $Area3D
	#else:
		#area = $Area3D
	character_speed /= 10.0
	_nav_path_line = Line3D.new()
	add_child(_nav_path_line)
	_nav_path_line.set_as_top_level(true)
	_nav_path_line.global_position = global_position
	progress_bar.visible = false
	
	#for actor in get_tree().get_nodes_in_group("Actor"):
		#ray.add_exception(actor.area)
	

func _physics_process(_delta):
	
	if(!get_parent().backwards):
		
		for object in objects_in_sight_of_guard:
			if(object.is_in_group("Actor")):
				if(!object.is_guard):
					var space_state = get_world_3d().direct_space_state
								
					var query = PhysicsRayQueryParameters3D.create(mesh.global_position,object.global_position)
					query.collision_mask = guard_sight_check_collision_mask
					query.collide_with_areas = true
					query.exclude = [burglar_area]

					var result = space_state.intersect_ray(query)#actor.ray.get_collider()	
					if(result):
						if(result.collider.owner.is_in_group("Actor")):
							owner.print_caught_message(object.unique_name + " caught at " + get_node("/root/Control/TimerLabel").get_time_as_string() +  " ("+str(get_node("/root/Control").ticks)+" ticks)" + " by " + unique_name)
							print("burglar position: " + str(result.collider.owner.global_position)+ ",id: " + str(result.collider.owner.id) + ", own position: " + str(global_position) + ", id: " + str(id))
							objects_in_sight_of_guard.remove_at(objects_in_sight_of_guard.find(object))
					
			if(object.is_in_group("Interactable")):
				var space_state = get_world_3d().direct_space_state
							
				var query = PhysicsRayQueryParameters3D.create(mesh.global_position,object.global_position)
				query.collision_mask = guard_sight_check_collision_mask
				query.collide_with_areas = true
				query.exclude = [burglar_area]

				var result = space_state.intersect_ray(query)#actor.ray.get_collider()	
				if(result):	
					if(result.collider.owner.is_in_group("Interactable")):
						if(result.collider.owner.object_type == 0 || result.collider.owner.object_type == 1):
							if(result.collider.owner.anim_player.current_animation_position != 0):
								owner.print_caught_message("open door was found at " +str(get_parent().ticks) + " by " + unique_name && result.collider.owner.was_opened_by_burglar)
								objects_in_sight_of_guard.remove_at(objects_in_sight_of_guard.find(object))							
		
		
	
	progress_bar.global_position = get_viewport().get_camera_3d().unproject_position(global_transform.origin)
	#$TextBubble/TextBubbleBackground.global_position = get_viewport().get_camera_3d().unproject_position(global_transform.origin)
	$TextBubble.global_position = get_viewport().get_camera_3d().unproject_position(global_transform.origin)
	#FIXME this seems unoptimized, you actually just have to do it once every time the progress bar pops up
	progress_bar.global_position += Vector2(-250,-150)
	#$TextBubble/TextBubbleBackground.global_position += Vector2(-125,-250)
	$TextBubble.global_position += Vector2(-125,-250)
	
	
	if _nav_agent.is_navigation_finished():
		return
	#var next_position := _nav_agent.get_next_path_position()

func _process(delta: float) -> void:
	if(Input.is_action_pressed("ui_cancel")):
		if(!get_parent().execute_plan && (!is_guard || record_guard)):
			var f:FileAccess
			if(!is_guard):
				f = FileAccess.open("user://replay" + filepath_addon+".txt", FileAccess.WRITE)
			else:
				f = FileAccess.open("res://guard_replays/replay" + filepath_addon+".txt", FileAccess.WRITE)
			
			#for e in replay:
			#	f.store_line("%d %s" % [e.tick, e.action])
			for l in replay:
				if(l.size() == 5):
					f.store_line(str(l[0]) + "|" + str(l[1])+"|" + str(l[2])+"|" + str(l[3])+"|" + str(l[4]))
				elif(l.size() == 4):
					f.store_line(str(l[0]) + "|" + str(l[1])+"|" + str(l[2])+"|" + str(l[3]))
				elif(l.size() == 3):
					f.store_line(str(l[0]) + "|" + str(l[1])+ "|" + str(l[2]))
				else:
					f.store_line(str(l[0]) + "|" + str(l[1]))
			f.close()
			var g:FileAccess
			if(!is_guard):
				g = FileAccess.open("user://waiting_positions" + filepath_addon+".txt", FileAccess.WRITE)
			else:
				g = FileAccess.open("res://guard_replays/waiting_positions" + filepath_addon+".txt", FileAccess.WRITE)
			for l in waiting_positions:
				g.store_line(str(l[0]) + "|" + str(l[1])+"|" + str(l[2]))
			g.close()
				
		if(int(filepath_addon) == get_parent().number_of_burglars):
			get_parent().debug_file.close()
			get_tree().quit()

func set_target_position(target_position: Vector3, record: bool):
	
	#if(get_parent().ticks == 0 && last_ticks.is_empty()):
		#last_ticks.append(0)
		#last_ticks_index += 1

	#_nav_agent.set_target_position(target_position)
	$TextBubble.visible = false
	
	get_parent().was_backwards = false
	get_parent().was_forwards = false
	get_parent().play = false
	# Get a full navigation path with the NavigationServer API.
	if true:
		var start_position = mesh.global_position
		var optimize := true
		var navigation_map := get_world_3d().get_navigation_map()
		var path := NavigationServer3D.map_get_path(
				navigation_map,
				start_position,
				target_position,
				optimize)
		
		
		if(record):		
			
			var vec = mesh.global_position
			
			var ticks_plus_one = false
			var ticks_plus_one_overwrite = false
			
			if(!replay.is_empty()):
				if(replay[id][0] != -1 && replay[id][0] > owner.ticks):
					replay.remove_at(id)
					ticks_plus_one_overwrite = true
					
			
			if(true):#id != maxid -1 && id != 0):
				#REMINDER I readded +1, this fixes an issue, does it cause other issues though?
				var diff:int
				#if(owner.was_backwards && !(get_parent().ticks != 0 && id != 0)):
					#diff = maxid - id + 1
				#else:
				if((get_parent().ticks != 0 && id != 0) || id != maxid - 1):
					diff = maxid - id
				else:
					diff = maxid - id + 1
				
				var range_start = maxid - 1		
				
				for i in range(range_start, maxid -diff,-1):
					replay.erase(replay.back())
					if(!ticks_plus_one_overwrite):
						ticks_plus_one = true
					pass
				#if(currentid == maxid):
					#currentid-= diff -1
				#parts.clear()
				#parts.append(get_parent().ticks)
				#parts.append(mesh.global_position)
				#replay.append(parts.duplicate())
				#currentid +=1
				#if(id > 0):
					#id-=1
				pass
			currentid = id

		#start with ticks and increment with each position
			var ticks_at_position:int
			#if(replay.size() > 0):
				##get_parent().ticks = replay[id-1][0]+1
				#ticks_at_position = r +1
			#else:
			if(replay.size() > 0):
				#REMINDER this is pretty hacky, I am not sure why, but in some situations I gotta add 1 to the ticks and in others not, for example when working the check for the ticks is before the ticks are added, therefore I need to make the ticks one lower, maybe I should put the ticks addition before the check
				if(replay[replay.size()-1][0] == get_parent().ticks || ticks_plus_one): #&& get_parent().highlighted_object == null):
					ticks_at_position = get_parent().ticks + 1
				elif(replay[replay.size()-1][0] != -1):
					ticks_at_position = get_parent().ticks
				else:
					ticks_at_position = get_parent().ticks + 1
			else:
				ticks_at_position = get_parent().ticks
			#if(get_parent().ticks != 0 && id != 0):
				#ticks_at_position += 1
			
			
			var i = -1
			
			var space_state = get_world_3d().direct_space_state
			#I commented all of this loop out, maybe I want to reactive it later if it's actually needed or I might improve it
			for v in path:
				i+=1
				var dir = 1
				if(i != path.size()-1):
					var current = path[i]
					var next = path[i+1]
					var query = PhysicsRayQueryParameters3D.create(current,next)
					query.collide_with_areas = true
					query.exclude = [burglar_area]
					#query.set_collide_with_bodies(false)
					
					var result = space_state.intersect_ray(query)
					
					#if(result):
						#if(result.collider.get_parent().get_parent().is_in_group("Interactable")):
							#if(result.collider.get_parent().get_parent().object_type == 0):
								#if(i == 0):
									##REMINDER this whole code might be obsolete
									#break
							#if(result.collider.get_parent().get_parent().is_breakable && result.collider.get_parent().get_parent() == get_parent().highlighted_object):
								#
								#var distance_x = abs(path[i+1].x - path[i].x)
								#var distance_z = abs(path[i+1].z - path[i].z)
								#
								#var current_path_y =path[i].y
								#var next_path_y = path[i+1].y
								#
								#
								#if(distance_x >= distance_z):
								##if(result.collider.isdoor()):
									#
									#if(path[i+1].x >= path[i].x):
										#dir = -1
								#else:
									#if(path[i+1].z <= path[i].z):
										#dir = -1
										#
								#
								#if(result.collider.get_parent().get_parent().flip_axis):
									#dir *= -1
								#path[i] = result.collider.global_position + (result.collider.global_transform.basis.z*dir)
								#path[i+1] = result.collider.global_position + (result.collider.global_transform.basis.z*dir)
								#
								#
									#
								#path[i].y = current_path_y
								#path[i+1].y = current_path_y
								#
								#if(i+1 != path.size()-1):
									#for k in range (i+1,path.size()-1,1):
										#path.remove_at(path.size()-1)
								#
								##TODO this only works for 1 door being walked through currently, need to change to work with more doors
				##if(get_parent().highlighted_object != null && i < path.size()-1):
					##var path_y = path[i+1].y
					##if(get_parent().highlighted_object.flip_axis):
						##dir *= -1
					##path[i+1] = get_parent().highlighted_object.global_position + (get_parent().highlighted_object.global_transform.basis.z*dir)
					##path[i+1].y = path_y
			
			i = -1
			
			#FIXME this is not working correctly currently, I can comment it out to restore some stuff that worked better before
			#for v in path:
				#if(v == path[path.size()-1]):
					#
					#var vv = path[path.size()-2]
					#var previous:Vector3
					#var current:Vector3
					#
					#while (vv != v):
						#previous = vv
						#vv = vv.move_toward(v, character_speed)
						#current = vv
						#
					##path = NavigationServer3D.map_get_path(navigation_map,previous-50*(current - previous),
						##current+ 50*(current - previous),
						##optimize)	
					#
					#if(get_parent().highlighted_object != null && v == path[path.size()-1]):
					#
						#var query = PhysicsRayQueryParameters3D.create(previous -50*(current - previous),current+ 50*(current - previous))
						#query.collide_with_areas = true
						#query.exclude = [burglar_area]
						#query.set_collide_with_bodies(false)
						#
						#var result = space_state.intersect_ray(query)
						#if(result):
							#if(result.collider.get_parent().is_in_group("Interactable")):
								#if(result.collider.get_parent().is_breakable):
									#
									#var distance_x = abs(current.x - previous.x)
									#var distance_z = abs(current.z - previous.z)
									#
									#var previous_path_y =previous.y
									#var current_y = current.y
									#
									#var dir = 1
									#if(distance_x >= distance_z):
									##if(result.collider.isdoor()):
										#
										#if(current.x >= previous.x):
											#dir = -1
										#current = result.collider.global_position + (result.collider.global_transform.basis.z*dir *2)
									#else:
										#if(current.z <= previous.z):
											#dir = -1
										#current = result.collider.global_position + (result.collider.global_transform.basis.z*dir *2)
											#
									#
									#previous.y = previous_path_y
									#current.y = previous_path_y
									#
									#path[path.size()-1] = current
									##vec = current
											#
			
			var comparision_position = Vector3.INF
			if(get_parent().highlighted_object != null):
				comparision_position = get_parent().highlighted_object.global_position
				comparision_position.y = mesh.global_position.y
				
			#if(!is_zoomed_onto_object):
			if(mesh.global_position.distance_squared_to(comparision_position)>2):
			
				var first_vec = true
				for v in path:
					
					i+=1
				
					
					var last_vec = false
					while(!last_vec):
										#TODO this only works for 1 door being walked through currently, need to change to work with more doors
										#break
							#parts.clear()
							#parts.append(ticks_at_position)
							#path[path.size()-1] = get_parent().highlighted_object.global_position + get_parent().highlighted_object.global_transform.basis.z*2
							#parts.append(path[path.size()-1])
							#parts.append("move")
							#replay.append(parts.duplicate())
							#ticks_at_position+=1
							#currentid +=1
							#break
						
						if((v-vec).length()< character_speed):
							#vec +=((v-vec).normalized())*character_speed
							vec = vec.move_toward(v, character_speed)
							vec.y = v.y
							last_vec = true
							
					
						else:
							vec = vec.move_toward(v, character_speed)
					
						parts.clear()
						if(first_vec): #|| (v == path[path.size()-1] && last_vec)):
							parts.append(ticks_at_position)
							first_vec = false
						else:	
							parts.append(-1)
							
						parts.append(vec)
						parts.append("move")
						replay.append(parts.duplicate())
						ticks_at_position+=1
						currentid +=1
						
				
					
					#TODO I disabled all this, maybe I want to activate it again later		
					#if(i != path.size()-1):
						#var current = path[i]
						#var next = path[i+1]
						#var query = PhysicsRayQueryParameters3D.create(current,next)
						#query.collide_with_areas = true
						#query.exclude = [burglar_area]
						#query.set_collide_with_bodies(false)
						#
						#var result = space_state.intersect_ray(query)
						#if(result):
							#if(result.collider.get_parent().is_in_group("Interactable")):
								#if(result.collider.get_parent().is_breakable && result.collider.get_parent().damage == 10000):
									##if(result.collider.get_parent().anim_player.current_animation_position != result.collider.get_parent().anim_player.current_animation_length):
									##at ticks for door opening animation
									#
									#
									##for actor in get_tree().get_nodes_in_group("Actor"):
										##pass
										#
									#for actor in get_tree().get_nodes_in_group("Actor"):
										#if(actor != burglar_area):
											#pass
												#
									#for j in range(result.collider.get_parent().opening_time):
										#parts.clear()
										#parts.append(ticks_at_position)
										#parts.append(result.collider.get_parent().name)	
										#parts.append("open")
										#replay.append(parts.duplicate())
										#ticks_at_position+=1
										#currentid +=1
								#else:
									#parts.clear()
									#parts.append(ticks_at_position)
									#parts.append(result.collider.get_parent().name)	
									#parts.append("open")
									#replay.append(parts.duplicate())
									#ticks_at_position+=1
									#currentid +=1
									#break
								#
			else:
				parts.clear()
				parts.append(ticks_at_position)		
				parts.append(mesh.global_position)
				parts.append("move")
				replay.append(parts.duplicate())
				ticks_at_position+=1
				currentid +=1
	
			if(get_parent().highlighted_object != null):
				if(selected_interaction == 1):
					
					#if is car
					if(get_parent().highlighted_object.object_type == 6):
							parts.clear()
							parts.append(-1)
							parts.append(get_parent().highlighted_object.global_position)
							parts.append("moveinsidecar")
							parts.append(str(get_parent().highlighted_object.get_path()))
							replay.append(parts.duplicate())
							ticks_at_position+=1
							currentid +=1
					
					#if is loot
					if(get_parent().highlighted_object.object_type == 4):
						for j in range(pickup_time):
							parts.clear()
							parts.append(-1)
							#FIXME this produces bad paths
							if(get_parent().highlighted_object.get_parent()is MeshInstance3D):
								parts.append(str(get_parent().highlighted_object.get_path()))
							else:	
								parts.append(str(get_parent().highlighted_object.get_path()))
							if(j < pickup_time -1):
								parts.append("none")
							else:
								parts.append("take")
							replay.append(parts.duplicate())
							ticks_at_position+=1
							currentid +=1
					if((get_parent().highlighted_object.object_type == 0 || get_parent().highlighted_object.object_type == 3 ) && get_parent().selected_tool == null):#(get_parent().highlighted_object.object_type == 1 && inside)):
						for j in range(get_parent().highlighted_object.opening_time):
							parts.clear()
							parts.append(-1)
							parts.append(str(get_parent().highlighted_object.get_path()))	
							#FIXME there is the following issue: I set it to only do the thing for 1 tick, because otherwise it would repeat the animation when the tick speed is high (for some reason), but the issue now is that when playing in reverse the object opening does only get reversed at the starting frame, so at the beginning of the forward animation not of the backward animation
							parts.append("open")
							if(j == 0):
								parts.append("first")
							elif(j == get_parent().highlighted_object.opening_time-1):
								parts.append("last")
							else:
								parts.append("intermediate")
							replay.append(parts.duplicate())
							ticks_at_position+=1
							currentid +=1
							
							
					#if is window and wants to open
					if(get_parent().highlighted_object.object_type == 1 && selected_interaction == 1 && get_parent().selected_tool == null):
						var pos:Vector3
						var y_pos = path[path.size()-1].y
						var start_pos:Vector3
						var end_pos:Vector3
						if(inside):
							start_pos = get_parent().highlighted_object.global_position-get_parent().highlighted_object.global_transform.basis.z
							end_pos = get_parent().highlighted_object.global_position+get_parent().highlighted_object.global_transform.basis.z*2
						else:
							start_pos = get_parent().highlighted_object.global_position+get_parent().highlighted_object.global_transform.basis.z
							end_pos = get_parent().highlighted_object.global_position-get_parent().highlighted_object.global_transform.basis.z*2
						start_pos.y = y_pos	
						end_pos.y = y_pos
						for t in range(0,1000,25):
							pos =_quadratic_bezier(start_pos,get_parent().highlighted_object.global_position, end_pos,t/1000.0)
							parts.clear()
							parts.append(-1)
							parts.append(pos)
							#REMINDER the idea is to not save the window opening steps, instead let the burglar dynamicaly open window and wait if needed
							parts.append("movethroughwindow")
							parts.append(str(get_parent().highlighted_object.get_path()))
							parts.append(inside)
							replay.append(parts.duplicate())
							ticks_at_position+=1
							currentid +=1
					
					
					if(get_parent().highlighted_object.object_type == 2):
						for j in range(get_parent().highlighted_object.opening_time):
							parts.clear()			
							parts.append(-1)
							parts.append(str(get_parent().highlighted_object.get_path()))	
							parts.append("use")
							if(j == 1):
								parts.append("first")
							elif(j == get_parent().highlighted_object.opening_time-1):
								parts.append("last")
							else:
								parts.append("intermediate")
							replay.append(parts.duplicate())
							ticks_at_position+=1
							currentid +=1
						
								
					elif((get_parent().highlighted_object.is_breakable && !(get_parent().highlighted_object.object_type == 1 && inside))&& get_parent().selected_tool != null):
						#this whole thing uses floats for time and steps and could be the cause of bugs later on with float precision issues
						#TODO this also causes and issue where the following happens: while the burglar is working on the object another one gets the command to work on it, but only recieves the current damage of the object not the damage in time when he arrives at the object
						var breaking_time = calculate_breaking_time()
						var step_size:int = floor(10000.0 / breaking_time)
						var current_progress = 	get_parent().highlighted_object.damage
						while(current_progress < 10000):
							current_progress += step_size
							if(current_progress > 10000):
								current_progress = 10000
							parts.clear()
							parts.append(-1)
							parts.append(str(get_parent().highlighted_object.get_path()))	
							parts.append("break")
							parts.append(step_size)
							parts.append(get_parent().selected_tool.name)
							replay.append(parts.duplicate())
							ticks_at_position+=1
							currentid +=1	
				if(selected_interaction == 2):
					if(get_parent().highlighted_object.object_type == 3 || get_parent().highlighted_object.object_type == 4):
						if(!is_guard):
							for j in range(3):
								parts.clear()
								parts.append(-1)
								if(get_parent().highlighted_object.get_parent()is MeshInstance3D):
									parts.append(str(get_parent().highlighted_object.get_path()))
								else:	
									parts.append(str(get_parent().highlighted_object.get_path()))
								parts.append("inspect")
								replay.append(parts.duplicate())
								ticks_at_position+=1
								currentid +=1	
					
						else:
							for j in range(25):
								parts.clear()
								parts.append(-1)
								parts.append(str(get_parent().highlighted_object.get_path()))	
								parts.append("inspect")
								replay.append(parts.duplicate())
								ticks_at_position+=1
								currentid +=1	
					
				if(selected_interaction == 4):
					for j in range(3):
						parts.clear()
						parts.append(-1)
						parts.append(str(get_parent().highlighted_object.get_path()))	
						parts.append("look at")
						replay.append(parts.duplicate())
						ticks_at_position+=1
						currentid +=1	
						
					
			#for actor in get_tree().get_nodes_in_group("Actor"):
				#if(actor != burglar_area):
					#actor.add_wait_ticks(ticks_at_position)
		#id -=1
		maxid = replay.size()
		
		var waiting_positions_to_delte = []
		
		for w in waiting_positions:
			if(w[0] >= get_node("/root/Control").ticks):
				waiting_positions_to_delte.append(w)
		
		for w in waiting_positions_to_delte:
			waiting_positions.erase(w)
		
		if(show_path):
			_nav_path_line.draw_path(path)
			pass

static func string_to_vector3(string := "") -> Vector3:
	if string:
		var new_string: String = string
		new_string = new_string.erase(0, 1)
		new_string = new_string.erase(new_string.length() - 1, 1)
		var array: Array = new_string.split(", ")

		return Vector3(float(array[0]), float(array[1]), float (array[2]))

	return Vector3.ZERO
	
func _on_area_3d_area_entered(area: Area3D) -> void:
	_on_body_or_area_entered(area)
	

func _on_area_3d_area_exited(area: Area3D) -> void:
	_on_body_or_area_exited(area)


func _on_area_3d_body_entered(body: Node3D) -> void:
	_on_body_or_area_entered(body)


func _on_area_3d_body_exited(body: Node3D) -> void:
	_on_body_or_area_exited(body)

func _on_body_or_area_entered(body_area):
	#if(!get_parent().backwards):

		if(objects_in_sight_of_guard.find(body_area.owner)== -1 && (body_area.owner.is_in_group("Interactable")|| body_area.owner.is_in_group("Actor"))): #|| body_area.owner.is_in_group("Actor"))):
			objects_in_sight_of_guard.append(body_area.owner)

		
		if(body_area.owner.is_in_group("Actor")):
			if(!body_area.owner.is_guard):
				var space_state = get_world_3d().direct_space_state
							
				var query = PhysicsRayQueryParameters3D.create(mesh.global_position,body_area.owner.global_position)
				query.collision_mask = guard_sight_check_collision_mask
				query.collide_with_areas = true
				query.exclude = [burglar_area]

				var result = space_state.intersect_ray(query)#actor.ray.get_collider()	
				if(result):
					if(result.collider.owner.is_in_group("Actor")):
						#owner.print_caught_message(body_area.owner.name,str(get_parent().ticks),unique_name)
						owner.print_caught_message(body_area.owner.unique_name + " caught at " +str(get_parent().ticks) + " by " + unique_name)
				
		if(body_area.owner.is_in_group("Interactable")):
			var space_state = get_world_3d().direct_space_state
						
			var query = PhysicsRayQueryParameters3D.create(mesh.global_position,body_area.owner.global_position)
			query.collision_mask = guard_sight_check_collision_mask
			query.collide_with_areas = true
			query.exclude = [burglar_area]

			var result = space_state.intersect_ray(query)#actor.ray.get_collider()	
			if(result):	
				if(result.collider.owner.is_in_group("Interactable")):
					if(result.collider.owner.object_type == 0 || result.collider.owner.object_type == 1  || result.collider.owner.object_type == 3):
						if(result.collider.owner.anim_player.current_animation_position != 0 && result.collider.owner.was_opened_by_burglar):
							owner.print_caught_message("opened object was found at " +str(get_parent().ticks) + " by " + unique_name)
	
func _on_body_or_area_exited(body_area):
	#if(!get_parent().backwards):
	var index = objects_in_sight_of_guard.find(body_area.owner)
	if(index != -1):
		objects_in_sight_of_guard.remove_at(index)

func load_replay():
	
	if(get_parent().play || get_parent().load_replay ||  (is_guard && !record_guard)):
		var f:FileAccess
		if(!is_guard):
			f = FileAccess.open("user://replay" + filepath_addon+".txt", FileAccess.READ)
		else:
			f = FileAccess.open("res://guard_replays/replay" + filepath_addon+".txt", FileAccess.READ)
		if(f != null):
			while !f.eof_reached():
				var line = f.get_line()
				if(line == ""):
					continue
				parts.clear()
				parts = line.split(("|"))
				var temp:Array
				temp.append(int(parts[0]))
				if(parts[2] == "move" || parts[2] == "movethroughwindow" || parts[2] == "moveinsidecar"):
					var vec = string_to_vector3(parts[1])
					temp.append(vec)
				else:
					temp.append(StringName(parts[1]))
				if(parts.size() == 3):
					temp.append(parts[2])	
				if(parts.size() >= 4):
					temp.append(parts[2])	
					if(parts[2] == "move" || parts[2] == "movethroughwindow" || parts[2] == "moveinsidecar" || parts[2] == "use" ||parts[2] == "open" || parts[2] == "wait"):
						temp.append(parts[3])
					else:
						temp.append(int(parts[3]))
				if(parts.size() == 5):
					temp.append(parts[4])
				replay.append(temp.duplicate())
			f.close()
		
		if(replay.size() > 0):		
			currentid =replay.size()
			maxid = replay.size()
			#TODO this is not very inefficient, but also not really bad
			for i in range(replay.size()-1):
				if(replay[i][0] != -1):
					maxticks = replay[i][0]
				else:
					maxticks +=1
					
					
		var g:FileAccess
		if(!is_guard):
			g = FileAccess.open("user://waiting_positions" + filepath_addon+".txt", FileAccess.READ)
		else:
			g = FileAccess.open("res://guard_replays/waiting_positions" + filepath_addon+".txt", FileAccess.READ)
		if(g != null):
			while !g.eof_reached():
				var line = g.get_line()
				if(line == ""):
					continue
				parts.clear()
				parts = line.split(("|"))
				var temp:Array
				temp.append(int(parts[0]))
				temp.append(parts[1])
				temp.append(float(parts[2]))
				waiting_positions.append(temp.duplicate())
			g.close()
			
			#if(replay.size() > 0):
				#next_time = int(replay[current_array_position+1][0])
				#next_action =  replay[current_array_position][1]
		

		

func calculate_breaking_time()->float:
	
	#type 3 is "none"
	if(get_parent().selected_tool != null && get_parent().highlighted_object.lock_type != 3):
		var time = floor(10000.0 / (float(get_parent().selected_tool.tool_efficencies[get_parent().highlighted_object.lock_type])+float(skills[get_parent().highlighted_object.lock_type])))
		return time
		#(300 - get_parent().highlighted_object.damage - get_parent().selected_tool.tool_efficencies[get_parent().highlighted_object.lock_type])
	else:
		return 0
		

func show_text_bubble(text:String):
	$TextBubble.size = Vector2.ZERO
	$TextBubble.text = text
	$TextBubble.visible = true

func _quadratic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float):
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	var r = q0.lerp(q1, t)
	return r

func add_wait_ticks(ticks_at_position):
	
	#REMINDER need to think this through!!!
	
	#var diff = ticks_at_position - last_ticks
	#print("diff = " +  str(diff))
	#
	#if(diff > 0):
		#
		#var final_position = start_pos
		#var i = replay.size()-1
		#
		#if(replay.size() > 0):
			#while(replay[i][2]!= "move" && i > 0):
				#i -= 1
			#
			#if(replay[i][2] == "move"):
				#final_position = replay[i][1]
		#
		#var k = 0 if replay.is_empty() else 1
		#
		#for j in range(k, diff):
			
	parts.clear()
	parts.append(ticks_at_position)
	parts.append(mesh.global_position)#final_position
	parts.append("wait")
	replay.append(parts.duplicate())
	
	maxid = replay.size()
