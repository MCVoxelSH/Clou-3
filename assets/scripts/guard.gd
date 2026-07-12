extends "res://assets/scripts/character.gd"

@export var record_guard = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	super(delta)

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
