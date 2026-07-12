extends VBoxContainer

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(Input.is_action_just_pressed("ui_cancel")):
		visible = !visible
		get_tree().paused = visible
		owner.active_burglar.bag.visible = false
		get_node("/root/Control/CaughtMessage").visible = false
	
