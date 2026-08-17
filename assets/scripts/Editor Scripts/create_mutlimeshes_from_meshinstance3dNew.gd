@tool
extends Node3D

@export var target_root_path: NodePath
@export var export_collisions := false
@export var convert_now := false : set = _on_convert_now_set

func _on_convert_now_set(value: bool) -> void:
	if not value:
		return
	convert_now = false

	if not has_node(target_root_path):
		push_error("invalid root path: %s" % target_root_path)
		return

	var root_node: Node = get_node(target_root_path)
	var target_nodes: Array[Node] = root_node.get_children()

	var mesh_data_map: Dictionary = {}
	var collision_data: Array = []

	for node in target_nodes:
		if node is MeshInstance3D:
			var mesh: Mesh = node.mesh
			if mesh:
				_add_instance(mesh_data_map, mesh, node.global_transform)

		var meshes: Array = node.find_children("*", "MeshInstance3D", true)
		for mesh_node in meshes:
			if mesh_node == node:
				continue
			var mesh: Mesh = mesh_node.mesh
			if mesh:
				_add_instance(mesh_data_map, mesh, mesh_node.global_transform)

		if export_collisions:
			_collect_collisions(node, collision_data)

	if mesh_data_map.is_empty():
		push_warning("no MeshInstance3D nodes found under: %s" % target_root_path)
		return

	var result_container := $ConverterResult if has_node("ConverterResult") else Node3D.new()
	if not result_container.is_inside_tree():
		result_container.name = "ConverterResult"
		get_tree().edited_scene_root.add_child(result_container)
		result_container.owner = get_tree().edited_scene_root
	else:
		for child in result_container.get_children():
			child.queue_free()

	for mesh in mesh_data_map.keys():
		var transforms: Array = mesh_data_map[mesh]
		var mm := MultiMesh.new()
		mm.mesh = mesh
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Batched_" + mesh.resource_name
		mmi.multimesh = mm
		result_container.add_child(mmi)
		mmi.owner = get_tree().edited_scene_root
		mmi.visible = false
		mmi.visible = true
		print("created %d instances for: %s" % [transforms.size(), mesh.resource_path])

	if export_collisions and not collision_data.is_empty():
		var static_body := StaticBody3D.new()
		static_body.name = "MergedCollisions"
		result_container.add_child(static_body)
		static_body.owner = get_tree().edited_scene_root

		for entry in collision_data:
			var col_shape := CollisionShape3D.new()
			col_shape.shape = entry["shape"]
			var local_xf: Transform3D = result_container.global_transform.inverse() * entry["global_xf"]
			col_shape.transform = static_body.transform.inverse() * local_xf
			static_body.add_child(col_shape)
			col_shape.owner = get_tree().edited_scene_root

		print("merged %d collision shape(s) into MergedCollisions" % collision_data.size())

	print("done")


func _collect_collisions(node: Node, out: Array) -> void:
	var col_shapes: Array = node.find_children("*", "CollisionShape3D", true)
	for cs in col_shapes:
		if cs is CollisionShape3D and cs.shape != null:
			out.append({
				"shape": cs.shape,
				"global_xf": cs.global_transform
			})


func _add_instance(dict: Dictionary, mesh: Mesh, xf: Transform3D) -> void:
	if not dict.has(mesh):
		dict[mesh] = []
	dict[mesh].append(xf)
