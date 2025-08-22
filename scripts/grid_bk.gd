# grid.gd

extends Node2D

class_name GameManager_2

# --- Game Board Properties ---
# These variables control the size and layout of the game grid.
var grid_width = 6
var grid_height = 6
var cell_size = 90
var shelf_gap_x = 10
var shelf_gap_y = 15
var use_shelf_gaps = false # Flag to enable/disable visual gaps
var padding = 60
var next_level_btn
var restart_level_btn

# --- Game State and Data ---
# Stores the current state of the game board and game-related information.
var grid_data = [] # A 2D array to hold references to DraggableItem nodes
var draggable_item_scene = preload("res://scene/DraggableItem.tscn")
# Colors for the different item types in the game.
const colors = [
	Color8(77, 255, 255), # Cyan
	Color8(255, 179, 77), # Orange
	Color8(82, 224, 149) # Green
]
const BOMB_MATCH_COUNT = 4 # Number of matching items to create a bomb
const POWERUP_BOMB_TYPE = 100 # A constant added to an item type to make it a bomb

const DEBUG_MODE = true # Change to false for release
const MAX_CASCADE_ROUNDS = 10 
const ASYNC_TIMEOUT = 5.0
var _cached_matches = {}
var _grid_hash = ""

# --- Level Management System ---
var current_level_number = 1
var levels_data = {}
var max_available_level = 1
var _level_completion_processed = false
var _game_initialized = false

# --- Level Goal System ---
var level_goals = {} # Dictionary to store goals for each color type (e.g., {0: 15, 1: 10})
var level_progress = {} # Dictionary to track progress for each color type (e.g., {0: 5, 1: 3})
var is_level_complete = false
var score = 0

# --- Drag and Drop Variables ---
# These variables manage the state of dragging and swapping items.
var dragging = false
var drag_start_pos = Vector2()
var drag_offset = Vector2()
var dragged_item: Node2D = null
var target_item: Node2D = null
var start_x = 0
var start_y = 0

# --- Timer Variables ---
var time_limit = 30.0 # Initial time limit for the level
var time_left = 0.0
var is_game_over = false

# --- References to UI Elements ---
# These variables will be assigned references to UI nodes at runtime.
var time_label: Label
var playerMsg_label: Label
var goal_label: Label
@export var bonus_time_per_match: float = 0.5 # Time added for each matched item
var playerMsg_initial_position: Vector2
var level_label: Label


# New dictionary to hold a colored texture for each type
var color_textures: Dictionary = {}

# --- Processing State ---
var is_processing_cascade = false # Prevents input during match cascades
var _processing_bomb_effects = false

# --- Utility Functions for Item Types ---
func _is_powerup_bomb(item_type):
	return item_type >= POWERUP_BOMB_TYPE

func _get_base_type(item_type):
	if _is_powerup_bomb(item_type):
		return item_type - POWERUP_BOMB_TYPE
	return item_type

func debug_print(message):
	if DEBUG_MODE:
		print_rich(message)

# --- Level System Functions ---
func _create_default_levels():
	"""Create default level data if JSON loading fails"""
	levels_data = {
		1: {
			"level_number": 1,
			"grid_size": {"rows": 5, "cols": 5},
			"level_goals": {"0": 8, "1": 6, "2": 4},
			"time_limit_seconds": 45
		}
	}
	max_available_level = 1
	debug_print("Using default level data")

func load_levels_data():
	"""Load all levels data from the JSON file"""
	debug_print("Loading levels data from res://levels.json")
	
	if not FileAccess.file_exists("res://levels.json"):
		debug_print("ERROR: levels.json file not found at res://levels.json")
		debug_print("Creating default level data...")
		_create_default_levels()
		return
	
	var file = FileAccess.open("res://levels.json", FileAccess.READ)
	if file == null:
		debug_print("ERROR: Could not open levels.json file")
		_create_default_levels()
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		debug_print("ERROR: Failed to parse levels.json - " + str(json.error_string))
		_create_default_levels()
		return
	
	var parsed_data = json.data
	
	if not parsed_data.has("levels") or not parsed_data["levels"] is Array:
		debug_print("ERROR: levels.json does not contain a valid 'levels' array")
		_create_default_levels()
		return
	
	# Convert array to dictionary indexed by level number
	for level in parsed_data["levels"]:
		if level.has("level_number"):
			var level_num = int(level["level_number"])  # Ensure it's an integer
			
			# Enhance level data with tile_info and colors if not present
			if not level.has("level_tile_info"):
				level["level_tile_info"] = get_default_tile_info()
				debug_print("Added default tile_info to level " + str(level_num))
			
			if not level.has("colors_array"):
				level["colors_array"] = get_default_colors()
				debug_print("Added default colors_array to level " + str(level_num))
			
			levels_data[level_num] = level
			max_available_level = max(max_available_level, level_num)
			debug_print("Loaded level " + str(level_num))
			
	debug_print("Successfully loaded " + str(levels_data.size()) + " levels. Max level: " + str(max_available_level))


func get_default_tile_info() -> Dictionary:
	"""Get default tile info when color_textures are available"""
	if color_textures.size() > 0:
		debug_print("Using existing color_textures for default tile_info")
		return color_textures.duplicate()
	else:
		debug_print("color_textures not ready, returning empty tile_info")
		return {}
		

func get_default_colors() -> Array:
	"""Get default colors array"""
	# Define default colors that match your game's color scheme
	var default_colors = [
		Color.CYAN,     # Color type 0
		Color.ORANGE,   # Color type 1
		Color.GREEN,    # Color type 2
		Color.MAGENTA,  # Color type 3
		Color.YELLOW,   # Color type 4
		Color.BLUE,     # Color type 5
		Color.RED,      # Color type 6
		Color.PURPLE    # Color type 7
	]
	return default_colors	

