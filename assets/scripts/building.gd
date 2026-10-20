extends Node

@export var number_of_floors = 0
@export var min_loot = 0
@export var music_track:AudioStreamOggVorbis
@export var max_distance_squared_from_mission = 50.0
@onready var mission_center = $MissionCenter
var current_visible_floor = 0 
