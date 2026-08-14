@tool
extends EditorScript

# 1. Path to your new scene
const NEW_SCENE_PATH = "res://Clou2/Clou2_unpack_new_textures/models/Böden/Boden1x1 [GroberSchotter]_1014.glb"

func _run() -> void:
	var interface := EditorInterface
	var selection := interface.get_selection().get_selected_nodes()
	
	if selection.is_empty():
		printerr("Keine Node im Scene Tree ausgewählt.")
		return
	
	for old_node in selection:
		var scene_root = interface.get_edited_scene_root()
		var parent_node = old_node.get_parent()
		
		if old_node == scene_root or not parent_node:
			printerr("Die Root-Node kann nicht ersetzt werden.")
			return

		var packed_scene = load(NEW_SCENE_PATH) as PackedScene
		if not packed_scene:
			printerr("Fehler beim Laden der Szene: ", NEW_SCENE_PATH)
			return
			
		var new_node = packed_scene.instantiate()
		
		# Zwischenspeichern der Transformation, solange die alte Node noch im Tree ist
		var old_transform = null
		if "global_transform" in old_node:
			old_transform = old_node.global_transform

		var undo_redo := interface.get_editor_undo_redo()
		undo_redo.create_action("Replace Scene Node")
		
		# --- DO ACTIONS (Ausführen) ---
		# 1. Neue Node hinzufügen (lesbar für den Editor)
		undo_redo.add_do_method(parent_node, "add_child", new_node, true)
		# 2. Position anpassen, sobald sie im Tree existiert
		if old_transform != null and "global_transform" in new_node:
			undo_redo.add_do_property(new_node, "global_transform", old_transform)
		# 3. Owner setzen (Wichtig für die Speicherung)
		undo_redo.add_do_property(new_node, "owner", scene_root)
		# 4. Alte Node sauber entfernen
		undo_redo.add_do_method(parent_node, "remove_child", old_node)
		undo_redo.add_do_reference(new_node)

		# --- UNDO ACTIONS (Rückgängig machen) ---
		# 1. Alte Node wieder hinzufügen
		undo_redo.add_undo_method(parent_node, "add_child", old_node, true)
		# 2. Alten Owner wiederherstellen
		undo_redo.add_undo_property(old_node, "owner", scene_root)
		# 3. Neue Node entfernen
		undo_redo.add_undo_method(parent_node, "remove_child", new_node)
		undo_redo.add_undo_reference(old_node)
		
		undo_redo.commit_action()
