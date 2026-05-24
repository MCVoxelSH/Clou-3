extends HSlider


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(get_parent().get_parent().execute_plan):
		if(value < 0):
			value = 0


func _on_drag_ended(value_changed: bool) -> void:
	value = 0
	get_parent().get_parent().pause = true
