extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_talk_mouse_entered() -> void:
	get_node("/root/Control").active_burglar.selected_interaction = 0


func _on_interact_mouse_entered() -> void:
	get_node("/root/Control").active_burglar.selected_interaction = 1

func _on_inspect_mouse_entered() -> void:
	get_node("/root/Control").active_burglar.selected_interaction = 2


func _on_talk_mouse_exited() -> void:
	get_node("/root/Control").active_burglar.selected_interaction = 3


func _on_interact_mouse_exited() -> void:
	get_node("/root/Control").active_burglar.selected_interaction = 3



func _on_inspect_mouse_exited() -> void:
	get_node("/root/Control").active_burglar.selected_interaction = 3
