@tool
extends Node3D

## Builds the game world directly in the editor from the raw unpacker.
##
## Additionally creates static collision geometry while the world is built.
##
## Collision strategy:
## - All mesh parts belonging to one model are combined.
## - Instances of that model are grouped into chunks.
## - One StaticBody3D + one CollisionShape3D is created per chunk.
## - The world is built off-tree and attached only once at the end.
##
## This avoids creating one collider per MultiMeshInstance3D.
## This is especially important because the generated scene contains
## roughly 80,000 MultiMeshInstance3D nodes.


@export_category("World Generator")

@export var flip_imported_normals: bool = true

@export_file("*.json")
var world_tree_path: String = "res://Clou2_unpack//world_tree.json"

@export_file("*.json")
var models_info_path: String = "res://Clou2_unpack/models_info.json"

@export_file("*.json")
var object_list_path: String = "res://Clou2_unpack/object_list.json"

@export var generate_world: bool = false:
	set = _on_generate_pressed

@export var clear_previous: bool = true


## Maximum number of model instances represented by one collision body.
##
## A model with e.g. 3000 instances will therefore get:
##
##   500 instances -> StaticBody
##   500 instances -> StaticBody
##   ...
##
## This prevents one ConcavePolygonShape3D from becoming enormous.
const COLLIDER_INSTANCES_PER_CHUNK := 500


var _building: bool = false


# ============================================================
# World generation
# ============================================================

func _on_generate_pressed(value: bool) -> void:
	# Only react to the transition to true.
	if not value:
		return

	if is_inside_tree() and not _building:
		build_world_in_editor()

	set_deferred("generate_world", false)