#func _setup_level_goals():
	#"""Setup goals for the current level. This can be customized per level."""
	#print("=== SETUP LEVEL GOALS DEBUG ===")
	#print("Setting up level goals...")
	#
	## Clear level-specific dictionaries (NOT color_textures!)
	#level_goals.clear()
	#level_progress.clear()
	#
	## Example goals for different levels - you can modify these or make them configurable
	#var goals_to_set: Dictionary = {
		#0: 15, # Cyan tiles
		#1: 10, # Orange tiles
		#2: 8,  # Green tiles
	#}
	#
	#print_rich("[color=yellow]level goals[/color]: ","[color=15]goal1[/color]")
	#
	## DEBUG: Check color_textures before using it
	#print("color_textures dictionary: ", color_textures)
	#print("color_textures size: ", color_textures.size())
	#for key in color_textures.keys():
		#print("  Key ", key, ": ", color_textures[key], " (size: ", color_textures[key].get_size() if color_textures[key] else "null", ")")
	#
	## Pass the preloaded textures directly
	#var tile_info_to_set = color_textures.duplicate()  # Make a copy to be safe
	#level_goals = goals_to_set.duplicate()
	#
	#for color_type in level_goals.keys():
		#level_progress[color_type] = 0
	#
	#is_level_complete = false
	#print("Level goals set: ", level_goals)
	#print("tile_info_to_set: ", tile_info_to_set)
	#
	## Send goals and tile info to Global singleton.
	#Global.set_goals(level_goals, tile_info_to_set, colors)
	##DEBUG
	#debug_print("[color=red]Here[/color]"+ str(level_goals)+str(tile_info_to_set)+str(colors))
	#print("=== SETUP LEVEL GOALS COMPLETE ===")


func load_level(level_number: int) -> bool:
	"""Load and configure a specific level"""
	debug_print("Loading level " + str(level_number))
	print("=== LOAD LEVEL DEBUG ===")
	
	# Debug info
	debug_print("[color=pink] LN" + str(level_number) + "\n Available levels: " + str(levels_data.keys()) + "---[/color]")
	debug_print("[color=pink]Level exists: " + str(levels_data.has(level_number)) + "[/color]")
	
	# Check if level exists using integer key
	if not levels_data.has(level_number):
		debug_print("[color=white]ERROR: Level " + str(level_number) + " not found in levels data[/color]")
		debug_print("Available levels: " + str(levels_data.keys()))
		return false
	
	var level_data = levels_data[level_number]  # Use integer key, not string!
	current_level_number = level_number
	
	# Validate required fields
	var required_fields = ["grid_size", "level_goals", "time_limit_seconds"]
	for field in required_fields:
		if not level_data.has(field):
			debug_print("ERROR: Level " + str(level_number) + " missing required field: " + field)
			return false
	
	# Apply grid size
	var grid_size = level_data["grid_size"]
	if grid_size.has("rows") and grid_size.has("cols"):
		grid_height = int(grid_size["rows"])
		grid_width = int(grid_size["cols"])
		debug_print("Set grid size to " + str(grid_width) + "x" + str(grid_height))
	
	# Apply time limit
	var time_limit_seconds = float(level_data["time_limit_seconds"])
	time_left = time_limit_seconds
	debug_print("Set time limit to " + str(time_limit_seconds) + " seconds")
	
	# Clear level-specific dictionaries (NOT color_textures!)
	level_goals.clear()
	level_progress.clear()
	
	# Get level colors with fallback to default colors
	var level_colors = []
	if level_data.has("colors_array"):
		level_colors = level_data["colors_array"]
	else:
		level_colors = get_default_colors()
		debug_print("Using default colors for level " + str(level_number))
	
	print_rich("[color=yellow]level colors[/color]: ", level_colors)
		
	# Set the goals in the Global singleton for other nodes to access.
	# The level goals are converted from string keys to integer keys
	var goals_data = level_data["level_goals"]
	var goals_to_pass = {}
	var progress_to_pass = {}
	
	for key in goals_data.keys():
		var color_type = int(key)
		var goal_count = int(goals_data[key])
		goals_to_pass[color_type] = goal_count
		progress_to_pass[color_type] = 0
		level_progress[color_type] = 0  # Initialize local progress tracking
		debug_print("Goal for color " + str(color_type) + ": " + str(goal_count))
	
	# Store goals locally for game logic
	level_goals = goals_to_pass.duplicate()
	print_rich("[color=yellow]level goals[/color]: ", level_goals)
	
	# DEBUG: Check color_textures before using it
	print("color_textures dictionary: ", color_textures)
	print("color_textures size: ", color_textures.size())
	for key in color_textures.keys():
		print("  Key ", key, ": ", color_textures[key], " (size: ", color_textures[key].get_size() if color_textures[key] else "null", ")")
	
	# Get tile_info from level data, but prioritize current color_textures if available
	var tile_info = {}
	if color_textures.size() > 0:
		# Use current color_textures for the most up-to-date textures
		tile_info = color_textures.duplicate()
		debug_print("Using current color_textures for tile_info")
	elif level_data.has("level_tile_info") and not level_data["level_tile_info"].is_empty():
		# Use level data tile info as fallback
		tile_info = level_data["level_tile_info"]
		debug_print("Using level_tile_info from level data")
	else:
		# Last resort: empty dictionary
		tile_info = {}
		debug_print("WARNING: No tile_info available for level " + str(level_number))
	
	print("tile_info_to_set: ", tile_info)
	
	# Send goals, tile info, and colors to Global singleton
	Global.set_goals(goals_to_pass, tile_info, level_colors)
	
	# Reset level state
	is_level_complete = false
	_level_completion_processed = false
	is_game_over = false
	
	#DEBUG
	#debug_print("[color=purple]Here[/color] Goals: " + str(goals_to_pass) + " TileInfo: " + str(tile_info) + " Colors: " + str(level_colors))
	
	_generate_grid() # Make sure you have this line to create the grid
	
	print("=== LOAD LEVEL COMPLETE ===")
	return true
	
