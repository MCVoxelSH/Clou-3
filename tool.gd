extends Node3D

## lockpicking, safecracking,alarms efficency
@export var tool_efficencies:Array[int] = [0,0,0]

## loudness for wood, metal and glass
@export var loudness:Array[int] = [0,0,0]

@export var damaging = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
