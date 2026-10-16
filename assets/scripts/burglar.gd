extends "res://assets/scripts/character.gd"


@onready var bag= $Bag
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	
	for c in GlobalFunctions.get_all_children(self):
		if(c.name == "Bag2" || c.name == "Bag3"):
			c.visible = false
		elif(c.name == "Bag1" && is_guard):
			c.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	super(delta)

func update_bag():
	if(current_carrying_weight >= max_capacity * 0.7):
		for c in GlobalFunctions.get_all_children(self):
			if(c.name == "Bag1" || c.name == "Bag2"):
				c.visible = false
			elif(c.name == "Bag3"):
				c.visible = true
	elif(current_carrying_weight >= max_capacity * 0.05):
		for c in GlobalFunctions.get_all_children(self):
			if(c.name == "Bag1" || c.name == "Bag3"):
				c.visible = false
			elif(c.name == "Bag2"):
				c.visible = true
	else:
		for c in GlobalFunctions.get_all_children(self):
			if(c.name == "Bag2" || c.name == "Bag3"):
				c.visible = false
			elif(c.name == "Bag1"):
				c.visible = true
		
