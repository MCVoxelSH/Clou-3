extends SubViewportContainer

@onready var sub_viewport: SubViewport = $SubViewport

func _ready() -> void:
	# Informiert den Viewport einmalig, dass die Maus in seinem Bereich existiert
	sub_viewport.notify_mouse_entered()

func _unhandled_input(event: InputEvent) -> void:
	# Wenn eine Taste gedrückt, die Maus bewegt oder geklickt wird und das Event 
	# nicht von einem UI-Button konsumiert wurde, schicken wir es direkt an das 3D-System
	if event is InputEventMouse:
		# Erstellt eine lokale Kopie des Events für den SubViewport
		var local_event = event.duplicate()
		
		# Rechnet die globale Mausposition auf die Position innerhalb des Containers um
		local_event.position = get_local_mouse_position()
		if "global_position" in local_event:
			local_event.global_position = get_local_mouse_position()
			
		# Feuert das Event direkt in den 3D-Raum des SubViewports
		sub_viewport.push_input(local_event)
	
