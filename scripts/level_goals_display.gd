# level_goals_display.gd
# A script to display goals using separate UI elements for better control
extends Node2D
class_name display_level_goals

# Export variable for the main container (HBoxContainer for horizontal layout)
@export var goals_container: HBoxContainer
var font_size = 35

func _update_display(level_goals: Dictionary, tile_info: Dictionary, colors: Array):
	print("Received 'goals_updated' signal with: ", level_goals)
	print("DEBUG - tile_info contents: ", tile_info)
	print("DEBUG - colors array: ", colors, " size: ", colors.size())
	
	# Clear existing goal displays
	clear_goals_display()
	
	if level_goals.is_empty():
		display_default_message()
		return
	
	var progress = Global.get_progress()
	
	for goal_type in level_goals.keys():
		var current = progress.get(goal_type, 0)
		var target = level_goals[goal_type]
		var tile_resource = tile_info.get(goal_type, null)
		
		# Safe color access with bounds checking
		var color_code = Color.BLACK  # Default fallback color
		if colors.size() > 0 and goal_type < colors.size():
			color_code = colors[goal_type]
		elif colors.size() > 0:
			# Use modulo to wrap around if goal_type exceeds array size
			color_code = colors[goal_type % colors.size()]
		else:
			# Generate a fallback color based on goal_type if colors array is empty
			var hue = (goal_type * 0.618033988749) # Golden ratio for nice color distribution
			hue = hue - floor(hue)  # Keep fractional part
			color_code = Color.from_hsv(hue, 0.8, 0.9)
			print("Generated fallback color for goal_type ", goal_type, ": ", color_code)
		
		# Debug print to see what we're getting
		print("Goal type: ", goal_type, " Tile resource: ", tile_resource, " Color: ", color_code)
		
		create_goal_item(goal_type, current, target, tile_resource, color_code)
	
	print("Successfully updated goal display with separate UI elements.")

func create_goal_item(goal_type: int, current: int, target: int, tile_resource, color_code: Color):
	# Add horizontal spacing before this goal (except for the first one)
	print("DEBUG - goal_type: ", goal_type, " tile_resource type: ", typeof(tile_resource), " value: ", tile_resource)
	# === ADD THIS DEBUG SECTION AT THE VERY TOP ===
	print("=== TEXTURE DEBUG ===")
	print("Goal type: ", goal_type)
	print("Tile resource: ", tile_resource)
	print("Texture type: ", typeof(tile_resource))
	print("Texture class: ", tile_resource.get_class() if tile_resource != null else "null")
	
	if tile_resource != null and tile_resource is Texture:
		print("Texture size: ", tile_resource.get_size())
		print("Texture width: ", tile_resource.get_width())
		print("Texture height: ", tile_resource.get_height())
		
		# Check if it's a ViewportTexture specifically
		if tile_resource is ViewportTexture:
			print("This is a ViewportTexture")
			var viewport_tex = tile_resource as ViewportTexture
			print("Viewport texture path: ", viewport_tex.viewport_path)
	print("=== END TEXTURE DEBUG ===")
	
	if goals_container.get_child_count() > 0:
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(15, 0)  # Horizontal spacing
		goals_container.add_child(spacer)
	
	# Create main container for this goal
	var goal_item = VBoxContainer.new()
	goal_item.name = "goal_item_" + str(goal_type)
	goal_item.custom_minimum_size = Vector2(90, 100)  # Fixed size for consistent appearance
	goal_item.add_theme_constant_override("separation", 4)
	goal_item.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Create background panel with proper styling
	var background_panel = Panel.new()
	background_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	background_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = color_code
	style_box.corner_radius_top_left = 12
	style_box.corner_radius_top_right = 12
	style_box.corner_radius_bottom_left = 12
	style_box.corner_radius_bottom_right = 12
	# Add border for definition
	style_box.border_width_left = 2
	style_box.border_width_right = 2  
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color.WHITE.darkened(0.2)
	background_panel.add_theme_stylebox_override("panel", style_box)
	
	# Create content container
	var content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 6)
	content_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Add tile image
	if tile_resource != null and tile_resource is Texture:
		var texture_rect = TextureRect.new()
		texture_rect.texture = tile_resource
		texture_rect.texture = preload("res://images/Mangotile.png") #Hard coded quick fix
		texture_rect.modulate = color_code 
		texture_rect.custom_minimum_size = Vector2(40, 40)
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		content_container.add_child(texture_rect)
		print("Added ViewportTexture for goal_type: ", goal_type)

	else:
		# Fallback colored rectangle
		var fallback_rect = ColorRect.new()
		fallback_rect.color = Color.WHITE.darkened(0.3)
		fallback_rect.custom_minimum_size = Vector2(40, 40)
		content_container.add_child(fallback_rect)
		print("No texture found for goal_type: ", goal_type, " - using color fallback")
	
	# Create progress text
	var text_label = Label.new()
	text_label.text = str(current) + "/" + str(target)
	if current >= target:
		text_label.text += "✓"
		text_label.add_theme_color_override("font_color", Color.BLACK)
	else:
		text_label.add_theme_color_override("font_color", Color.BLACK)
	
	# Style the text
	text_label.add_theme_font_size_override("font_size", 20)  # Readable size
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	content_container.add_child(text_label)
	
	# Add padding around content
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 10)
	margin_container.add_theme_constant_override("margin_right", 10)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	margin_container.add_child(content_container)
	
	# Assemble the goal item
	background_panel.add_child(margin_container)
	goal_item.add_child(background_panel)
	
	# Add the completed goal item to the main container
	goals_container.add_child(goal_item)

func clear_goals_display():
	"""Clear all existing goal display items"""
	if goals_container == null:
		print("ERROR: goals_container is not assigned in the editor!")
		return
	
	# Remove all children from the container
	for child in goals_container.get_children():
		child.queue_free()

func display_default_message():
	"""Display default message when no goals are present"""
	if goals_container == null:
		print("ERROR: goals_container is not assigned in the editor!")
		return
	
	var default_label = Label.new()
	default_label.text = Global.get_default_message()
	default_label.add_theme_font_size_override("font_size", font_size)
	default_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goals_container.add_child(default_label)
	print_rich("[color=teal][b]Displayed default message:[/b][/color]", Global.get_default_message())

# Called when the node enters the scene tree for the first time.
func _ready():
	if goals_container == null:
		print("ERROR: goals_container is not assigned in the editor!")
		return
	
	print("display_level_goals is ready and listening for signals.")
	
	# Connect to the signal from our Global singleton
	Global.goals_updated.connect(_update_display)
	
	# Initialize display - Pass all three arguments to _update_display
	_update_display(Global.level_goals, Global.level_tile_info, Global.level_colors)
