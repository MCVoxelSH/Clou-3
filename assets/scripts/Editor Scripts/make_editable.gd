@tool
extends EditorScript

func _run() -> void:
	var interface := EditorInterface
	var selection := interface.get_selection().get_selected_nodes()

	if selection.is_empty():
		printerr("Keine Node im Scene Tree ausgewählt.")
		return

	for node in selection:
		var parent := node.get_parent()

		if parent:
			parent.set_editable_instance(node, true)
			print("Editable Children aktiviert für:", node.name)
