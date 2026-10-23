extends "res://assets/Scenes/camera.gd"

@export var offset = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
		if((get_node("/root/Control").ticks + offset) % 90 <= 45):
			turn_off_power()
		else:
			turn_on_power()

	
