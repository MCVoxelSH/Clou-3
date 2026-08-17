@tool
extends "res://assets/scripts/Interactable/interactable.gd"

@export_category("Loot")

@export var value := 0
@export var weight := 1.0
@export var unique_name := ""

@export_category("Loot Setup")

@export var loot_mesh: PackedScene

@export var generate_colliders = false

@export var setup_loot := false:
	set(value):
		setup_loot = value

		if value and Engine.is_editor_hint():
			_setup_loot()
			setup_loot = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	var area := get_node_or_null("Area3D")
		
	super()

func update_interactable(delta: float) -> void:
	super(delta)


func _setup_loot() -> void:
	if loot_mesh == null:
		return

	object_type = 4
	
	# Bereits vorhandenes automatisch erzeugtes Objekt entfernen
	var old_visual := get_node_or_null("LootVisual")
	if old_visual:
		old_visual.free()

	# GLB/Scene instanziieren
	var visual := loot_mesh.instantiate()
	visual.name = "LootVisual"

	add_child(visual)
	visual.owner = get_tree().edited_scene_root
	
	_create_area(self)
	
	# Hier können später Area/Collision automatisch erzeugt werden.
	if generate_colliders:
		_create_loot_colliders(visual)



func _create_loot_colliders(visual: Node3D) -> void:
	_create_static_body(self)

func _create_area(model: Node3D) -> void:
	var old_area := get_node_or_null("Area3D")
	if old_area:
		old_area.free()

	var area := Area3D.new()
	area.name = "Area3D"

	var enter_callable = Callable(self, "_on_area_3d_mouse_entered")
	var exit_callable = Callable(self, "_on_area_3d_mouse_exited")

	# 2. Verbinde die Signale und nutze CONNECT_PERSIST (Speichert sie in die .tscn)
	if not area.mouse_entered.is_connected(enter_callable):
		area.mouse_entered.connect(enter_callable, CONNECT_PERSIST)

	if not area.mouse_exited.is_connected(exit_callable):
		area.mouse_exited.connect(exit_callable, CONNECT_PERSIST)

	area.scale = Vector3(0.1,0.1,0.1)
	

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"

	var result := _create_collision(model)

	if result.is_empty():
		return

	collision.shape = result["shape"]
	collision.position = Vector3.ZERO

	area.add_child(collision)
	add_child(area)

	area.owner = get_tree().edited_scene_root
	collision.owner = get_tree().edited_scene_root
	
func _create_static_body(model: Node3D) -> void:
	var old_area := get_node_or_null("StaticBody3D")
	if old_area:
		old_area.free()

	
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	body.input_ray_pickable = false
	body.scale = Vector3(0.1,0.1,0.1)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"

	var result := _create_collision(model)

	if result.is_empty():
		return

	collision.shape = result["shape"]
	collision.position = Vector3.ZERO

	body.add_child(collision)
	add_child(body)

	body.owner = get_tree().edited_scene_root
	collision.owner = get_tree().edited_scene_root
	
func _create_collision(root: Node3D) -> Dictionary:
	var meshes: Array[MeshInstance3D] = []

	_find_meshes(root, meshes)

	if meshes.is_empty():
		return {}

	var aabb: AABB

	var first := true

	for mesh in meshes:
		var mesh_aabb := mesh.get_aabb()
		mesh_aabb = mesh.global_transform * mesh_aabb

		if first:
			aabb = mesh_aabb
			first = false
		else:
			aabb = aabb.merge(mesh_aabb)

	var shape := BoxShape3D.new()
	shape.size = aabb.size

	return {
		"shape": shape,
		"position": aabb.get_center()
	}
	
func _find_meshes(
	node: Node,
	result: Array[MeshInstance3D]
) -> void:

	if node is MeshInstance3D:
		result.append(node)

	for child in node.get_children():
		_find_meshes(child, result)
		

func _on_area_3d_mouse_entered() -> void:
	super()
	
func _on_area_3d_mouse_exited() -> void:
	super()