func build_world_in_editor() -> void:
	if not Engine.is_editor_hint():
		return

	var edited_scene := get_tree().edited_scene_root

	if edited_scene == null:
		printerr("Ошибка: Не удалось получить корень сцены.")
		return

	_building = true

	print("[DBG] clear_previous start, child_count=", get_child_count())

	if clear_previous:
		for child in get_children():
			child.queue_free()

	print("[DBG] clear_previous done")

	# --------------------------------------------------------
	# Load JSON
	# --------------------------------------------------------

	print("[DBG] loading world_tree_path=", world_tree_path)
	var world_tree = _load_json(world_tree_path)

	print(
		"[DBG] world_tree loaded, is_null=",
		world_tree == null
	)

	print("[DBG] loading models_info_path=", models_info_path)
	var models_info = _load_json(models_info_path)

	print(
		"[DBG] models_info loaded, is_null=",
		models_info == null
	)

	print("[DBG] loading object_list_path=", object_list_path)
	var object_list = _load_json(object_list_path)

	print(
		"[DBG] object_list loaded, is_null=",
		object_list == null
	)

	if (
		world_tree == null
		or models_info == null
		or object_list == null
	):
		_building = false
		return

	# --------------------------------------------------------
	# Folder hierarchy
	# --------------------------------------------------------

	print("[DBG] building folder hierarchy")

	var folder_info := _build_folder_hierarchy(world_tree)

	var folder_nodes: Dictionary = folder_info["folders"]
	var by_index: Dictionary = folder_info["by_index"]

	print(
		"[DBG] folder hierarchy built, folders=",
		folder_nodes.size()
	)

	# --------------------------------------------------------
	# Resolve instances
	# --------------------------------------------------------

	print(
		"Разбор world_tree.json (",
		world_tree.size(),
		" узлов)..."
	)

	print("[DBG] calling _resolve_instances")

	var resolved := _resolve_instances(
		world_tree,
		models_info,
		object_list,
		folder_info
	)

	# file -> folder_index -> Array[instance]
	var instances_by_file_folder: Dictionary = (
		resolved["by_file"]
	)

	# index -> special instance data
	var special_instances: Dictionary = (
		resolved["special"]
	)

	print(
		"[DBG] _resolve_instances done, unique files=",
		instances_by_file_folder.size(),
		", special=",
		special_instances.size()
	)

	# --------------------------------------------------------
	# Release raw JSON data before loading models.
	# --------------------------------------------------------

	print("[DBG] nulling raw json refs")

	world_tree = null
	models_info = null
	object_list = null

	print("[DBG] nulled raw json refs")

	if instances_by_file_folder.is_empty():
		print("Нет объектов для генерации.")
		_building = false
		return

	# --------------------------------------------------------
	# Count instances
	# --------------------------------------------------------

	var total_files := instances_by_file_folder.size()
	var total_instances := special_instances.size()

	for file_name: String in instances_by_file_folder:

		var by_folder: Dictionary = (
			instances_by_file_folder[file_name]
		)

		for folder_key in by_folder:
			total_instances += (
				by_folder[folder_key].size()
			)

	print(
		"Начинаем генерацию MultiMesh. Файлов: ",
		total_files,
		", инстансов: ",
		total_instances
	)

	# --------------------------------------------------------
	# Build the entire world off-tree.
	# --------------------------------------------------------

	var world_root := Node3D.new()
	world_root.name = "GeneratedWorld"

	# Add top-level folders to world_root.
	for folder_index in folder_nodes:

		var fnode: Node3D = folder_nodes[folder_index]

		if fnode.get_parent() == null:
			world_root.add_child(fnode)

	# --------------------------------------------------------
	# Main build
	# --------------------------------------------------------

	var processed_files := 0
	var created_instances := 0

	# Shared model cache.
	var mesh_cache: Dictionary = {}

	for file_name: String in instances_by_file_folder:

		var by_folder: Dictionary = (
			instances_by_file_folder[file_name]
		)

		var file_instance_count := 0

		for folder_key in by_folder:
			file_instance_count += (
				by_folder[folder_key].size()
			)

		# ----------------------------------------------------
		# Load model parts
		# ----------------------------------------------------

		var parts := _load_mesh_parts(
			file_name,
			mesh_cache
		)

		if parts.is_empty():
			processed_files += 1
			continue

		# ----------------------------------------------------
		# Process every folder containing this model.
		# ----------------------------------------------------

		for folder_key in by_folder:

			var nodes_data: Array = (
				by_folder[folder_key]
			)

			var instance_count := nodes_data.size()

			var parent_node: Node3D = (
				folder_nodes.get(
					folder_key,
					world_root
				)
			)

			# ------------------------------------------------
			# Create MultiMeshes
			# ------------------------------------------------

			for part in parts:

				var mmi := MultiMeshInstance3D.new()

				mmi.name = (
					file_name.get_file().get_basename()
					+ "_"
					+ String(part["name"])
				)

				var mm := MultiMesh.new()

				mm.transform_format = (
					MultiMesh.TRANSFORM_3D
				)

				mm.use_custom_data = false
				mm.mesh = part["mesh"]
				mm.instance_count = instance_count

				mmi.multimesh = mm

				if part["material"]:
					mmi.material_override = (
						part["material"]
					)

				var internal_transform: Transform3D = (
					part["internal_transform"]
				)

				for i in range(instance_count):

					var data: Dictionary = (
						nodes_data[i]
					)

					var json_xform := (
						_compute_instance_transform(
							data["pos"],
							float(data.get("rot", 0.0)),
							float(data.get("scale", 1.0))
						)
					)

					mm.set_instance_transform(
						i,
						json_xform * internal_transform
					)

				parent_node.add_child(mmi)

			# ------------------------------------------------
			# Create collision for the model.
			#
			# All parts belonging to this model are combined.
			# The instances are split into chunks.
			# ------------------------------------------------

			_create_multimesh_colliders(
				parent_node,
				file_name.get_file().get_basename(),
				parts,
				nodes_data
			)

		created_instances += file_instance_count
		processed_files += 1

		print(
			"[DBG] #%d/%d %s (%d inst, %d parts, %d folders) total=%d"
			% [
				processed_files,
				total_files,
				file_name,
				file_instance_count,
				parts.size(),
				by_folder.size(),
				created_instances,
			]
		)

		# ----------------------------------------------------
		# Give the editor time to process.
		# ----------------------------------------------------

		await get_tree().process_frame
		await get_tree().process_frame

		if processed_files % 50 == 0:

			for _i in range(10):
				await get_tree().process_frame

	# ========================================================
	# Special instances
	# ========================================================

	if not special_instances.is_empty():

		print(
			"[DBG] resolving ",
			special_instances.size(),
			" special (instance-child-of-instance) nodes"
		)

		var special_folder_cache: Dictionary = {}
		var wrapper_nodes: Dictionary = {}

		var remaining: Array = (
			special_instances.keys()
		)

		var guard := 0

		while remaining.size() > 0 and guard < 20:

			guard += 1

			var still_remaining: Array = []

			for idx in remaining:

				var info: Dictionary = (
					special_instances[idx]
				)

				var parent_id: int = (
					info["parent_id"]
				)

				var container: Node3D

				# ------------------------------------------------
				# Parent is another special instance.
				# ------------------------------------------------

				if special_instances.has(parent_id):

					if not wrapper_nodes.has(parent_id):

						still_remaining.append(idx)
						continue

					container = (
						wrapper_nodes[parent_id]
					)

				# ------------------------------------------------
				# Parent is a folder.
				# ------------------------------------------------

				else:

					var folder_key := (
						_resolve_folder(
							parent_id,
							folder_nodes,
							by_index,
							special_folder_cache
						)
					)

					container = (
						folder_nodes.get(
							folder_key,
							world_root
						)
					)

				# ------------------------------------------------
				# Load model.
				# ------------------------------------------------

				var parts := _load_mesh_parts(
					info["file_path"],
					mesh_cache
				)

				var inst_xform := (
					_compute_instance_transform(
						info["pos"],
						info["rot"],
						info["scale"]
					)
				)

				# ------------------------------------------------
				# Wrapper.
				# ------------------------------------------------

				var wrapper := Node3D.new()

				wrapper.name = (
					info["file_path"]
					.get_file()
					.get_basename()
					+ "_"
					+ str(idx)
				)

				# The wrapper already contains the instance transform.
				wrapper.transform = inst_xform

				for part in parts:

					var mi := MeshInstance3D.new()

					mi.name = String(part["name"])
					mi.mesh = part["mesh"]

					if part["material"]:
						mi.material_override = (
							part["material"]
						)

					# Only the internal model transform here.
					mi.transform = (
						part["internal_transform"]
					)

					wrapper.add_child(mi)

				container.add_child(wrapper)

				# ------------------------------------------------
				# Collider for this special object.
				#
				# IMPORTANT:
				# inst_xform is NOT passed here because wrapper
				# already has it.
				# ------------------------------------------------

				_create_special_collider(
					wrapper,
					parts
				)

				wrapper_nodes[idx] = wrapper

				created_instances += 1

			remaining = still_remaining

			await get_tree().process_frame

		if remaining.size() > 0:

			printerr(
				"[DBG] could not resolve parent chain for special instances: ",
				remaining
			)

		print(
			"[DBG] special instances resolved: ",
			wrapper_nodes.size()
		)

	# ========================================================
	# Attach generated world to the actual scene.
	# ========================================================

	print(
		"[DBG] attaching world_root to edited scene, child_count=",
		world_root.get_child_count()
	)

	add_child(world_root)

	print("[DBG] world_root attached")

	_set_owner_recursive(
		world_root,
		edited_scene
	)

	print("[DBG] owners set recursively")

	print(
		"Генерация успешно завершена! Отрисовано инстансов: ",
		created_instances
	)

	_building = false




