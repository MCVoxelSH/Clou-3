extends Node

func get_visual_facing(root: Node3D)-> Vector3:
	var mesh := _find_first_mesh(root)
	if mesh == null:
		push_error("Kein Mesh gefunden:	" + root.name)
		return	Vector3.ZERO

	var	forward	:=	-mesh.global_transform.basis.z.normalized()

	if	abs(forward.x) > abs(forward.z):
		return	Vector3.FORWARD if	forward.x	>	0 else	-Vector3.FORWARD
	else:
		return	Vector3.RIGHT if	forward.z	>	0 else	-Vector3.RIGHT

func _find_first_mesh(node:	Node)->	MeshInstance3D:
	if	node	is	MeshInstance3D:
					return	node

	for	child	in	node.get_children():
					var	m	:=	_find_first_mesh(child)
					if	m:
									return	m

	return	null

func get_all_children(node):
	var nodes : Array = []

	for N in node.get_children():

		if N.get_child_count() > 0:

			nodes.append(N)

			nodes.append_array(get_all_children(N))

		else:

			nodes.append(N)

	return nodes
