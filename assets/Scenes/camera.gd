extends Node3D

@onready var spotlight = $Spotlight

@export_enum("Door", "Window", "Switch", "Container","Loot","other", "Car", "Camera", "Alarm") var object_type

var camera_pos_node:Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	camera_pos_node = $CameraPosNode


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_area_entered(area: Area3D) -> void:
	if(area.get_parent().is_in_group("Actor") && !get_node("/root/Control/").backwards):
		if(!area.get_parent().is_guard):
			get_node("/root/Control").print_caught_message(area.get_parent().name + " caught at " +str(get_node("/root/Control/").ticks) + " by " + name)
	