func _clear_grid():
	"""Clear the existing grid items"""
	if grid_data.size() > 0:
		for x in range(grid_data.size()):
			if grid_data[x] is Array:
				for y in range(grid_data[x].size()):
					if grid_data[x][y] != null and is_instance_valid(grid_data[x][y]):
						grid_data[x][y].queue_free()
						grid_data[x][y] = null
	grid_data.clear()
	
func _recalculate_grid_position():
	"""Recalculate grid position based on current grid size"""
	var grid_total_width = (grid_width * cell_size) + ((grid_width - 1) * shelf_gap_x)
	var grid_total_height = (grid_height * cell_size) + ((grid_height - 1) * shelf_gap_y)
	
	position = Vector2(-grid_total_width / 2, -grid_total_height / 2)
	
	# Update background panel with error checking
	var background_panel = get_node_or_null("Panel")
	if background_panel != null:
		background_panel.size = Vector2(grid_total_width + padding, grid_total_height + padding)
		background_panel.position = Vector2(-padding / 2, -padding / 2)
	else:
		debug_print("WARNING: Background panel not found")

#func _update_level_display():
	#"""Update the level display in the UI"""
	#if level_label != null:
		#level_label.text = "Level " + str(current_level_number)
#
	#var level_label = ui_container.get_node_or_null("levelLabel")
	#if level_label != null:
		#level_label.text = "Loading..."  # Temporary text until level loads
	
	
func start_level(level_number: int):
	"""Start a specific level from scratch"""
	if not _game_initialized:
		debug_print("Game not fully initialized, deferring level start")
		call_deferred("start_level", level_number)
		return
		
	debug_print("Starting level " + str(level_number))
	
	# Reset state flags
	_level_completion_processed = false
	is_processing_cascade = false
	_processing_bomb_effects = false
	
	# Clear existing grid
	_clear_grid()
	
	# Load level configuration
	if not load_level(level_number):
		debug_print("Failed to load level " + str(level_number) + ", using default")
		if not load_level(1):
			debug_print("CRITICAL: Could not load default level!")
			return
	
	# Recalculate grid positioning
	_recalculate_grid_position()
	
	# Generate new grid
	_generate_grid()
	
	# Update goals in Global singleton (with error checking)
	if Global and Global.has_method("set_goals"):
		Global.set_goals(level_goals, color_textures, colors)
	else:
		debug_print("WARNING: Global singleton not available or missing set_goals method")
	
	# Update UI
	_update_level_display(level_number)
	
	debug_print("Level " + str(current_level_number) + " started successfully")


func advance_to_next_level():
	"""Progress to the next level"""
	var next_level = current_level_number + 1
	
	if next_level > max_available_level:
		debug_print("Congratulations! You've completed all available levels!")
		_show_game_complete_message()
		return
	
	debug_print("Advancing to level " + str(next_level))
	start_level(next_level)

func restart_level():
	"""Restart the level"""
	var next_level = current_level_number 
	
	debug_print("Restarting level " + str(next_level))
	start_level(next_level)


func _show_game_complete_message():
	"""Show message when all levels are completed"""
	if playerMsg_label:
		playerMsg_label.text = "ALL LEVELS COMPLETE!\nAmazing job!"
		playerMsg_label.modulate = Color(1, 1, 0, 1)
		playerMsg_label.scale = Vector2(1.2, 1.2)






@onready var gm_node = get_node_or_null("res://scene/game_manager.tscn") 




# --- Core Functions ---
func _ready():
	debug_print("--- Game Started ---")
	randomize()
	color_textures = {}
	
	# Load levels data first
	load_levels_data()
	
	# Setup UI references
	setup_ui_references()
	
	# Create the textures and wait for completion
	await _create_color_textures_safe()
	
	# Mark as initialized
	_game_initialized = true
	
	# Start with level 1 (deferred to ensure everything is ready)
	call_deferred("start_level", 1)
	#_setup_level_goals() 


	next_level_btn = get_node_or_null("../../../MarginContainer/VBoxContainer/NextLevelButton") #l("../../../UI/VBoxContainer/NextLevelButton")
	restart_level_btn = get_node_or_null("../../../MarginContainer/VBoxContainer/RestartButton")


	if gm_node != null:
		# Correct: Connect to the custom signal on the grid_node
		gm_node.next_level_requested.connect(_on_next_level_button_pressed)
		gm_node.restart_level_requested.connect(_on_restart_level_button_pressed)
		

	if next_level_btn != null:
		# Connect the button's "pressed" signal to a function in this script.
		next_level_btn.pressed.connect(_on_next_level_button_pressed)
		next_level_btn.hide()
		
	if restart_level_btn != null:
		# Connect the button's "pressed" signal to a function in this script.
		restart_level_btn.pressed.connect(_on_restart_level_button_pressed)
		restart_level_btn.hide()

func _on_next_level_button_pressed():
	if next_level_btn != null:
		next_level_btn.hide()
		restart_level_btn.hide()
	advance_to_next_level()
	
func _on_restart_level_button_pressed():
	if next_level_btn != null:
		restart_level_btn.hide()
	restart_level()	


