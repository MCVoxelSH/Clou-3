extends Node

@export var interaction_point: Vector3 = Vector3.ZERO

func get_interaction_forward(obj: Node3D) -> Vector3:
	var forward :Vector3= obj.basis * obj.interaction_point.normalized()
	forward.y = 0.0
	return forward.normalized()

func get_all_children(node):
	var nodes : Array = []

	for N in node.get_children():

		if N.get_child_count() > 0:

			nodes.append(N)

			nodes.append_array(get_all_children(N))

		else:

			nodes.append(N)

	return nodes
