@tool
extends EditorScript


# ============================================================
# Einstellungen
# ============================================================

# Wenn true, werden bereits vorhandene Collider mit diesem
# Namen übersprungen.
const COLLIDER_NAME := "__GeneratedCollider"


# ============================================================
# Einstieg
# ============================================================

func _run() -> void:
	print("")
	print("================================================")
	print(" MultiMesh Collider Generator")
	print("================================================")

	var root := EditorInterface.get_edited_scene_root()

	if root == null:
		printerr("Keine geöffnete Szene gefunden.")
		return

	print("Scene Root: ", root.get_path())

	# --------------------------------------------------------
	# 1. Alle MultiMeshes finden
	# --------------------------------------------------------

	var multimeshes: Array[MultiMeshInstance3D] = []

	print("Suche MultiMeshInstance3D ...")

	_collect_multimeshes(root, multimeshes)

	print("Gefundene MultiMeshes: ", multimeshes.size())

	if multimeshes.is_empty():
		print("Keine MultiMeshes gefunden.")
		return

	# --------------------------------------------------------
	# 2. MultiMeshes gruppieren
	# --------------------------------------------------------

	print("")
	print("Gruppiere Objekte ...")

	var groups: Dictionary = {}

	for mm in multimeshes:
		var key := _get_group_key(mm)

		if not groups.has(key):
			groups[key] = []

		groups[key].append(mm)

	print("Erkannte Objektgruppen: ", groups.size())

	# --------------------------------------------------------
	# 3. Collider erzeugen
	# --------------------------------------------------------

	var group_index := 0

	for key in groups:
		group_index += 1

		var group: Array = groups[key]

		print("")
		print(
			"[",
			group_index,
			"/",
			groups.size(),
			"] Erzeuge Collider: ",
			key,
			" (",
			group.size(),
			" MultiMeshes)"
		)

		_create_group_collider(
			key,
			group,
			root
		)

	print("")
	print("================================================")
	print("FERTIG")
	print("================================================")

	EditorInterface.mark_scene_as_unsaved()


# ============================================================
# Alle MultiMeshes rekursiv finden
# ============================================================

func _collect_multimeshes(
	node: Node,
	result: Array[MultiMeshInstance3D]
) -> void:

	if node is MultiMeshInstance3D:
		result.append(node)

	for child in node.get_children():
		_collect_multimeshes(child, result)


# ============================================================
# Gruppen-ID bestimmen
#
# Fall A:
#
# Nachtkasten_2368_15009
# ├── pPlaneShape107
# ├── pPlaneShape108
# └── pCubeShape12
#
# -> Parent wird als Gruppe verwendet.
#
#
# Fall B:
#
# SlinkySpider_2672_polySurfaceShape56
# SlinkySpider_2672_polySurfaceShape57
#
# -> gemeinsamer Präfix "SlinkySpider_2672"
# ============================================================

func _get_group_key(
	mm: MultiMeshInstance3D
) -> String:

	var parent := mm.get_parent()

	# --------------------------------------------------------
	# Wenn der Parent mehrere MultiMeshes enthält und selbst
	# wie ein Objekt-Container aussieht, verwenden wir ihn.
	# --------------------------------------------------------

	if parent != null:

		var sibling_multimeshes := 0

		for child in parent.get_children():
			if child is MultiMeshInstance3D:
				sibling_multimeshes += 1

		if sibling_multimeshes >= 2:
			return "PARENT:" + str(parent.get_path())


	# --------------------------------------------------------
	# Sonst versuchen wir den Namen zu normalisieren.
	#
	# Beispiel:
	#
	# SlinkySpider_2672_polySurfaceShape56
	#
	# -> SlinkySpider_2672
	# --------------------------------------------------------

	var name := mm.name

	var poly_index := name.find("_polySurfaceShape")

	if poly_index >= 0:
		return "NAME:" + name.substr(0, poly_index)


	# Weitere typische Maya Shape-Namen
	var shape_index := name.find("_pPlaneShape")

	if shape_index >= 0:
		return "NAME:" + name.substr(0, shape_index)

	shape_index = name.find("_pCubeShape")

	if shape_index >= 0:
		return "NAME:" + name.substr(0, shape_index)

	shape_index = name.find("_pCylinderShape")

	if shape_index >= 0:
		return "NAME:" + name.substr(0, shape_index)


	# --------------------------------------------------------
	# Fallback:
	# MultiMesh bleibt eine eigene Gruppe.
	# --------------------------------------------------------

	return "NODE:" + str(mm.get_path())


# ============================================================
# Collider für eine komplette Objektgruppe erstellen
# ============================================================

