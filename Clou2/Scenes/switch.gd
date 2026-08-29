extends "res://assets/scripts/Interactable/interactable.gd"

@export var ticks_to_reset := 250

var ticks_to_reset_at: Array [int] = []

func update_interactable(delta):
	super(delta)
	
	var control = get_node("/root/Control")
	#var anim_position := 0.0
	#
	#if anim_player:
		#anim_position = anim_player.current_animation_position
		#
	#if(previous_animation_position != current_animation_clip_length  && anim_position == current_animation_clip_length  && !control.pause && !control.backwards):
		#append_switch_timer(control.ticks)
	
	if(ticks_to_reset_at.size() > 0):	
		#if(control).ticks == ticks_to_reset_at[ticks_to_reset_at.size()-1][0]):
			#print("backwards? " + str(owner.backwards))
		
		if(control.ticks == ticks_to_reset_at[ticks_to_reset_at.size()-1]+ticks_to_reset):
			for obj in related_objects:
				obj.toggle_power_state()	
			
		if(!control.backwards):	
			if(control.ticks == ticks_to_reset_at[ticks_to_reset_at.size()-1]+ticks_to_reset):
				play_animation(animation_name, true, true)
				#ticks_to_reset_at.erase(ticks_to_reset_at.back())
			#elif(control.ticks > ticks_to_reset_at[ticks_to_reset_at.size()-1]+ticks_to_reset):
				#play_animation(animation_name, true, true)
				#anim_player.advance(1.0/control.FPS)
				#ticks_to_reset_at.erase(ticks_to_reset_at.back())
				#ticks_to_reset_at.erase(ticks_to_reset_at.back())
				#for obj in related_objects:
					#obj.toggle_power_state()
		else:
			if(control.ticks == ticks_to_reset_at[ticks_to_reset_at.size()-1]+ticks_to_reset+opening_time): #+opening_time
				play_animation(animation_name, false, true)
				#ticks_to_reset_at.erase(ticks_to_reset_at.back())
			#elif(control.ticks < ticks_to_reset_at[ticks_to_reset_at.size()-1]+ticks_to_reset+opening_time):
				#play_animation(animation_name, false, true)
				#anim_player.advance(1.0/control.FPS)
				#ticks_to_reset_at.erase(ticks_to_reset_at.back())
				#for obj in related_objects:
					#obj.toggle_power_state()
				
func append_switch_timer(ticks: int)->void:
	if(ticks_to_reset != 0):
		if(ticks_to_reset_at.is_empty() or ticks_to_reset_at.back() != ticks):
			ticks_to_reset_at.append(ticks)
