extends Node3D

@onready var spotlight = $Spotlight

@export_enum("Door", "Window", "Switch", "Container","Loot","other", "Car", "CameraOrLaser", "Alarm") var object_type

var camera_pos_node:Node3D

var base_albedos: Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	camera_pos_node = $CameraPosNode
	
	for c in GlobalFunctions.get_all_children(self):
		if(c is MeshInstance3D):
			var array = []
			var count = c.get_surface_override_material_count()
			for i in range(count):
				var mesh_material = c.get_active_material(i).duplicate()
				array.append(mesh_material.albedo_color)
			base_albedos.append(array)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_area_entered(area: Area3D) -> void:
	if(area.get_parent().is_in_group("Actor") && !get_node("/root/Control/").backwards):
		if(!area.get_parent().is_guard):
			get_node("/root/Control").print_caught_message(area.get_parent().name + " caught at " +str(get_node("/root/Control/").ticks) + " by " + name)
	

func toggle_power_state() -> void:
	if(process_mode == Node.PROCESS_MODE_DISABLED):
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		process_mode = Node.PROCESS_MODE_DISABLED
		
	spotlight.visible = !spotlight.visible		