# ============================================================
# Create colliders for normal MultiMesh instances
# ============================================================

func _create_multimesh_colliders(
	parent_node: Node3D,
	model_name: String,
	parts: Array,
	nodes_data: Array
) -> void:

	if nodes_data.is_empty():
		return

	print(
		"[COLLIDER] Starte: ",
		model_name,
		" | Instanzen=",
		nodes_data.size(),
		" | Parts=",
		parts.size()
	)

	var total_instances := nodes_data.size()
	var chunk_start := 0
	var chunk_index := 0

	while chunk_start < total_instances:

		var chunk_end = min(
			chunk_start + COLLIDER_INSTANCES_PER_CHUNK,
			total_instances
		)

		var faces := PackedVector3Array()

		# ----------------------------------------------------
		# Alle Instanzen dieses Chunks
		# ----------------------------------------------------

		for instance_index in range(chunk_start, chunk_end):

			var data: Dictionary = nodes_data[instance_index]

			var instance_transform := _compute_instance_transform(
				data["pos"],
				float(data.get("rot", 0.0)),
				float(data.get("scale", 1.0))
			)

			# ------------------------------------------------
			# Alle Mesh-Parts des Modells
			# ------------------------------------------------

			for part in parts:

				var mesh: Mesh = part["mesh"]

				if mesh == null:
					continue

				var internal_transform: Transform3D = (
					part["internal_transform"]
				)

				var final_transform := (
					instance_transform
					* internal_transform
				)

				_append_mesh_faces(
					mesh,
					final_transform,
					faces
				)

		print(
			"[COLLIDER] ",
			model_name,
			" Chunk ",
			chunk_index,
			": ",
			chunk_end - chunk_start,
			" Instanzen, ",
			faces.size() / 3,
			" Dreiecke"
		)

		if faces.is_empty():

			printerr(
				"[COLLIDER] WARNUNG: Keine Geometrie für ",
				model_name,
				" Chunk ",
				chunk_index
			)

			chunk_start = chunk_end
			chunk_index += 1
			continue

		# ----------------------------------------------------
		# Concave collision shape
		# ----------------------------------------------------

		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)

		# ----------------------------------------------------
		# StaticBody
		# ----------------------------------------------------

		var static_body := StaticBody3D.new()

		if total_instances <= COLLIDER_INSTANCES_PER_CHUNK:
			static_body.name = "__Collider_" + model_name
		else:
			static_body.name = "__Collider_%s_%d" % [
				model_name,
				chunk_index
			]

		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		collision_shape.shape = shape

		static_body.add_child(collision_shape)
		parent_node.add_child(static_body)

		print(
			"[COLLIDER] ERSTELLT: ",
			static_body.name,
			" | Faces=",
			faces.size() / 3
		)

		chunk_start = chunk_end
		chunk_index += 1