func setup_ui_references():
	"""Setup UI references with error checking"""
	time_label = get_node_or_null("../../../UI/VBoxContainer/Timer")
	playerMsg_label = get_node_or_null("../../../UI/VBoxContainer/playerMsg")
	goal_label = get_node_or_null("../../../UI/VBoxContainer/Goals")
	
	if time_label == null:
		debug_print("WARNING: Timer UI element not found!")
	if playerMsg_label == null:
		debug_print("WARNING: PlayerMsg UI element not found!")
	if goal_label == null:
		debug_print("WARNING: Goals UI element not found!")
	
	# Don't set level text here - wait until level is actually loaded
	var ui_container = get_node_or_null("../../../UI/VBoxContainer")
	if ui_container == null:
		debug_print("WARNING: UI VBoxContainer not found!")
	
	if playerMsg_label != null:
		playerMsg_initial_position = playerMsg_label.position
		
	var level_label = ui_container.get_node_or_null("levelLabel")
	if level_label != null:
		level_label.text = "Loading..."  # Temporary text until level loads

func _update_level_display(level_number: int):
	"""Update the level display with the current level number"""
	var ui_container = get_node_or_null("../../../UI/VBoxContainer")
	if ui_container != null:
		var level_label = ui_container.get_node_or_null("levelLabel")
		if level_label != null:
			level_label.text = "Level " + str(level_number)
			debug_print("Updated level display to: Level " + str(level_number))
		else:
			debug_print("WARNING: Level Label node not found!")
	else:
		debug_print("WARNING: UI VBoxContainer not found for level display update!")




func _create_color_textures_safe():
	"""Create colored textures safely with proper cleanup"""
	debug_print("=== TEXTURE CREATION DEBUG ===")
	
	color_textures = {}
	
	var item_instance = draggable_item_scene.instantiate()
	var sprite = item_instance.get_node("Sprite2D")
	if sprite == null:
		debug_print("ERROR: Could not get Sprite2D from draggable item scene")
		item_instance.queue_free()
		return
		
	var base_texture = sprite.texture
	if base_texture == null:
		debug_print("ERROR: Base texture is null")
		item_instance.queue_free()
		return
	
	debug_print("Base texture size: " + str(base_texture.get_size()))
	debug_print("Colors array: " + str(colors))
	
	for i in range(colors.size()):
		debug_print("Creating texture for color " + str(i) + ": " + str(colors[i]))
		
		var viewport = SubViewport.new()
		viewport.size = base_texture.get_size()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		
		var colored_sprite = Sprite2D.new()
		colored_sprite.texture = base_texture
		colored_sprite.modulate = colors[i]
		viewport.add_child(colored_sprite)
		
		add_child(viewport)
		
		# Wait for rendering
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Capture the texture BEFORE freeing viewport
		var viewport_texture = viewport.get_texture()
		if viewport_texture != null:
			var image = viewport_texture.get_image()
			if image != null:
				var new_texture = ImageTexture.new()
				new_texture.set_image(image)
				color_textures[i] = new_texture
				debug_print("Successfully created texture for color " + str(i))
			else:
				debug_print("ERROR: Could not get image from viewport texture for color " + str(i))
		else:
			debug_print("ERROR: Viewport texture is null for color " + str(i))
		
		# Clean up viewport to prevent memory leak
		viewport.queue_free()
	
	item_instance.queue_free()
	debug_print("Texture creation complete. Created " + str(color_textures.size()) + " textures")




func _process(delta):
	if not _game_initialized:
		return
		
	# Update the game state and UI every frame.
	if time_label != null:
		if not is_game_over and not is_level_complete:
			time_left -= delta
			if time_left <= 0:
				time_left = 0
				game_over()
			time_label.text = "Time: " + str(int(time_left)) +"\nScore: " + str(score)
		elif is_level_complete:
			level_complete()
		else:
			game_over()
	
	_update_goal_display()

func _generate_grid():
	print("Generating grid...")
	grid_data.resize(grid_width)
	for x in range(grid_width):
		grid_data[x] = []
		for y in range(grid_height):
			var item_type = _get_random_item_type(x, y)
			var item_instance = _create_item(item_type, x, y)
			grid_data[x].append(item_instance)
	print("Grid generation complete.")

func _get_random_item_type(x, y):
	# Ensures no immediate matches are created on the initial grid generation.
	var possible_types = range(colors.size())
	if x >= 2:
		var t1 = _get_base_type(grid_data[x-1][y].item_type)
		var t2 = _get_base_type(grid_data[x-2][y].item_type)
		if t1 == t2:
			if possible_types.has(t1):
				possible_types.erase(t1)
	if y >= 2:
		var t1 = _get_base_type(grid_data[x][y-1].item_type)
		var t2 = _get_base_type(grid_data[x][y-2].item_type)
		if t1 == t2:
			if possible_types.has(t1):
				possible_types.erase(t1)
	return possible_types[randi() % possible_types.size()]

