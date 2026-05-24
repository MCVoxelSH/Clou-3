extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	text =  "Cash: "+ str(get_parent().cash) +"$"
	if(get_parent().cash >= get_parent().min_loot):
		var green = Color(0.0,1.0,0.0,1.0)
		set("theme_override_colors/font_color",green)
	else:
		var red = Color(1.0,0.0,0.0,1.0)
		set("theme_override_colors/font_color",red)