# ============================================================
# Liest die tatsächlichen Vertex-/Index-Daten eines Meshes aus
# ============================================================

func _append_mesh_faces(
	mesh: Mesh,
	transform: Transform3D,
	output: PackedVector3Array
) -> void:

	if mesh == null:
		return

	for surface in range(mesh.get_surface_count()):

		var arrays: Array = mesh.surface_get_arrays(surface)

		if arrays.is_empty():
			continue

		var vertices: PackedVector3Array = (
			arrays[Mesh.ARRAY_VERTEX]
		)

		if vertices.is_empty():
			continue

		var indices: PackedInt32Array = (
			arrays[Mesh.ARRAY_INDEX]
		)

		# ----------------------------------------------------
		# Indexed mesh
		# ----------------------------------------------------

		if not indices.is_empty():

			var triangle_count := indices.size() / 3

			for i in range(triangle_count):

				var i0 := indices[i * 3]
				var i1 := indices[i * 3 + 1]
				var i2 := indices[i * 3 + 2]

				output.append(
					transform * vertices[i0]
				)

				output.append(
					transform * vertices[i1]
				)

				output.append(
					transform * vertices[i2]
				)

		# ----------------------------------------------------
		# Non-indexed mesh
		# ----------------------------------------------------

		else:

			var triangle_count := vertices.size() / 3

			for i in range(triangle_count):

				output.append(
					transform * vertices[i * 3]
				)

				output.append(
					transform * vertices[i * 3 + 1]
				)

				output.append(
					transform * vertices[i * 3 + 2]
				)


# ============================================================
# Collider für Special Instances
# ============================================================

func _create_special_collider(
	wrapper: Node3D,
	parts: Array
) -> void:

	var faces := PackedVector3Array()

	for part in parts:

		var mesh: Mesh = part["mesh"]

		if mesh == null:
			continue

		var internal_transform: Transform3D = (
			part["internal_transform"]
		)

		_append_mesh_faces(
			mesh,
			internal_transform,
			faces
		)

	if faces.is_empty():

		printerr(
			"[COLLIDER] Special Instance enthält keine Geometrie: ",
			wrapper.name
		)

		return

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)

	var static_body := StaticBody3D.new()
	static_body.name = "__Collider"

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape

	static_body.add_child(collision_shape)
	wrapper.add_child(static_body)

	print(
		"[COLLIDER] Special Collider erstellt: ",
		wrapper.name,
		" | Dreiecke=",
		faces.size() / 3
	)

# ============================================================
# Set owner recursively
# ============================================================

func _set_owner_recursive(
	node: Node,
	owner_node: Node
) -> void:

	node.owner = owner_node

	for child in node.get_children():

		_set_owner_recursive(
			child,
			owner_node
		)


# ============================================================
# JSON loading
# ============================================================

func _load_json(path: String) -> Variant:

	if not FileAccess.file_exists(path):

		printerr(
			"Файл не найден: ",
			path
		)

		return null

	var f := FileAccess.open(
		path,
		FileAccess.READ
	)

	var json := JSON.new()

	if json.parse(
		f.get_as_text()
	) != OK:

		printerr(
			"Ошибка парсинга JSON: ",
			path
		)

		return null

	return json.data