func _create_item(item_type, x, y, is_bomb = false):
	# Creates a new item instance and places it on the grid.
	var item_instance = draggable_item_scene.instantiate()

	if is_bomb:
		item_instance.item_type = POWERUP_BOMB_TYPE + item_type
	else:
		item_instance.item_type = item_type

	item_instance.grid_x = x
	item_instance.grid_y = y

	var sprite_instance = item_instance.get_node("Sprite2D")

	var new_material = sprite_instance.material.duplicate()
	sprite_instance.material = new_material

	var item_color = colors[_get_base_type(item_instance.item_type)]
	new_material.set_shader_parameter("base_color", item_color)

	if not _is_powerup_bomb(item_instance.item_type):
		new_material.set_shader_parameter("pulse_strength", 0.0)

	var tex_size = sprite_instance.texture.get_size()
	var scale_factor = cell_size / tex_size.x
	sprite_instance.scale = Vector2(scale_factor, scale_factor)

	var extra_offset_x = 0.0
	var extra_offset_y = 0.0
	if use_shelf_gaps:
		extra_offset_x = (x / 3.0) * shelf_gap_x
		extra_offset_y = (y / 1.0) * shelf_gap_y
	else:
		extra_offset_x = x * shelf_gap_x
		extra_offset_y = y * shelf_gap_y

	item_instance.position = Vector2(
		x * cell_size + cell_size / 2 + extra_offset_x,
		y * cell_size + cell_size / 2 + extra_offset_y
	)
	item_instance.clicked.connect(_on_item_clicked)
	add_child(item_instance)
	return item_instance

func _input(event):
	# Handles user input for dragging and dropping items.
	if is_processing_cascade:
		return
		
	if event is InputEventMouseMotion and dragging:
		if dragged_item:
			dragged_item.position = to_local(event.position) + drag_offset
	elif event is InputEventMouseButton and not event.pressed and dragging:
		end_drag(to_local(event.position))
	elif event is InputEventScreenTouch and not event.pressed and dragging:
		end_drag(to_local(event.position))

func _on_item_clicked(item, click_pos: Vector2):
	if is_processing_cascade:
		return
	start_drag(item, click_pos)

func start_drag(item, pos):
	dragging = true
	dragged_item = item
	drag_start_pos = item.position
	dragged_item.z_index = 1
	drag_offset = item.position - to_local(pos)
	var grid_coords = _get_grid_coords_from_position(dragged_item.position)
	start_x = grid_coords.x
	start_y = grid_coords.y
	print("Starting drag at grid coords: ", start_x, ", ", start_y)

func end_drag(pos):
	dragging = false
	if not dragged_item:
		return

	dragged_item.z_index = 0
	var end_coords = _get_grid_coords_from_position(pos)
	print("Ending drag at grid coords: ", end_coords.x, ", ", end_coords.y)

	if _is_inside_grid(end_coords.x, end_coords.y):
		target_item = grid_data[end_coords.x][end_coords.y]
		if target_item != null and target_item != dragged_item:
			var dx = abs(start_x - end_coords.x)
			var dy = abs(start_y - end_coords.y)
			if (dx == 1 and dy == 0) or (dx == 0 and dy == 1) or (dx == 1 and dy == 1):
				is_processing_cascade = true
				attempt_swap(dragged_item, target_item, start_x, start_y, end_coords.x, end_coords.y)
				await get_tree().create_timer(0.2).timeout

				print("Checking for initial match...")
				var initial_match_found = await check_for_matches()
				print("Initial match found: ", initial_match_found)
				if initial_match_found:
					print("Initial match found, starting cascade.")
					await _handle_cascade()
				else:
					print("No initial match found, swapping back.")
					attempt_swap(dragged_item, target_item, end_coords.x, end_coords.y, start_x, start_y)
				is_processing_cascade = false
			else:
				print("Invalid swap, resetting position.")
				reset_item_position(dragged_item, start_x, start_y)
		else:
			print("Target item is invalid, resetting position.")
			reset_item_position(dragged_item, start_x, start_y)
	else:
		print("Dropped outside grid, resetting position.")
		reset_item_position(dragged_item, start_x, start_y)

	dragged_item = null
	target_item = null

func _get_grid_coords_from_position(pos: Vector2) -> Vector2:
	# Calculates the nearest grid coordinates for a given screen position.
	var closest_pos = Vector2(-1, -1)
	var min_dist_sq = INF

	for x in range(grid_width):
		for y in range(grid_height):
			var cell_center = _get_cell_center(x, y)
			var dist_sq = pos.distance_squared_to(cell_center)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest_pos = Vector2(x, y)

	return closest_pos

func _is_inside_grid(x, y):
	return x >= 0 and x < grid_width and y >= 0 and y < grid_height

func attempt_swap(item1, item2, x1, y1, x2, y2):
	# Swaps two items on the grid and animates their movement.
	print("Attempting to swap items at (", x1, ",", y1, ") and (", x2, ",", y2, ")")
	var pos1 = _get_cell_center(x1, y1)
	var pos2 = _get_cell_center(x2, y2)

	grid_data[x1][y1] = item2
	grid_data[x2][y2] = item1

	item1.grid_x = x2
	item1.grid_y = y2
	item2.grid_x = x1
	item2.grid_y = y1

	create_tween().tween_property(item1, "position", pos2, 0.15)
	create_tween().tween_property(item2, "position", pos1, 0.15)
	print("Swap animation started.")

func reset_item_position(item, grid_x, grid_y):
	print("Resetting item position for item at (", grid_x, ",", grid_y, ")")
	item.position = _get_cell_center(grid_x, grid_y)

func _get_cell_center(x, y):
	# Calculates the center position of a cell on the screen.
	var extra_offset_x = 0.0
	var extra_offset_y = 0.0
	if use_shelf_gaps:
		extra_offset_x = (x / 3.0) * shelf_gap_x
		extra_offset_y = (y / 1.0) * shelf_gap_y
	else:
		extra_offset_x = x * shelf_gap_x
		extra_offset_y = y * shelf_gap_y

	return Vector2(
		x * cell_size + cell_size / 2 + extra_offset_x,
		y * cell_size + cell_size / 2 + extra_offset_y
	)

# -------------------------------
# Level Goal System
# -------------------------------


