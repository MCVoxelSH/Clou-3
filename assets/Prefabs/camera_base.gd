extends Node3D

var start_pos:Vector3
# Called when the node enters the scene tree for the first time.
func update_camera() -> void:
	start_pos =  get_parent().active_burglar.global_position#global_position

#func _process(delta: float) -> void:
	##global_position = global_position.move_toward(get_parent().get_parent().active_burglar.global_position, 1)
	#global_position = start_pos#get_parent().get_parent().active_burglar.global_position