func _create_group_collider(
	group_name: String,
	group: Array,
	scene_root: Node
) -> void:

	if group.is_empty():
		return

	# --------------------------------------------------------
	# Prüfen, ob bereits ein Collider existiert.
	#
	# Wir hängen ihn unter den Parent der ersten MultiMesh.
	# --------------------------------------------------------

	var first_mm: MultiMeshInstance3D = group[0]

	var existing := first_mm.get_node_or_null(
		COLLIDER_NAME
	)

	if existing != null:
		print("  -> Collider existiert bereits, überspringe.")
		return


	# --------------------------------------------------------
	# Alle Dreiecke der Gruppe sammeln.
	#
	# concave_faces enthält immer:
	#
	# 3 Vector3 = 1 Dreieck
	# --------------------------------------------------------

	var concave_faces := PackedVector3Array()

	var total_instances := 0
	var total_triangles := 0


	for mm in group:

		if mm.multimesh == null:
			continue

		if mm.multimesh.mesh == null:
			continue

		var multimesh = mm.multimesh
		var mesh = mm.mesh

		var instance_count = multimesh.instance_count

		if instance_count == 0:
			continue

		# ----------------------------------------------------
		# Mesh-Dreiecke auslesen
		# ----------------------------------------------------

		var mesh_triangles := _get_mesh_triangles(mesh)

		if mesh_triangles.is_empty():
			continue

		# ----------------------------------------------------
		# Transform der MultiMeshInstance3D
		# ----------------------------------------------------

		var mm_transform = mm.global_transform

		# ----------------------------------------------------
		# Jede MultiMesh-Instanz
		# ----------------------------------------------------

		for instance_index in range(instance_count):

			var instance_transform = (
				multimesh.get_instance_transform(instance_index)
			)

			var final_transform = (
				mm_transform * instance_transform
			)

			# Alle Dreiecke transformieren
			for vertex in mesh_triangles:
				concave_faces.append(
					final_transform * vertex
				)

			total_instances += 1

			total_triangles += (
				mesh_triangles.size() / 3
			)

		# ----------------------------------------------------
		# Zwischenstand
		# ----------------------------------------------------

		if total_instances % 1000 == 0:
			print(
				"    Instanzen verarbeitet: ",
				total_instances
			)


	# --------------------------------------------------------
	# Keine Geometrie?
	# --------------------------------------------------------

	if concave_faces.is_empty():
		print("  -> Keine Kollisionsgeometrie gefunden.")
		return


	print(
		"  -> Instanzen: ",
		total_instances
	)

	print(
		"  -> Dreiecke: ",
		total_triangles
	)


	# --------------------------------------------------------
	# ConcavePolygonShape3D erstellen
	# --------------------------------------------------------

	var shape := ConcavePolygonShape3D.new()

	shape.set_faces(concave_faces)


	# --------------------------------------------------------
	# StaticBody
	# --------------------------------------------------------

	var static_body := StaticBody3D.new()

	static_body.name = COLLIDER_NAME


	# Da die Vertices bereits in globalen Koordinaten
	# vorliegen, muss der StaticBody selbst Identity haben.
	static_body.global_transform = Transform3D.IDENTITY


	# --------------------------------------------------------
	# CollisionShape
	# --------------------------------------------------------

	var collision_shape := CollisionShape3D.new()

	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape


	static_body.add_child(collision_shape)

	# Owner setzen
	static_body.owner = scene_root
	collision_shape.owner = scene_root


	# --------------------------------------------------------
	# Collider in die Szene einfügen
	#
	# Wir hängen ihn unter den Scene Root.
	# Dadurch gibt es keine zusätzlichen Transform-Probleme.
	# --------------------------------------------------------

	scene_root.add_child(static_body)

	print("  -> StaticBody erstellt.")


# ============================================================
# Dreiecke eines Meshes auslesen
# ============================================================

func _get_mesh_triangles(
	mesh: Mesh
) -> PackedVector3Array:

	var result := PackedVector3Array()

	for surface_index in range(mesh.get_surface_count()):

		var primitive = mesh.surface_get_primitive_type(
			surface_index
		)

		# Nur Dreiecke sind für die Collision interessant.
		if primitive != Mesh.PRIMITIVE_TRIANGLES:
			continue

		var arrays := mesh.surface_get_arrays(
			surface_index
		)

		if arrays.is_empty():
			continue

		var vertices: PackedVector3Array = (
			arrays[Mesh.ARRAY_VERTEX]
		)

		var indices: PackedInt32Array = (
			arrays[Mesh.ARRAY_INDEX]
		)

		# ----------------------------------------------------
		# Indexed Mesh
		# ----------------------------------------------------

		if not indices.is_empty():

			for i in range(0, indices.size(), 3):

				if i + 2 >= indices.size():
					break

				result.append(
					vertices[indices[i]]
				)

				result.append(
					vertices[indices[i + 1]]
				)

				result.append(
					vertices[indices[i + 2]]
				)


		# ----------------------------------------------------
		# Non-indexed Mesh
		# ----------------------------------------------------

		else:

			for i in range(0, vertices.size(), 3):

				if i + 2 >= vertices.size():
					break

				result.append(vertices[i])
				result.append(vertices[i + 1])
				result.append(vertices[i + 2])


	return result