# New function to create and store colored textures
func _preload_color_textures():
	print("=== TEXTURE CREATION DEBUG ===")
	
	# Make sure color_textures is initialized
	color_textures = {}
	
	var item_instance = draggable_item_scene.instantiate()
	var sprite = item_instance.get_node("Sprite2D")
	var base_texture = sprite.texture
	
	print("Base texture: ", base_texture)
	print("Base texture size: ", base_texture.get_size())
	print("Colors array: ", colors)
	
	for i in range(colors.size()):
		print("Creating texture for color ", i, ": ", colors[i])
		
		var colored_sprite = Sprite2D.new()
		colored_sprite.texture = base_texture
		colored_sprite.modulate = colors[i]
		
		var viewport = SubViewport.new()
		viewport.size = base_texture.get_size()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		
		viewport.add_child(colored_sprite)
		add_child(viewport)
		
		await get_tree().process_frame
		await get_tree().process_frame
		
		var viewport_texture = viewport.get_texture()
		print("Created viewport texture: ", viewport_texture)
		print("Viewport texture size: ", viewport_texture.get_size())
		
		color_textures[i] = viewport_texture
		
		# DON'T free the viewport - keep it alive!
		print("Stored texture at index ", i)
	
	item_instance.queue_free()
	print("Final color_textures: ", color_textures)
	#_setup_level_goals()


func _update_goal_display():
	"""Update the goal display UI - now handled by Global singleton"""
	# Since Global singleton handles the display updates,
	# check for level completion
	_check_level_completion()

func _check_level_completion():
	"""Check if all level goals have been met"""
	if _level_completion_processed:
		return false
		
	# Check using Global singleton if available
	var goals_complete = false
	if Global and Global.has_method("are_goals_complete"):
		goals_complete = Global.are_goals_complete()
	else:
		# Fallback local check
		goals_complete = _check_goals_locally()
	
	if goals_complete and not is_level_complete:
		_level_completion_processed = true
		is_level_complete = true
		return true
	return false

func _check_goals_locally() -> bool:
	"""Fallback method to check goals locally"""
	for color_type in level_goals.keys():
		if not level_progress.has(color_type) or level_progress[color_type] < level_goals[color_type]:
			return false
	return true

func level_complete():
	# Handle level completion
	var time_bonus = int(time_left * 10)
	var completion_text = "LEVEL " + str(current_level_number) + " COMPLETE!\nScore: " + str(score) + "\nTime Bonus: " + str(time_bonus)
	
	if not is_game_over:
		is_game_over = true
		score += time_bonus
		debug_print("Level " + str(current_level_number) + " complete! Final Score: " + str(score))
		
		if time_label != null:
			time_label.text = completion_text
		
		# Show completion message briefly, then advance to next level
		if playerMsg_label != null:
			playerMsg_label.text = "Level Complete!\n Get ready for Level " + str(current_level_number + 1)
			playerMsg_label.modulate = Color(0, 1, 0, 1)
			playerMsg_label.scale = Vector2(1.1, 1.1)
		
		# Wait a bit then show the next level button
		await get_tree().create_timer(2.0).timeout
		
		# Show the next level button
		if next_level_btn != null:
			next_level_btn.show()
			
		if restart_level_btn != null:
			restart_level_btn.show()



		
		

func game_over(completion_text = null):
	#show restart buttom
	if restart_level_btn != null:
			restart_level_btn.show()
	
	var final_score = "Game Over! \nScore: " + str(score)
	if completion_text:
		final_score = completion_text
	if not is_game_over:
		is_game_over = true
		print(final_score)
		if time_label != null:
			time_label.text = final_score
	else:
		time_label.text = final_score



# -------------------------------
# Match Detection and Gameplay Logic
# -------------------------------
func _handle_cascade():
	print("--- Starting Cascade ---")
	var cascade_round = 0
	
	print("Post-match cleanup: Applying gravity and refilling.")
	await apply_gravity()
	await refill_grid()
	
	var matches_found_in_round = true
	while matches_found_in_round:
		cascade_round += 1
		print("Cascade Round ", cascade_round, ": Checking for matches.")
		matches_found_in_round = await check_for_matches()
		if matches_found_in_round:
			print("Cascade Round ", cascade_round, ": Matches found. Applying gravity and refilling.")
			await apply_gravity()
			await refill_grid()
		else:
			print("Cascade Round ", cascade_round, ": No more matches found. Ending cascade.")
			break
	print("--- Cascade Complete ---")

