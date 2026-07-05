extends "res://assets/scripts/Interactable/interactable.gd"

@export var value = 0
@export var weight = 1.0
@export var unique_name = ""
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func update_interactable(delta: float) -> void:
	super(delta)
