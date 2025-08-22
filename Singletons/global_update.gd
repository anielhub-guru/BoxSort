# Global.gd
# This is a singleton that can be accessed from any script in the game.
# It will manage the level goals and send signals when they are updated.
extends Node

# A signal that we can emit when the goals are updated.
# We pass both goals, tile info and colors
signal goals_updated(new_goals: Dictionary, new_tile_info: Dictionary, level_colors_array: Array)

# A new variable to store the colors array
var level_colors: Array = []

# A variable to store our level goals.
var level_goals: Dictionary = {}

# Variable to store level progress
var level_progress: Dictionary = {}

# Default message to display when no goals are set
var default_goals_message: String = "No goals set yet. Ready to start your adventure!"



# A new variable to store tile information.
var level_tile_info: Dictionary = {}

# A function to set goals and tile info, and emit the signal.
func set_goals(goals_dict: Dictionary, tile_info: Dictionary, colors: Array):
	level_goals = {}
	level_progress = {}
	
	for key in goals_dict:
		level_goals[int(key)] = goals_dict[key]
		level_progress[int(key)] = 0
	
	level_tile_info = tile_info
	level_colors = colors # Store the new colors array
	
	print("Emitting 'goals_updated' signal.")
	goals_updated.emit(level_goals, level_tile_info, level_colors)

# Function to update progress for a specific goal
func update_progress(goal_type: int, amount: int):
	if level_progress.has(goal_type):
		level_progress[goal_type] += amount
		
		# Now we can use the level_colors array here to get the Color8 value
		var goal_color_object = level_colors[goal_type] if goal_type < level_colors.size() else Color(0,0,0)
		print("Updated progress for goal ", goal_color_object, ": ", level_progress[goal_type], "/", level_goals[goal_type])
		
		# Emit signal to update displays
		goals_updated.emit(level_goals, level_tile_info, level_colors)


# Function to get current progress
func get_progress() -> Dictionary:
	return level_progress.duplicate()

# Function to check if all goals are complete
func are_goals_complete() -> bool:
	for goal_type in level_goals.keys():
		if level_progress.get(goal_type, 0) < level_goals[goal_type]:
			return false
	return level_goals.size() > 0

# Function to get the default message
func get_default_message() -> String:
	return default_goals_message

# Function to check if goals are set
func has_goals() -> bool:
	return level_goals.size() > 0
	
	
	
