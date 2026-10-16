extends "res://assets/scripts/Interactable/Alarm.gd"

@export var hearing = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func update_interactable(delta: float) -> void:
	super(delta)