func check_for_matches() -> bool:
	print("Checking for matches...")
	var to_remove = {}
	var new_bombs_to_create = {}

	set_meta("bomb_affected_tiles", [])

	# Check for horizontal matches of 3 or more
	for y in range(grid_height):
		var current_run_length = 1
		for x in range(grid_width):
			if x > 0 and grid_data[x][y] and grid_data[x-1][y] and _get_base_type(grid_data[x][y].item_type) == _get_base_type(grid_data[x-1][y].item_type):
				current_run_length += 1
			else:
				if current_run_length >= 3:
					_process_match(x - 1, y, "horizontal", current_run_length, to_remove, new_bombs_to_create)
				current_run_length = 1
		if current_run_length >= 3:
			_process_match(grid_width - 1, y, "horizontal", current_run_length, to_remove, new_bombs_to_create)

	# Check for vertical matches of 3 or more
	for x in range(grid_width):
		var current_run_length = 1
		for y in range(grid_height):
			if y > 0 and grid_data[x][y] and grid_data[x][y-1] and _get_base_type(grid_data[x][y].item_type) == _get_base_type(grid_data[x][y-1].item_type):
				current_run_length += 1
			else:
				if current_run_length >= 3:
					_process_match(x, y - 1, "vertical", current_run_length, to_remove, new_bombs_to_create)
				current_run_length = 1
		if current_run_length >= 3:
			_process_match(x, grid_height - 1, "vertical", current_run_length, to_remove, new_bombs_to_create)

	print("Matches found:", to_remove.size() > 0 or new_bombs_to_create.size() > 0)
	if to_remove.size() > 0 or new_bombs_to_create.size() > 0:
		var bomb_affected_tiles = get_meta("bomb_affected_tiles")
		var has_bomb_effect = bomb_affected_tiles.size() > 0
		
		if has_bomb_effect:
			var bomb_positions = []
			var regular_positions = []
			
			for pos in to_remove.keys():
				if pos in bomb_affected_tiles:
					bomb_positions.append(pos)
				else:
					regular_positions.append(pos)
			
			if bomb_positions.size() > 0:
				highlight_and_remove(bomb_positions, true)
				await get_tree().create_timer(0.1).timeout
			
			if regular_positions.size() > 0:
				highlight_and_remove(regular_positions, false)
				await get_tree().create_timer(0.1).timeout
		else:
			highlight_and_remove(to_remove.keys(), false)
			await get_tree().create_timer(0.2).timeout

		for pos in new_bombs_to_create:
			var base_type = new_bombs_to_create[pos]
			var new_item = _create_item(base_type, int(pos.x), int(pos.y), true)
			grid_data[int(pos.x)][int(pos.y)] = new_item

		return true

	return false

func _process_match(x: int, y: int, direction: String, length: int, to_remove: Dictionary, new_bombs_to_create: Dictionary):
	# Processes a detected match, handles bomb creation and removal.
	print("Processing a ", length, " ", direction, " match at (", x, ",", y, ")")
	var base_type = _get_base_type(grid_data[x][y].item_type)
	var matched_items = []

	if direction == "horizontal":
		for i in range(length):
			matched_items.append(grid_data[x - i][y])
	else:
		for i in range(length):
			matched_items.append(grid_data[x][y - i])

	var has_bomb_in_match = false
	for item in matched_items:
		if _is_powerup_bomb(item.item_type):
			has_bomb_in_match = true
			_trigger_powerup_effect(Vector2(item.get_grid_x(), item.get_grid_y()), to_remove)

	if has_bomb_in_match:
		for item in matched_items:
			if not to_remove.has(Vector2(item.get_grid_x(), item.get_grid_y())):
				to_remove[Vector2(item.get_grid_x(), item.get_grid_y())] = true

	elif length >= BOMB_MATCH_COUNT:
		var merge_pos = Vector2(-1, -1)
		for item in matched_items:
			if item == dragged_item:
				merge_pos = Vector2(item.get_grid_x(), item.get_grid_y())
				break
		if merge_pos.x == -1:
			merge_pos = Vector2(matched_items[0].get_grid_x(), matched_items[0].get_grid_y())

		new_bombs_to_create[merge_pos] = base_type

		for item in matched_items:
			if not to_remove.has(Vector2(item.get_grid_x(), item.get_grid_y())):
				to_remove[Vector2(item.get_grid_x(), item.get_grid_y())] = true

	else:
		for item in matched_items:
			if not to_remove.has(Vector2(item.get_grid_x(), item.get_grid_y())):
				to_remove[Vector2(item.get_grid_x(), item.get_grid_y())] = true

func _trigger_powerup_effect(pos: Vector2, to_remove: Dictionary):
	# Triggers the bomb effect, adding affected tiles to the removal list.
	print("Triggering powerup effect at (", pos.x, ",", pos.y, ")")
	var x = int(pos.x)
	var y = int(pos.y)
	var bomb_affected_tiles = []
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				if grid_data[new_x][new_y] != null:
					var tile_pos = Vector2(new_x, new_y)
					to_remove[tile_pos] = true
					bomb_affected_tiles.append(tile_pos)
	
	if not has_meta("bomb_affected_tiles"):
		set_meta("bomb_affected_tiles", [])
	var current_bomb_tiles = get_meta("bomb_affected_tiles")
	current_bomb_tiles.append_array(bomb_affected_tiles)
	set_meta("bomb_affected_tiles", current_bomb_tiles)

func highlight_and_remove(matched_positions, is_bomb_effect = false):
	# Animates the removal of matched items and frees them.
	print("Highlighting and removing ", matched_positions.size(), " tiles.")
	
	_track_goal_progress(matched_positions)
	add_score(matched_positions.size())

	if is_bomb_effect:
		var tween = create_tween().set_parallel(true)
		
		for pos in matched_positions:
			var gx = int(pos.x)
			var gy = int(pos.y)
			if _is_inside_grid(gx, gy) and grid_data[gx][gy]:
				var item = grid_data[gx][gy]
				var sprite = item.get_node("Sprite2D")
				
				sprite.modulate = Color(1, 1, 0)
				tween.tween_property(item, "scale", Vector2(1.2, 1.2), 0.1)
				tween.tween_property(item, "scale", Vector2(0, 0), 0.3).set_delay(0.1)

		await tween.finished
	else:
		for pos in matched_positions:
			var gx = int(pos.x)
			var gy = int(pos.y)
			if _is_inside_grid(gx, gy) and grid_data[gx][gy]:
				grid_data[gx][gy].get_node("Sprite2D").modulate = Color(1, 1, 0)

		await get_tree().create_timer(0.2).timeout

	for pos in matched_positions:
		var gx = int(pos.x)
		var gy = int(pos.y)
		if _is_inside_grid(gx, gy) and grid_data[gx][gy]:
			grid_data[gx][gy].queue_free()
			grid_data[gx][gy] = null
	
	_check_level_completion()
	
	print("Finished removing tiles.")

