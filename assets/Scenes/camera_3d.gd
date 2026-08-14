extends Node3D

func _process(delta):
		# Use the built-in interpolated transform for smooth camera movement
		global_transform = owner.getchild(0).get_global_transform_interpolated()
