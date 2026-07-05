extends "res://assets/scripts/Interactable/interactable.gd"

@export var max_capacity = 100.0
@export var speed = 90.0

#current weight in car
var current_load = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func update_interactable(delta: float) -> void:
	super(delta)
