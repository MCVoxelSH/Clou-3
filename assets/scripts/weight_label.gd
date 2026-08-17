extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if(!owner.active_burglar.is_guard):
		text = str(int(get_node("/root/Control/").active_burglar.current_carrying_weight))+ "/"+ str(int(get_node("/root/Control/").active_burglar.max_capacity)) +"kg"
	else:
		text = str(owner.active_burglar.selected_interaction)
