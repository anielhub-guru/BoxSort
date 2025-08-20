# level_goals_display.gd

# A script to display goals using a Label node.

extends Node2D

class_name level_goal_display



# An export variable to link the Label node from the scene

@export var goal_label: Label



# Helper function to update the label text

func _update_display(goals: Dictionary):
	print("Received 'goals_updated' signal with: ", goals)
	if goals.is_empty():
		# Show default message when no goals are set
		goal_label.text = Global.get_default_message()
		print("Displayed default message.")
		return	


# Get current progress from Global

var progress = Global.get_progress()


# Build a string to display all the goals with progress.

var goal_text = "GOALS:\n"
var color_names = ["Cyan", "Orange", "Green"]

for goal_type in goals.keys():
	var current = progress.get(goal_type, 0)
	var target = goals[goal_type]
	var color_name = color_names[goal_type] if goal_type < color_names.size() else "Color " + str(goal_type)


goal_text += color_name + ": " + str(current) + "/" + str(target)

if current >= target:

goal_text += " ✓"

goal_text += "\n"


# Update the text of the Label node.

goal_label.text = goal_text

print("Successfully updated goal display.")



# Function to display default message

func _display_default_message():

if goal_label == null:

print("ERROR: goal_label is not assigned in the editor!")

return


goal_label.text = Global.get_default_message()

print("Displayed default message: ", Global.get_default_message())



# Called when the node enters the scene tree for the first time.

func _ready():

# Check if the goal_label has been assigned in the editor.

if goal_label == null:

print("ERROR: goal_label is not assigned in the editor!")

return


print("level_goal_display is ready and listening for signals.")


# Connect to the signal from our Global singleton.

Global.goals_updated.connect(_update_display)


# Check if goals have already been set, otherwise show default message

if Global.has_goals():

print("Goals already set, updating display now.")

_update_display(Global.level_goals)

else:

print("No goals set, showing default message.")

_display_default_message()
