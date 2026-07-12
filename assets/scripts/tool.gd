extends "res://assets/Scenes/Items/item.gd"

## lockpicking, safecracking,alarms efficency in percent (e.g. 50.0%)
@export var tool_efficencies:Array[float] = [0.0,0.0,0.0]

## loudness for wood, metal and glass in percent (e.g. 50.0%)
@export var loudness:Array[float] = [0.0,0.0,0.0]

@export var damaging = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	super(delta)
	