# ============================================================
# Build folder hierarchy
# ============================================================

func _build_folder_hierarchy(
	world_tree: Array
) -> Dictionary:

	var by_index: Dictionary = {}
	var folder_nodes: Dictionary = {}

	for n: Dictionary in world_tree:

		by_index[int(n["index"])] = n

		if n.get("type") == 0:

			var fname: String = String(
				n.get(
					"folder_name",
					""
				)
			)

			if fname.is_empty():

				fname = (
					"Folder_%d"
					% int(n["index"])
				)

			var fnode := Node3D.new()

			fnode.name = fname

			folder_nodes[
				int(n["index"])
			] = fnode

	# Link folder hierarchy.

	for folder_index in folder_nodes:

		var n: Dictionary = (
			by_index[folder_index]
		)

		var parent_id := int(
			n.get(
				"parent_id",
				-1
			)
		)

		if folder_nodes.has(parent_id):

			folder_nodes[parent_id].add_child(
				folder_nodes[folder_index]
			)

	return {
		"folders": folder_nodes,
		"by_index": by_index
	}


# ============================================================
# Resolve folder
# ============================================================

func _resolve_folder(
	start_parent_id: int,
	folder_nodes: Dictionary,
	by_index: Dictionary,
	cache: Dictionary
) -> int:

	if cache.has(start_parent_id):

		return cache[start_parent_id]

	var pid := start_parent_id

	var result := -1

	var seen: Dictionary = {}

	while (
		by_index.has(pid)
		and not seen.has(pid)
	):

		seen[pid] = true

		if folder_nodes.has(pid):

			result = pid
			break

		pid = int(
			by_index[pid].get(
				"parent_id",
				-1
			)
		)

	cache[start_parent_id] = result

	return result


# ============================================================
# Resolve model file
# ============================================================

func _resolve_node_file(
	node: Dictionary,
	model_map: Dictionary,
	object_model_map: Dictionary
) -> String:

	var node_type = node.get("type")

	var file_path: String = ""

	if node_type == 1:

		var mid = node.get("model_id")

		if (
			mid != null
			and model_map.has(int(mid))
		):

			file_path = model_map[int(mid)]

	elif node_type == 2:

		var oid = node.get("object_id")

		if (
			oid != null
			and object_model_map.has(int(oid))
		):

			file_path = object_model_map[int(oid)]

	if file_path.is_empty():
		return ""

	file_path = file_path.replace(
		"\\",
		"/"
	)

	if file_path.to_lower().ends_with(
		".nmf"
	):

		file_path = (
			file_path.substr(
				0,
				file_path.length() - 4
			)
			+ ".glb"
		)

	return file_path


# ============================================================
# Resolve all instances
# ============================================================

