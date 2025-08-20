# level_goals_display.gd
# A script to display goals using a Label node.
extends Node2D
class_name display_level_goals

# An export variable to link the Label node from the scene
@export var goal_label: RichTextLabel
var font_size = 35

func _update_display(level_goals: Dictionary, tile_info: Dictionary, colors: Array):
	print("Received 'goals_updated' signal with: ", level_goals)
	
	if level_goals.is_empty():
		goal_label.text = Global.get_default_message()
		print("Displayed default message.")
		return
	
	var progress = Global.get_progress()
	var goal_text = ""
	
	for goal_type in level_goals.keys():
		var current = progress.get(goal_type, 0)
		var target = level_goals[goal_type]
		var tile_path = tile_info.get(goal_type, "")
		
		# Now use print_rich to check the full path for debugging
		print_rich(tile_path)
		
		var color_code = colors[goal_type]
		
		goal_text += "[bgcolor=" + color_code.to_html(false) + "]"
		
		#if tile_path != "":
			#goal_text += "[img=24]" + tile_path + "[/img]"
		#else:
			#goal_text += "Color " + str(goal_type)
		
		goal_text += "[/bgcolor]"
		
		goal_text += "[font_size=" + str(font_size) + "][b]"
		goal_text += " " + str(current) + "/" + str(target)
		if current >= target:
			goal_text += " ✓"
		goal_text += "[/b][/font_size]"
		goal_text += " "
	
	goal_label.text = goal_text
	print("Successfully updated goal display.")


# Function to display default message
func display_default_message():
	if goal_label == null:
		print("ERROR: goal_label is not assigned in the editor!")
		return

	goal_label.text = Global.get_default_message()
	print_rich("[color=teal][b]Displayed default message:[/b][/color]", Global.get_default_message())

# Called when the node enters the scene tree for the first time.
func _ready():
	if goal_label == null:
		print("ERROR: goal_label is not assigned in the editor!")
		return
	
	print("display_level_goals is ready and listening for signals.")
	
	# Connect to the signal from our Global singleton.
	Global.goals_updated.connect(_update_display)
	
	# Pass all three arguments to _update_display, as the signal emits them.
	_update_display(Global.level_goals, Global.level_tile_info, Global.level_colors)
