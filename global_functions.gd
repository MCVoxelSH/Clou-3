extends Node

@export var interaction_point: Vector3 = Vector3.ZERO

func get_interaction_forward(obj: Node3D) -> Vector3:
	var forward :Vector3= obj.basis * obj.interaction_point
	forward.y = 0.0
	return forward

func get_all_children(node):
	var nodes : Array = []

	for N in node.get_children():

		if N.get_child_count() > 0:

			nodes.append(N)

			nodes.append_array(get_all_children(N))

		else:

			nodes.append(N)

	return nodes

func find_currently_enabled_floor() -> int:
	var enabled_floor = -1
	for i in range (get_node("/root/Control").active_burglar.current_floor + 1, get_node("/root/Control").burglary_target_node.number_of_floors + 1):
		if(get_node("/root/Control/"+str(get_node("/root/Control").burglary_target)+"/Inside/Floor"+str(i)).process_mode == PROCESS_MODE_DISABLED):
			break
		else:
			enabled_floor += 1

	return enabled_floor