func _resolve_instances(
	world_tree: Array,
	models_info: Array,
	object_list: Array,
	folder_info: Dictionary
) -> Dictionary:

	var model_map: Dictionary = {}

	for m in models_info:

		model_map[
			int(m["index"])
		] = String(
			m["system_filepath"]
		)

	var object_model_map: Dictionary = {}

	for o in object_list:

		var models: Array = (
			o.get(
				"models",
				[]
			)
		)

		if models.is_empty():
			continue

		var chosen: Dictionary = (
			models[0]
		)

		var mid := int(
			chosen.get(
				"model_3d_id",
				-1
			)
		)

		if model_map.has(mid):

			object_model_map[
				int(o["index"])
			] = model_map[mid]

	var folder_nodes: Dictionary = (
		folder_info["folders"]
	)

	var by_index: Dictionary = (
		folder_info["by_index"]
	)

	var folder_cache: Dictionary = {}

	# --------------------------------------------------------
	# Find special instance -> instance relationships.
	# --------------------------------------------------------

	var special_indices: Dictionary = {}

	for node: Dictionary in world_tree:

		var t = node.get("type")

		if t != 1 and t != 2:
			continue

		var parent_id := int(
			node.get(
				"parent_id",
				-1
			)
		)

		var parent_node: Dictionary = (
			by_index.get(
				parent_id,
				{}
			)
		)

		var parent_type = (
			parent_node.get("type")
		)

		if (
			parent_type == 1
			or parent_type == 2
		):

			special_indices[
				int(node["index"])
			] = true

			special_indices[
				parent_id
			] = true

	# --------------------------------------------------------
	# Resolve normal and special instances.
	# --------------------------------------------------------

	var instances_by_file: Dictionary = {}
	var special_instances: Dictionary = {}

	for node: Dictionary in world_tree:

		var file_path := _resolve_node_file(
			node,
			model_map,
			object_model_map
		)

		if file_path.is_empty():
			continue

		var idx := int(
			node["index"]
		)

		var parent_id := int(
			node.get(
				"parent_id",
				-1
			)
		)

		# ----------------------------------------------------
		# Special instance
		# ----------------------------------------------------

		if special_indices.has(idx):

			special_instances[idx] = {
				"file_path": file_path,
				"pos": [
					node["x"],
					node["y"],
					node["z"]
				],
				"rot": float(
					node.get(
						"rotation",
						0.0
					)
				),
				"scale": float(
					node.get(
						"scaling",
						1.0
					)
				),
				"parent_id": parent_id,
			}

			continue

		# ----------------------------------------------------
		# Normal instance
		# ----------------------------------------------------

		var folder_key := _resolve_folder(
			parent_id,
			folder_nodes,
			by_index,
			folder_cache
		)

		if not instances_by_file.has(
			file_path
		):

			instances_by_file[file_path] = {}

		var by_folder: Dictionary = (
			instances_by_file[file_path]
		)

		if not by_folder.has(
			folder_key
		):

			by_folder[folder_key] = []

		by_folder[folder_key].append({
			"pos": [
				node["x"],
				node["y"],
				node["z"]
			],
			"rot": float(
				node.get(
					"rotation",
					0.0
				)
			),
			"scale": float(
				node.get(
					"scaling",
					1.0
				)
			),
		})

	return {
		"by_file": instances_by_file,
		"special": special_instances
	}


# ============================================================
# Instance transform
# ============================================================

func _compute_instance_transform(
	pos_arr: Array,
	rot: float,
	scale: float
) -> Transform3D:

	var position := Vector3(
		pos_arr[0],
		pos_arr[1],
		-pos_arr[2]
	)

	var scale_vec := Vector3(
		scale,
		scale,
		scale
	)

	var xform := (
		Transform3D()
		.scaled(scale_vec)
	)

	xform = xform.rotated(
		Vector3.UP,
		-rot
	)

	xform.origin = position

	return xform


# ============================================================
# Load model mesh parts
# ============================================================

func _load_mesh_parts(
	file_path: String,
	cache: Dictionary
) -> Array:

	if cache.has(file_path):
		return cache[file_path]

	var parts: Array = []

	var res_path := (
		"res://Clou2/Clou2_unpack/"
		+ file_path
	)

	if not ResourceLoader.exists(res_path):

		printerr(
			"Файл модели не найден: ",
			res_path
		)

		cache[file_path] = parts
		return parts

	var model_scene := (
		load(res_path) as PackedScene
	)

	if not model_scene:

		cache[file_path] = parts
		return parts

	var dummy_root := (
		model_scene.instantiate()
	)

	for mesh_instance in get_all_mesh_instances(dummy_root):

		var source_mesh: Mesh = mesh_instance.mesh

		if source_mesh == null:
			continue

		# ------------------------------------------------
		# Flip triangle winding and normals.
		#
		# The imported world uses the opposite orientation
		# after the coordinate-system conversion.
		# ------------------------------------------------

		var mesh := _flip_mesh_normals(source_mesh)

		if mesh == null:
			printerr(
				"[MESH] Konnte Mesh nicht flippen: ",
				mesh_instance.name
			)
			continue

		# ------------------------------------------------
		# Calculate the transform relative to dummy_root.
		# ------------------------------------------------

		var internal_transform := (
			Transform3D.IDENTITY
		)

		var current_node: Node = mesh_instance

		while (
			current_node
			and current_node is Node3D
		):

			internal_transform = (
				current_node.transform
				* internal_transform
			)

			if current_node == dummy_root:
				break

			current_node = current_node.get_parent()

		# ------------------------------------------------
		# Material
		# ------------------------------------------------

		var material: Material = null

		if mesh_instance.material_override:

			material = (
				mesh_instance.material_override
			)

		elif mesh_instance.get_surface_override_material(0):

			material = (
				mesh_instance
				.get_surface_override_material(0)
			)

		parts.append({
			"name": mesh_instance.name,
			"mesh": mesh,
			"internal_transform": internal_transform,
			"material": material,
		})

	dummy_root.queue_free()

	cache[file_path] = parts

	return parts


