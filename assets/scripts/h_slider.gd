extends HSlider

var reset_slider = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(Global.execute_plan):
		if(value < 0):
			value = 0
			
	if(reset_slider):
		if (value != 0):
			value = 0
		else:
			reset_slider = false

func _on_drag_ended(value_changed: bool) -> void:
	reset_slider = true