func _track_goal_progress(matched_positions):
	"""Track progress towards level goals when tiles are matched"""
	var color_counts = {}
	
	for pos in matched_positions:
		var gx = int(pos.x)
		var gy = int(pos.y)
		if _is_inside_grid(gx, gy) and grid_data[gx][gy]:
			var item = grid_data[gx][gy]
			var base_color_type = _get_base_type(item.item_type)
			
			if not color_counts.has(base_color_type):
				color_counts[base_color_type] = 0
			color_counts[base_color_type] += 1
	
	# Update progress in both local tracking and Global singleton
	for color_type in color_counts.keys():
		if level_goals.has(color_type):
			level_progress[color_type] += color_counts[color_type]
			# Update Global singleton progress
			Global.update_progress(color_type, color_counts[color_type])
			print("Goal progress for color ", color_type, ": ", level_progress[color_type], "/", level_goals[color_type])
	
	var total_progress = 0
	for count in color_counts.values():
		total_progress += count
	
	if total_progress > 0:
		_show_goal_progress_message(color_counts)

func _show_goal_progress_message(color_counts):
	"""Show a message about goal progress"""
	if playerMsg_label == null:
		return
	
	var color_names = ["Cyan", "Orange", "Green"]
	var progress_text = ""
	
	for color_type in color_counts.keys():
		if level_goals.has(color_type):
			var count = color_counts[color_type]
			var color_name = color_names[color_type] if color_type < color_names.size() else "Color " + str(color_type)
			var phrases = ["Great Job!", "Well done!", "Amazing!", "Wow!"]
			var random_phrase = phrases.pick_random()
			if progress_text != "":
				progress_text += "..."
			progress_text += random_phrase
	
	if progress_text != "":
		playerMsg_label.scale = Vector2(0.8, 0.8)
		playerMsg_label.modulate = Color(0.8, 1, 0.8, 1)
		playerMsg_label.text = progress_text
	


func add_score(matched_count):
	if is_game_over or is_level_complete:
		return

	score += matched_count * 10

	var time_added = matched_count * bonus_time_per_match
	time_left += time_added

	if playerMsg_label != null:
		playerMsg_label.position = playerMsg_initial_position
		playerMsg_label.scale = Vector2(1, 1)
		playerMsg_label.modulate = Color(1, 1, 1, 1)
		playerMsg_label.text = "+" + str(time_added) + "s"
		playerMsg_label.show()

		var tween = create_tween()
		tween.tween_property(playerMsg_label, "modulate", Color(1, 1, 1, 0), 2.0).set_delay(0.25)


func apply_gravity():
	print("Applying gravity...")
	var tween = create_tween().set_parallel(true)
	var tiles_moved = false

	# Process each column from bottom to top
	for x in range(grid_width):
		var write_index = grid_height - 1
		
		# Compact non-null items downward
		for y in range(grid_height - 1, -1, -1):
			if grid_data[x][y] != null:
				if y != write_index:
					var item_to_move = grid_data[x][y]
					grid_data[x][write_index] = item_to_move
					grid_data[x][y] = null
					
					item_to_move.grid_x = x
					item_to_move.grid_y = write_index
					
					var new_pos = _get_cell_center(x, write_index)
					tween.tween_property(item_to_move, "position", new_pos, 0.3)
					tiles_moved = true
				write_index -= 1

	if tiles_moved:
		await tween.finished
	print("Finished applying gravity.")

func refill_grid():
	print("Refilling grid...")
	var items_to_create = []
	
	for x in range(grid_width):
		var empty_count = 0
		for y in range(grid_height):
			if grid_data[x][y] == null:
				empty_count += 1
				items_to_create.append({
					"x": x,
					"y": y,
					"drop_from": y - empty_count
				})
	
	if items_to_create.size() == 0:
		print("No empty cells to refill.")
		return
	
	var tween = create_tween().set_parallel(true)
	
	for item_info in items_to_create:
		var x = item_info.x
		var y = item_info.y
		var drop_from = item_info.drop_from
		
		var item_type = _get_safe_refill_type(x, y)
		var item_instance = _create_item(item_type, x, y)
		grid_data[x][y] = item_instance
		
		var start_pos = _get_cell_center(x, drop_from)
		item_instance.position = start_pos
		
		var end_pos = _get_cell_center(x, y)
		var drop_distance = y - drop_from
		var drop_time = 0.1 + (drop_distance * 0.05)
		
		tween.tween_property(item_instance, "position", end_pos, drop_time)
	
	await tween.finished
	print("Finished refilling grid.")

func _get_safe_refill_type(x: int, y: int) -> int:
	var possible_types = range(colors.size())
	var attempts = 0
	var max_attempts = 10
	
	while attempts < max_attempts:
		var test_type = possible_types[randi() % possible_types.size()]
		
		var horizontal_safe = true
		if x >= 2 and grid_data[x-1][y] != null and grid_data[x-2][y] != null:
			var t1 = _get_base_type(grid_data[x-1][y].item_type)
			var t2 = _get_base_type(grid_data[x-2][y].item_type)
			if t1 == t2 and t1 == test_type:
				horizontal_safe = false
		
		var vertical_safe = true
		if y >= 2 and grid_data[x][y-1] != null and grid_data[x][y-2] != null:
			var t1 = _get_base_type(grid_data[x][y-1].item_type)
			var t2 = _get_base_type(grid_data[x][y-2].item_type)
			if t1 == t2 and t1 == test_type:
				vertical_safe = false
		
		if horizontal_safe and vertical_safe:
			return test_type
		
		attempts += 1
	
	return randi() % colors.size()