# ============================================================
# Find all MeshInstance3D nodes
# ============================================================

func get_all_mesh_instances(
	node: Node
) -> Array[MeshInstance3D]:

	var result: Array[MeshInstance3D] = []

	if node is MeshInstance3D:

		result.append(
			node
		)

	for child in node.get_children():

		result.append_array(
			get_all_mesh_instances(child)
		)

	return result


func _flip_mesh_normals(
	source_mesh: Mesh
) -> ArrayMesh:

	var flipped_mesh := ArrayMesh.new()

	for surface in range(source_mesh.get_surface_count()):

		var arrays: Array = (
			source_mesh.surface_get_arrays(surface)
		)

		if arrays.is_empty():
			continue

		var vertices: PackedVector3Array = (
			arrays[Mesh.ARRAY_VERTEX]
		)

		if vertices.is_empty():
			continue

		# ------------------------------------------------
		# Flip stored vertex normals.
		# ------------------------------------------------

		var normals: PackedVector3Array = (
			arrays[Mesh.ARRAY_NORMAL]
		)

		if not normals.is_empty():

			for i in range(normals.size()):

				normals[i] = -normals[i]

			arrays[Mesh.ARRAY_NORMAL] = normals

		# ------------------------------------------------
		# Reverse triangle winding.
		#
		# (a, b, c) becomes (a, c, b)
		# ------------------------------------------------

		var indices: PackedInt32Array = (
			arrays[Mesh.ARRAY_INDEX]
		)

		if not indices.is_empty():

			for i in range(0, indices.size(), 3):

				if i + 2 >= indices.size():
					break

				var temp := indices[i + 1]

				indices[i + 1] = indices[i + 2]
				indices[i + 2] = temp

			arrays[Mesh.ARRAY_INDEX] = indices

		else:

			# --------------------------------------------
			# Non-indexed mesh:
			# Swap complete vertices in each triangle.
			#
			# We must also swap all per-vertex attributes,
			# otherwise UVs/normals/etc. no longer match.
			# --------------------------------------------

			_flip_non_indexed_triangle_arrays(
				arrays,
				vertices.size()
			)

		# ------------------------------------------------
		# Preserve the primitive type where possible.
		# Most imported meshes should be triangles.
		# ------------------------------------------------

		flipped_mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,
			arrays
		)

		# Preserve the surface material.
		var surface_material := (
			source_mesh.surface_get_material(surface)
		)

		if surface_material:

			flipped_mesh.surface_set_material(
				flipped_mesh.get_surface_count() - 1,
				surface_material
			)

	return flipped_mesh
	
func _flip_non_indexed_triangle_arrays(
	arrays: Array,
	vertex_count: int
) -> void:

	for i in range(0, vertex_count, 3):

		if i + 2 >= vertex_count:
			break

		# Alle Arrays durchgehen, deren Daten pro Vertex
		# gespeichert sind.

		for array_index in range(arrays.size()):

			var attribute = arrays[array_index]

			if attribute == null:
				continue

			# Nur Arrays behandeln, die genau einen Wert
			# pro Vertex enthalten.

			if attribute is PackedVector3Array:

				var data: PackedVector3Array = attribute

				if data.size() == vertex_count:

					var temp = data[i + 1]
					data[i + 1] = data[i + 2]
					data[i + 2] = temp

					arrays[array_index] = data

			elif attribute is PackedVector2Array:

				var data: PackedVector2Array = attribute

				if data.size() == vertex_count:

					var temp = data[i + 1]
					data[i + 1] = data[i + 2]
					data[i + 2] = temp

					arrays[array_index] = data

			elif attribute is PackedColorArray:

				var data: PackedColorArray = attribute

				if data.size() == vertex_count:

					var temp = data[i + 1]
					data[i + 1] = data[i + 2]
					data[i + 2] = temp

					arrays[array_index] = data

			elif attribute is PackedFloat32Array:

				var data: PackedFloat32Array = attribute

				if data.size() == vertex_count:

					var temp = data[i + 1]
					data[i + 1] = data[i + 2]
					data[i + 2] = temp

					arrays[array_index] = data
