extends "res://assets/scripts/character.gd"

@export var record_guard = false

@onready var bag= $Bag
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	super(delta)

func _physics_process(_delta):
	if(!get_parent().backwards):
		
		for object in objects_in_sight_of_guard:
			if(object.is_in_group("Actor")):
				if(!object.is_guard):
					var space_state = get_world_3d().direct_space_state
								
					var query = PhysicsRayQueryParameters3D.create(mesh_root.global_position,object.global_position)
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
							
				var query = PhysicsRayQueryParameters3D.create(mesh_root.global_position,object.global_position)
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
		
		
	super(_delta)	

func load_replay():
	
	if(get_parent().play || Global.load_replay ||  (is_guard && !record_guard)):
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
					if(parts[4] == "true"):
						temp.append(true)
					elif(parts[4] == "false"):
						temp.append(false)
					else:
						temp.append(parts[4])	
				replay.append(temp.duplicate())
			f.close()
		
		if(replay.size() > 0):		
			currentid =replay.size()
			maxid = replay.size()
			#TODO this is not very inefficient, but also not really bad
			for i in range(replay.size()-1):
				if(replay[i][0] != -1):
					max_ticks = replay[i][0]
				else:
					max_ticks +=1
		
		last_ticks = max_ticks			
					
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
		
func save_replay():
	
	if(!Global.execute_plan && (!is_guard || record_guard)):
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
			
	#if(int(filepath_addon) == get_parent().number_of_burglars):

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
							
				var query = PhysicsRayQueryParameters3D.create(mesh_root.global_position,body_area.owner.global_position)
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
						
			var query = PhysicsRayQueryParameters3D.create(mesh_root.global_position,body_area.owner.global_position)
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
