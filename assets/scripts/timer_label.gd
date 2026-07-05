extends Label

var time_divisor = 9
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if(!get_node("/root/Control/").debug_mode):
		text = get_time_as_string()
	else:
		text = str(get_node("/root/Control/").ticks)
	
func calculate_minutes():
	return  floor((get_node("/root/Control/").ticks/time_divisor)/60)

	
func calculate_seconds():
	return  ((get_node("/root/Control/").ticks/time_divisor)%60)

func get_time_as_string():
	var seconds = calculate_seconds()
	var minutes = calculate_minutes()
	var seconds_string:String
	var minutes_string:String
	if(seconds < 10):
		seconds_string += "0"
	seconds_string += str(seconds)
	if(minutes < 10):
		minutes_string += "0"
	minutes_string += str(minutes)
		
	return "Time: "+ minutes_string + ":" + seconds_string
	
	
