# grid.gd

extends Node2D

class_name GameManage1

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


# --- Enhanced Power-up Constants ---
const BOMB_MATCH_COUNT = 4 # Number of matching items to create a bomb
const POWERUP_BOMB_TYPE = 100      # 3x3 explosion (existing)
const POWERUP_STRIPED_H_TYPE = 200 # Horizontal striped candy
const POWERUP_STRIPED_V_TYPE = 300 # Vertical striped candy
const POWERUP_WRAPPED_TYPE = 400   # Wrapped candy (3x3 + second explosion)
const POWERUP_COLOR_BOMB_TYPE = 500 # Color bomb (removes all of one color)
const POWERUP_STAR_TYPE = 600      # Star candy (diagonal removal)
const POWERUP_FISH_TYPE = 700      # Fish candy (targets random tiles)

# Power-up creation thresholds
const STRIPED_MATCH_COUNT = 4      # 4 in a line creates striped
const WRAPPED_MATCH_COUNT = 5      # L or T shape creates wrapped
const COLOR_BOMB_MATCH_COUNT = 5   # 5 in a line creates color bomb
const STAR_MATCH_COUNT = 6         # 6 in a line creates star
const FISH_MATCH_COUNT = 7         # 7 matches creates fish


# --- Utility Functions for Item Types --- May need to delete
func _is_powerup_bomb(item_type):
	return item_type >= POWERUP_BOMB_TYPE


# --- Enhanced Utility Functions ---
func _is_any_powerup(item_type):
	return item_type >= POWERUP_BOMB_TYPE

func _get_powerup_type(item_type):
	if item_type >= POWERUP_FISH_TYPE:
		return POWERUP_FISH_TYPE
	elif item_type >= POWERUP_STAR_TYPE:
		return POWERUP_STAR_TYPE
	elif item_type >= POWERUP_COLOR_BOMB_TYPE:
		return POWERUP_COLOR_BOMB_TYPE
	elif item_type >= POWERUP_WRAPPED_TYPE:
		return POWERUP_WRAPPED_TYPE
	elif item_type >= POWERUP_STRIPED_V_TYPE:
		return POWERUP_STRIPED_V_TYPE
	elif item_type >= POWERUP_STRIPED_H_TYPE:
		return POWERUP_STRIPED_H_TYPE
	elif item_type >= POWERUP_BOMB_TYPE:
		return POWERUP_BOMB_TYPE
	return 0

func _get_base_type(item_type):
	if _is_any_powerup(item_type):
		var powerup_type = _get_powerup_type(item_type)
		return item_type - powerup_type
	return item_type

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


# FIXED: Remove duplicate grid generation
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
	
	var level_data = levels_data[level_number]
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
	var goals_data = level_data["level_goals"]
	var goals_to_pass = {}
	var progress_to_pass = {}
	
	for key in goals_data.keys():
		var color_type = int(key)
		var goal_count = int(goals_data[key])
		goals_to_pass[color_type] = goal_count
		progress_to_pass[color_type] = 0
		level_progress[color_type] = 0
		debug_print("Goal for color " + str(color_type) + ": " + str(goal_count))
	
	# Store goals locally for game logic
	level_goals = goals_to_pass.duplicate()
	print_rich("[color=yellow]level goals[/color]: ", level_goals)
	
	# Get tile_info from level data, but prioritize current color_textures if available
	var tile_info = {}
	if color_textures.size() > 0:
		tile_info = color_textures.duplicate()
		debug_print("Using current color_textures for tile_info")
	elif level_data.has("level_tile_info") and not level_data["level_tile_info"].is_empty():
		tile_info = level_data["level_tile_info"]
		debug_print("Using level_tile_info from level data")
	else:
		tile_info = {}
		debug_print("WARNING: No tile_info available for level " + str(level_number))
	
	# Send goals, tile info, and colors to Global singleton
	Global.set_goals(goals_to_pass, tile_info, level_colors)
	
	# Reset level state
	is_level_complete = false
	_level_completion_processed = false
	is_game_over = false
	
	# REMOVED: _generate_grid() call - grid generation now handled in start_level()
	
	print("=== LOAD LEVEL COMPLETE ===")
	return true


# IMPROVED: Better grid clearing with validation
func _clear_grid():
	"""Clear the existing grid items with proper validation"""
	debug_print("Clearing existing grid...")
	
	if grid_data.size() > 0:
		for x in range(grid_data.size()):
			if grid_data[x] is Array and grid_data[x].size() > 0:
				for y in range(grid_data[x].size()):
					var item = grid_data[x][y]
					if item != null and is_instance_valid(item):
						item.queue_free()
						grid_data[x][y] = null
	
	# Clear the entire grid data structure
	grid_data.clear()
	
	# Clear cached matches
	_cached_matches.clear()
	_grid_hash = ""
	
	debug_print("Grid cleared successfully")
	
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
		
		
# FIXED: Ensure proper grid clearing and single generation
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
	
	# IMPORTANT: Clear existing grid FIRST before loading new level
	_clear_grid()
	
	# Load level configuration (this sets up goals, colors, etc. but doesn't generate grid)
	if not load_level(level_number):
		debug_print("Failed to load level " + str(level_number) + ", using default")
		if not load_level(1):
			debug_print("CRITICAL: Could not load default level!")
			return
	
	# Recalculate grid positioning based on new grid size
	_recalculate_grid_position()
	
	# Generate new grid ONCE after everything is set up
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
# --- Core Functions ---
func _ready():
	debug_print("--- Game Started ---")
	randomize()
	color_textures = {}
	
	# Load levels data first
	load_levels_data()
	
	#load UI data
	setup_ui_references()
	
	# Create the textures and wait for completion
	await _create_color_textures_safe()
	
	# Mark as initialized
	_game_initialized = true
	
	# Start with level 1 (deferred to ensure everything is ready)
	call_deferred("start_level", 1)

	next_level_btn = get_node_or_null("../../../MarginContainer/VBoxContainer/NextLevelButton")
	restart_level_btn = get_node_or_null("../../../MarginContainer/VBoxContainer/RestartButton")
		
	if next_level_btn != null:
		next_level_btn.pressed.connect(_on_next_level_button_pressed)
		next_level_btn.hide()
		
	if restart_level_btn != null:
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
		
	level_label = ui_container.get_node_or_null("levelLabel")
	if level_label != null:
		level_label.text = "Loading..."

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


# -------------------------------
# Improved Texture Creation
# -------------------------------
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

# --- Safety Functions ---
func _is_grid_ready() -> bool:
	return grid_data.size() == grid_width and (grid_data.size() == 0 or grid_data[0].size() == grid_height)

func _safe_get_grid_item(x: int, y: int):
	if not _is_grid_ready() or not _is_inside_grid(x, y):
		return null
	return grid_data[x][y]

func _safe_set_grid_item(x: int, y: int, item):
	if not _is_grid_ready() or not _is_inside_grid(x, y):
		return false
	grid_data[x][y] = item
	return true

# IMPROVED: Grid generation with better error handling
func _generate_grid():
	"""Generate the game grid with proper initialization"""
	debug_print("Generating grid " + str(grid_width) + "x" + str(grid_height) + "...")
	
	# Ensure grid_data is properly initialized
	grid_data.clear()
	grid_data.resize(grid_width)
	
	for x in range(grid_width):
		grid_data[x] = []
		grid_data[x].resize(grid_height)
		
		for y in range(grid_height):
			# Initialize to null first
			grid_data[x][y] = null
			
			# Create the item
			var item_type = _get_random_item_type(x, y)
			var item_instance = _create_item(item_type, x, y)
			
			if item_instance != null:
				grid_data[x][y] = item_instance
			else:
				debug_print("ERROR: Failed to create item at (" + str(x) + "," + str(y) + ")")
	
	debug_print("Grid generation complete with " + str(grid_width * grid_height) + " cells")

func _get_random_item_type(x, y):
	# Ensures no immediate matches are created on the initial grid generation.
	var possible_types = range(colors.size())
	
	if x >= 2:
		var item1 = _safe_get_grid_item(x-1, y)
		var item2 = _safe_get_grid_item(x-2, y)
		if item1 != null and item2 != null:
			var t1 = _get_base_type(item1.item_type)
			var t2 = _get_base_type(item2.item_type)
			if t1 == t2 and possible_types.has(t1):
				possible_types.erase(t1)
	
	if y >= 2:
		var item1 = _safe_get_grid_item(x, y-1)
		var item2 = _safe_get_grid_item(x, y-2)
		if item1 != null and item2 != null:
			var t1 = _get_base_type(item1.item_type)
			var t2 = _get_base_type(item2.item_type)
			if t1 == t2 and possible_types.has(t1):
				possible_types.erase(t1)
	
	if possible_types.size() == 0:
		possible_types = range(colors.size())
	
	return possible_types[randi() % possible_types.size()]

func _create_item(item_type, x, y, is_bomb = false, powerup_type = 0):
	var item_instance = draggable_item_scene.instantiate()
	
	# Determine the actual item type - FIXED VERSION
	var final_item_type = item_type
	if powerup_type > 0:
		# Use the provided powerup type
		final_item_type = powerup_type + item_type
		debug_print("Creating powerup item: base=" + str(item_type) + " powerup=" + str(powerup_type) + " final=" + str(final_item_type))
	elif is_bomb:
		# Fallback for old bomb creation method
		final_item_type = POWERUP_BOMB_TYPE + item_type
		debug_print("Creating bomb item (legacy): final=" + str(final_item_type))

	item_instance.item_type = final_item_type
	item_instance.grid_x = x
	item_instance.grid_y = y

	var sprite_instance = item_instance.get_node("Sprite2D")
	if sprite_instance == null:
		debug_print("ERROR: Sprite2D not found in draggable item!")
		return null

	# Create new material instance - IMPORTANT for shader effects
	var new_material = null
	if sprite_instance.material != null:
		new_material = sprite_instance.material.duplicate()
	else:
		# Create a new ShaderMaterial if none exists
		new_material = ShaderMaterial.new()
		# You'll need to load your shader here
		var powerup_shader = load("res://shaders/powerup_item.gdshader")
		new_material.shader = powerup_shader
	
	sprite_instance.material = new_material

	var base_type = _get_base_type(final_item_type)
	if base_type < colors.size():
		var item_color = colors[base_type]
		
		# Apply power-up specific visual effects
		_apply_powerup_visual_effects(new_material, final_item_type, item_color)
	else:
		debug_print("WARNING: Invalid color type: " + str(base_type))
		# Set a default color
		new_material.set_shader_parameter("base_color", Color.WHITE)

	var tex_size = sprite_instance.texture.get_size()
	var scale_factor = cell_size / tex_size.x
	sprite_instance.scale = Vector2(scale_factor, scale_factor)

	# Position calculation
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
	
	if item_instance.has_signal("clicked"):
		item_instance.clicked.connect(_on_item_clicked)
	
	add_child(item_instance)
	return item_instance


func _apply_powerup_visual_effects(material, item_type, base_color):
	"""Apply visual effects based on power-up type"""
	var powerup_type = _get_powerup_type(item_type)
	
	# Reset all shader parameters first
	_reset_shader_parameters(material)
	
	# Set base color
	material.set_shader_parameter("base_color", base_color)
	
	match powerup_type:
		POWERUP_BOMB_TYPE:
			# Pulsing orange/red effect for bomb
			material.set_shader_parameter("is_bomb", true)
			material.set_shader_parameter("pulse_strength", 0.4)
			material.set_shader_parameter("pulse_speed", 2.5)
			debug_print("Applied bomb visual effects")
		
		POWERUP_STRIPED_H_TYPE:
			# Horizontal stripes effect
			material.set_shader_parameter("stripe_horizontal", true)
			material.set_shader_parameter("stripe_color", Color.WHITE)
			material.set_shader_parameter("stripe_width", 0.15)
			material.set_shader_parameter("stripe_speed", 1.8)
			debug_print("Applied horizontal striped visual effects")
		
		POWERUP_STRIPED_V_TYPE:
			# Vertical stripes effect
			material.set_shader_parameter("stripe_vertical", true)
			material.set_shader_parameter("stripe_color", Color.WHITE)
			material.set_shader_parameter("stripe_width", 0.15)
			material.set_shader_parameter("stripe_speed", 1.8)
			debug_print("Applied vertical striped visual effects")
		
		POWERUP_WRAPPED_TYPE:
			# Wrapped candy effect (border glow)
			material.set_shader_parameter("is_wrapped", true)
			material.set_shader_parameter("glow_strength", 0.6)
			material.set_shader_parameter("glow_color", base_color.lightened(0.4))
			material.set_shader_parameter("pulse_strength", 0.2)
			material.set_shader_parameter("pulse_speed", 1.2)
			debug_print("Applied wrapped visual effects")
		
		POWERUP_COLOR_BOMB_TYPE:
			# Rainbow/multicolor effect
			material.set_shader_parameter("rainbow_effect", true)
			material.set_shader_parameter("rainbow_speed", 1.5)
			material.set_shader_parameter("pulse_strength", 0.3)
			material.set_shader_parameter("pulse_speed", 1.8)
			debug_print("Applied color bomb visual effects")
		
		POWERUP_STAR_TYPE:
			# Star effect with sparkles
			material.set_shader_parameter("star_effect", true)
			material.set_shader_parameter("sparkle_intensity", 0.7)
			material.set_shader_parameter("sparkle_frequency", 6.0)
			material.set_shader_parameter("base_color", Color.YELLOW)
			debug_print("Applied star visual effects")
		
		POWERUP_FISH_TYPE:
			# Fish effect with swimming animation
			material.set_shader_parameter("fish_effect", true)
			material.set_shader_parameter("wave_strength", 0.4)
			material.set_shader_parameter("wave_frequency", 3.0)
			material.set_shader_parameter("base_color", Color.CYAN)
			debug_print("Applied fish visual effects")

func _reset_shader_parameters(material):
	"""Reset all shader parameters to default values"""
	# Reset all boolean flags
	material.set_shader_parameter("is_bomb", false)
	material.set_shader_parameter("stripe_horizontal", false)
	material.set_shader_parameter("stripe_vertical", false)
	material.set_shader_parameter("is_wrapped", false)
	material.set_shader_parameter("rainbow_effect", false)
	material.set_shader_parameter("star_effect", false)
	material.set_shader_parameter("fish_effect", false)
	
	# Reset numeric parameters to defaults
	material.set_shader_parameter("pulse_strength", 0.0)
	material.set_shader_parameter("pulse_speed", 2.0)
	material.set_shader_parameter("stripe_width", 0.2)
	material.set_shader_parameter("stripe_speed", 1.5)
	material.set_shader_parameter("glow_strength", 0.0)
	material.set_shader_parameter("sparkle_intensity", 0.0)
	material.set_shader_parameter("wave_strength", 0.0)


func _input(event):
	# Handles user input for dragging and dropping items.
	if is_processing_cascade or not _game_initialized:
		return
		
	if event is InputEventMouseMotion and dragging:
		if dragged_item and is_instance_valid(dragged_item):
			dragged_item.position = to_local(event.position) + drag_offset
	elif event is InputEventMouseButton and not event.pressed and dragging:
		end_drag(to_local(event.position))
	elif event is InputEventScreenTouch and not event.pressed and dragging:
		end_drag(to_local(event.position))

func _on_item_clicked(item, click_pos: Vector2):
	if is_processing_cascade or not _game_initialized:
		return
	start_drag(item, click_pos)

func start_drag(item, pos):
	if item == null or not is_instance_valid(item):
		return
		
	dragging = true
	dragged_item = item
	drag_start_pos = item.position
	dragged_item.z_index = 1
	drag_offset = item.position - to_local(pos)
	var grid_coords = _get_grid_coords_from_position(dragged_item.position)
	start_x = grid_coords.x
	start_y = grid_coords.y
	debug_print("Starting drag at grid coords: " + str(start_x) + ", " + str(start_y))

func end_drag(pos):
	dragging = false
	if not dragged_item or not is_instance_valid(dragged_item):
		dragged_item = null
		return

	dragged_item.z_index = 0
	var end_coords = _get_grid_coords_from_position(pos)
	debug_print("Ending drag at grid coords: " + str(end_coords.x) + ", " + str(end_coords.y))

	if _is_inside_grid(end_coords.x, end_coords.y):
		target_item = _safe_get_grid_item(end_coords.x, end_coords.y)
		if target_item != null and target_item != dragged_item and is_instance_valid(target_item):
			var dx = abs(start_x - end_coords.x)
			var dy = abs(start_y - end_coords.y)
			if (dx == 1 and dy == 0) or (dx == 0 and dy == 1) or (dx == 1 and dy == 1):
				is_processing_cascade = true
				await _handle_swap_attempt(dragged_item, target_item, start_x, start_y, end_coords.x, end_coords.y)
				is_processing_cascade = false
			else:
				debug_print("Invalid swap, resetting position.")
				reset_item_position(dragged_item, start_x, start_y)
		else:
			debug_print("Target item is invalid, resetting position.")
			reset_item_position(dragged_item, start_x, start_y)
	else:
		debug_print("Dropped outside grid, resetting position.")
		reset_item_position(dragged_item, start_x, start_y)

	dragged_item = null
	target_item = null

func _handle_swap_attempt(item1, item2, x1, y1, x2, y2):
	"""Handle the swap attempt with proper error checking and timeouts"""
	attempt_swap(item1, item2, x1, y1, x2, y2)
	await get_tree().create_timer(0.2).timeout

	debug_print("Checking for initial match...")
	
	# Add timeout to prevent hanging
	var timeout_timer = get_tree().create_timer(ASYNC_TIMEOUT)
	var initial_match_found = await check_for_matches()
	
	if timeout_timer.time_left <= 0:
		debug_print("WARNING: Match check timed out!")
		attempt_swap(item1, item2, x2, y2, x1, y1) # Swap back
		return
	
	debug_print("Initial match found: " + str(initial_match_found))
	if initial_match_found:
		debug_print("Initial match found, starting cascade.")
		await _handle_cascade()
	else:
		debug_print("No initial match found, swapping back.")
		attempt_swap(item1, item2, x2, y2, x1, y1)


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

#func attempt_swap(item1, item2, x1, y1, x2, y2):
	## Swaps two items on the grid and animates their movement.
	#print("Attempting to swap items at (", x1, ",", y1, ") and (", x2, ",", y2, ")")
	#var pos1 = _get_cell_center(x1, y1)
	#var pos2 = _get_cell_center(x2, y2)
#
	#grid_data[x1][y1] = item2
	#grid_data[x2][y2] = item1
#
	#item1.grid_x = x2
	#item1.grid_y = y2
	#item2.grid_x = x1
	#item2.grid_y = y1
#
	#create_tween().tween_property(item1, "position", pos2, 0.15)
	#create_tween().tween_property(item2, "position", pos1, 0.15)
	#print("Swap animation started.")

func attempt_swap(item1, item2, x1, y1, x2, y2):
	# Swaps two items on the grid and animates their movement.
	if not item1 or not item2 or not is_instance_valid(item1) or not is_instance_valid(item2):
		debug_print("ERROR: Invalid items for swap")
		return
		
	debug_print("Attempting to swap items at (" + str(x1) + "," + str(y1) + ") and (" + str(x2) + "," + str(y2) + ")")
	var pos1 = _get_cell_center(x1, y1)
	var pos2 = _get_cell_center(x2, y2)

	_safe_set_grid_item(x1, y1, item2)
	_safe_set_grid_item(x2, y2, item1)

	if item1.has_method("set_grid_position"):
		item1.set_grid_position(x2, y2)
	else:
		item1.grid_x = x2
		item1.grid_y = y2
		
	if item2.has_method("set_grid_position"):
		item2.set_grid_position(x1, y1)
	else:
		item2.grid_x = x1
		item2.grid_y = y1

	# Clear cached matches when grid changes
	_cached_matches.clear()
	_grid_hash = ""

	create_tween().tween_property(item1, "position", pos2, 0.15)
	create_tween().tween_property(item2, "position", pos1, 0.15)
	debug_print("Swap animation started.")


func reset_item_position(item, grid_x, grid_y):
	if not item or not is_instance_valid(item):
		return
	debug_print("Resetting item position for item at (" + str(grid_x) + "," + str(grid_y) + ")")
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

func _calculate_grid_hash() -> String:
	"""Calculate a hash of the current grid state for caching"""
	var hash_data = ""
	for x in range(grid_width):
		for y in range(grid_height):
			var item = _safe_get_grid_item(x, y)
			if item != null:
				hash_data += str(item.item_type) + ","
			else:
				hash_data += "null,"
	return hash_data

func _handle_cascade():
	debug_print("--- Starting Cascade ---")
	var cascade_round = 0
	
	debug_print("Post-match cleanup: Applying gravity and refilling.")
	await apply_gravity()
	await refill_grid()
	
	var matches_found_in_round = true
	while matches_found_in_round and cascade_round < MAX_CASCADE_ROUNDS:
		cascade_round += 1
		debug_print("Cascade Round " + str(cascade_round) + ": Checking for matches.")
		
		# Add timeout protection
		var timeout_timer = get_tree().create_timer(ASYNC_TIMEOUT)
		matches_found_in_round = await check_for_matches()
		
		if timeout_timer.time_left <= 0:
			debug_print("WARNING: Cascade timed out at round " + str(cascade_round))
			break
		
		if matches_found_in_round:
			debug_print("Cascade Round " + str(cascade_round) + ": Matches found. Applying gravity and refilling.")
			await apply_gravity()
			await refill_grid()
		else:
			debug_print("Cascade Round " + str(cascade_round) + ": No more matches found. Ending cascade.")
			break
	
	if cascade_round >= MAX_CASCADE_ROUNDS:
		debug_print("WARNING: Maximum cascade rounds reached!")
	
	debug_print("--- Cascade Complete ---")


func check_for_matches() -> bool:
	debug_print("Checking for matches...")
	
	# Use caching for performance
	var current_hash = _calculate_grid_hash()
	if current_hash == _grid_hash and _cached_matches.has(current_hash):
		debug_print("Using cached match result")
		return _cached_matches[current_hash]
	
	var result = await _perform_match_check()
	
	# Cache the result
	_grid_hash = current_hash
	_cached_matches[current_hash] = result
	
	return result

func _perform_match_check() -> bool:
	"""Perform the actual match checking logic"""
	var to_remove = {}
	var new_bombs_to_create = {}

	set_meta("bomb_affected_tiles", [])

	# Check for horizontal matches of 3 or more
	for y in range(grid_height):
		var current_run_length = 1
		for x in range(grid_width):
			var current_item = _safe_get_grid_item(x, y)
			var prev_item = _safe_get_grid_item(x-1, y) if x > 0 else null
			
			if x > 0 and current_item != null and prev_item != null and _get_base_type(current_item.item_type) == _get_base_type(prev_item.item_type):
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
			var current_item = _safe_get_grid_item(x, y)
			var prev_item = _safe_get_grid_item(x, y-1) if y > 0 else null
			
			if y > 0 and current_item != null and prev_item != null and _get_base_type(current_item.item_type) == _get_base_type(prev_item.item_type):
				current_run_length += 1
			else:
				if current_run_length >= 3:
					_process_match(x, y - 1, "vertical", current_run_length, to_remove, new_bombs_to_create)
				current_run_length = 1
		if current_run_length >= 3:
			_process_match(x, grid_height - 1, "vertical", current_run_length, to_remove, new_bombs_to_create)

	debug_print("Matches found: " + str(to_remove.size() > 0 or new_bombs_to_create.size() > 0))
	if to_remove.size() > 0 or new_bombs_to_create.size() > 0:
		var bomb_affected_tiles = get_meta("bomb_affected_tiles", [])
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

		# Create new bombs - FIXED VERSION
		for pos in new_bombs_to_create:
			var bomb_data = new_bombs_to_create[pos]
			
			# Handle both old format (just base_type) and new format (dictionary)
			var base_type = 0
			var powerup_type = 0
			
			if bomb_data is Dictionary:
				# New format with power-up data
				base_type = bomb_data.get("type", 0)
				powerup_type = bomb_data.get("powerup", POWERUP_BOMB_TYPE)
			else:
				# Old format - just the base type, default to bomb
				base_type = bomb_data
				powerup_type = POWERUP_BOMB_TYPE
			
			# Create the item with proper parameters
			var new_item = _create_item(base_type, int(pos.x), int(pos.y), false, powerup_type)
			if new_item != null:
				_safe_set_grid_item(int(pos.x), int(pos.y), new_item)

		return true

	return false
	
func _process_match(x: int, y: int, direction: String, length: int, to_remove: Dictionary, new_bombs_to_create: Dictionary):
	var grid_item = _safe_get_grid_item(x, y)
	if grid_item == null:
		debug_print("ERROR: No item at match position (" + str(x) + "," + str(y) + ")")
		return
		
	debug_print("Processing a " + str(length) + " " + direction + " match at (" + str(x) + "," + str(y) + ")")
	var base_type = _get_base_type(grid_item.item_type)
	var matched_items = []

	# Collect matched items
	if direction == "horizontal":
		for i in range(length):
			var item = _safe_get_grid_item(x - i, y)
			if item != null:
				matched_items.append(item)
	else:
		for i in range(length):
			var item = _safe_get_grid_item(x, y - i)
			if item != null:
				matched_items.append(item)

	# Check for existing power-ups in match
	var has_powerup_in_match = false
	for item in matched_items:
		if item != null and _is_any_powerup(item.item_type):
			has_powerup_in_match = true
			_trigger_powerup_effect(Vector2(item.grid_x, item.grid_y), to_remove)

	# Determine merge position (prefer dragged item position)
	var merge_pos = Vector2(-1, -1)
	for item in matched_items:
		if item != null and item == dragged_item:
			merge_pos = Vector2(item.grid_x, item.grid_y)
			break
	if merge_pos.x == -1 and matched_items.size() > 0 and matched_items[0] != null:
		merge_pos = Vector2(matched_items[0].grid_x, matched_items[0].grid_y)

	# Create appropriate power-up based on match length and pattern - FIXED VERSION
	if merge_pos.x != -1 and not has_powerup_in_match:
		var powerup_to_create = _determine_powerup_type(length, direction, x, y)
		if powerup_to_create > 0:
			# Store as dictionary with type and powerup info
			new_bombs_to_create[merge_pos] = {"type": base_type, "powerup": powerup_to_create}
			debug_print("Will create [color=yellow]powerup type " + str(powerup_to_create) + "[/color] at " + str(merge_pos))
		elif length >= BOMB_MATCH_COUNT:
			# Default bomb creation for 4+ matches without special pattern
			new_bombs_to_create[merge_pos] = {"type": base_type, "powerup": POWERUP_BOMB_TYPE}
			debug_print("Will create bomb at " + str(merge_pos))

	# Mark all matched items for removal
	for item in matched_items:
		if item != null:
			var item_pos = Vector2(item.grid_x, item.grid_y)
			if not to_remove.has(item_pos):
				to_remove[item_pos] = true

func _determine_powerup_type(length: int, direction: String, x: int, y: int) -> int:
	"""Determine what type of power-up to create based on match characteristics"""
	
	# Check for L or T shapes for wrapped candy
	if _check_for_l_or_t_shape(x, y):
		return POWERUP_WRAPPED_TYPE
	
	# Length-based power-ups
	match length:
		7, 8, 9, 10: # Very long matches create fish
			return POWERUP_FISH_TYPE
		6: # 6 in a line creates star
			return POWERUP_STAR_TYPE
		5: # 5 in a line creates color bomb
			return POWERUP_COLOR_BOMB_TYPE
		4: # 4 in a line creates striped candy
			if direction == "horizontal":
				return POWERUP_STRIPED_V_TYPE  # Horizontal match creates vertical striped
			else:
				return POWERUP_STRIPED_H_TYPE  # Vertical match creates horizontal striped
		_:
			return 0  # No power-up for matches less than 4
			
			
func _check_for_l_or_t_shape(x: int, y: int) -> bool:
	"""Check if there's an L or T shaped match at the given position"""
	var base_item = _safe_get_grid_item(x, y)
	if base_item == null:
		return false
	
	var base_type = _get_base_type(base_item.item_type)
	
	# Check for T shape (horizontal + vertical intersection)
	var horizontal_count = 1
	var vertical_count = 1
	
	# Count horizontal matches
	var left_count = 0
	var right_count = 0
	for i in range(1, grid_width):
		var left_item = _safe_get_grid_item(x - i, y)
		if left_item != null and _get_base_type(left_item.item_type) == base_type:
			left_count += 1
		else:
			break
	
	for i in range(1, grid_width):
		var right_item = _safe_get_grid_item(x + i, y)
		if right_item != null and _get_base_type(right_item.item_type) == base_type:
			right_count += 1
		else:
			break
	
	horizontal_count = left_count + right_count + 1
	
	# Count vertical matches
	var up_count = 0
	var down_count = 0
	for i in range(1, grid_height):
		var up_item = _safe_get_grid_item(x, y - i)
		if up_item != null and _get_base_type(up_item.item_type) == base_type:
			up_count += 1
		else:
			break
	
	for i in range(1, grid_height):
		var down_item = _safe_get_grid_item(x, y + i)
		if down_item != null and _get_base_type(down_item.item_type) == base_type:
			down_count += 1
		else:
			break
	
	vertical_count = up_count + down_count + 1
	
	# Return true if both horizontal and vertical counts are >= 3
	return horizontal_count >= 3 and vertical_count >= 3


			

#func _trigger_powerup_effect(pos: Vector2, to_remove: Dictionary):
	## Triggers the bomb effect, adding affected tiles to the removal list.
	#if _processing_bomb_effects:
		#debug_print("WARNING: Recursive bomb effect prevented")
		#return
		#
	#_processing_bomb_effects = true
	#
	#debug_print("Triggering powerup effect at (" + str(pos.x) + "," + str(pos.y) + ")")
	#var x = int(pos.x)
	#var y = int(pos.y)
	#var bomb_affected_tiles = []
	#
	#for dx in range(-1, 2):
		#for dy in range(-1, 2):
			#var new_x = x + dx
			#var new_y = y + dy
			#if _is_inside_grid(new_x, new_y):
				#var item = _safe_get_grid_item(new_x, new_y)
				#if item != null:
					#var tile_pos = Vector2(new_x, new_y)
					#to_remove[tile_pos] = true
					#bomb_affected_tiles.append(tile_pos)
	#
	#var current_bomb_tiles = get_meta("bomb_affected_tiles", [])
	#current_bomb_tiles.append_array(bomb_affected_tiles)
	#set_meta("bomb_affected_tiles", current_bomb_tiles)
	#
	#_processing_bomb_effects = false

# --- Enhanced Power-up Effect System ---
func _trigger_powerup_effect(pos: Vector2, to_remove: Dictionary):
	if _processing_bomb_effects:
		debug_print("WARNING: Recursive bomb effect prevented")
		return
		
	_processing_bomb_effects = true
	
	var x = int(pos.x)
	var y = int(pos.y)
	var item = _safe_get_grid_item(x, y)
	
	if item == null:
		_processing_bomb_effects = false
		return
	
	var powerup_type = _get_powerup_type(item.item_type)
	debug_print("Triggering powerup effect: " + str(powerup_type) + " at (" + str(x) + "," + str(y) + ")")
	
	match powerup_type:
		POWERUP_BOMB_TYPE:
			_trigger_bomb_effect(x, y, to_remove)
		POWERUP_STRIPED_H_TYPE:
			_trigger_striped_horizontal_effect(x, y, to_remove)
		POWERUP_STRIPED_V_TYPE:
			_trigger_striped_vertical_effect(x, y, to_remove)
		POWERUP_WRAPPED_TYPE:
			_trigger_wrapped_effect(x, y, to_remove)
		POWERUP_COLOR_BOMB_TYPE:
			_trigger_color_bomb_effect(x, y, to_remove)
		POWERUP_STAR_TYPE:
			_trigger_star_effect(x, y, to_remove)
		POWERUP_FISH_TYPE:
			_trigger_fish_effect(x, y, to_remove)
	
	_processing_bomb_effects = false

func _trigger_bomb_effect(x: int, y: int, to_remove: Dictionary):
	"""3x3 explosion effect"""
	debug_print("Triggering bomb effect at (" + str(x) + "," + str(y) + ")")
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				var tile_pos = Vector2(new_x, new_y)
				to_remove[tile_pos] = true
				
func _trigger_striped_horizontal_effect(x: int, y: int, to_remove: Dictionary):
	"""Clear entire row"""
	debug_print("Triggering horizontal striped effect at row " + str(y))
	
	for i in range(grid_width):
		if _is_inside_grid(i, y):
			var tile_pos = Vector2(i, y)
			to_remove[tile_pos] = true

func _trigger_striped_vertical_effect(x: int, y: int, to_remove: Dictionary):
	"""Clear entire column"""
	debug_print("Triggering vertical striped effect at column " + str(x))
	
	for i in range(grid_height):
		if _is_inside_grid(x, i):
			var tile_pos = Vector2(x, i)
			to_remove[tile_pos] = true

func _trigger_wrapped_effect(x: int, y: int, to_remove: Dictionary):
	"""3x3 explosion, then second 5x5 explosion after delay"""
	debug_print("Triggering wrapped effect at (" + str(x) + "," + str(y) + ")")
	
	# First explosion (3x3)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				var tile_pos = Vector2(new_x, new_y)
				to_remove[tile_pos] = true
	
	# Schedule second explosion (5x5) - this would need to be handled in the cascade system
	call_deferred("_trigger_wrapped_second_explosion", x, y)

func _trigger_wrapped_second_explosion(x: int, y: int):
	"""Second explosion for wrapped candy (5x5)"""
	await get_tree().create_timer(0.3).timeout
	
	var second_to_remove = {}
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				var tile_pos = Vector2(new_x, new_y)
				second_to_remove[tile_pos] = true
	
	if second_to_remove.size() > 0:
		highlight_and_remove(second_to_remove.keys(), true)

func _trigger_color_bomb_effect(x: int, y: int, to_remove: Dictionary):
	"""Remove all tiles of the most common color on the board"""
	debug_print("Triggering color bomb effect")
	
	# Count colors on the board
	var color_counts = {}
	for grid_x in range(grid_width):
		for grid_y in range(grid_height):
			var item = _safe_get_grid_item(grid_x, grid_y)
			if item != null:
				var base_type = _get_base_type(item.item_type)
				if not color_counts.has(base_type):
					color_counts[base_type] = 0
				color_counts[base_type] += 1
	
	# Find most common color
	var target_color = -1
	var max_count = 0
	for color_type in color_counts.keys():
		if color_counts[color_type] > max_count:
			max_count = color_counts[color_type]
			target_color = color_type
	
	# Remove all tiles of that color
	if target_color >= 0:
		for grid_x in range(grid_width):
			for grid_y in range(grid_height):
				var item = _safe_get_grid_item(grid_x, grid_y)
				if item != null and _get_base_type(item.item_type) == target_color:
					var tile_pos = Vector2(grid_x, grid_y)
					to_remove[tile_pos] = true

func _trigger_star_effect(x: int, y: int, to_remove: Dictionary):
	"""Remove tiles in diagonal directions"""
	debug_print("Triggering star effect at (" + str(x) + "," + str(y) + ")")
	
	# Remove in all 4 diagonal directions
	var directions = [
		Vector2(1, 1),   # Down-right
		Vector2(1, -1),  # Up-right
		Vector2(-1, 1),  # Down-left
		Vector2(-1, -1)  # Up-left
	]
	
	for direction in directions:
		var current_x = x
		var current_y = y
		
		# Extend in this diagonal direction until edge of grid
		while _is_inside_grid(current_x, current_y):
			var tile_pos = Vector2(current_x, current_y)
			to_remove[tile_pos] = true
			current_x += direction.x
			current_y += direction.y

func _trigger_fish_effect(x: int, y: int, to_remove: Dictionary):
	"""Fish targets 3-5 random tiles on the board"""
	debug_print("Triggering fish effect")
	
	var available_positions = []
	for grid_x in range(grid_width):
		for grid_y in range(grid_height):
			var item = _safe_get_grid_item(grid_x, grid_y)
			if item != null:
				available_positions.append(Vector2(grid_x, grid_y))
	
	# Target 3-5 random positions
	var target_count = min(randi_range(3, 5), available_positions.size())
	available_positions.shuffle()
	
	for i in range(target_count):
		if i < available_positions.size():
			var pos = available_positions[i]
			to_remove[pos] = true


func highlight_and_remove(matched_positions, is_bomb_effect = false):
	debug_print("Highlighting and removing " + str(matched_positions.size()) + " tiles.")
	
	# Create a new tween for all removal effects
	var removal_tween = create_tween().set_parallel(true)
	var final_remove_items = []
	
	# Apply shader effects for removal
	for pos in matched_positions:
		var gx = int(pos.x)
		var gy = int(pos.y)
		var item = _safe_get_grid_item(gx, gy)
		if item != null and is_instance_valid(item):
			var sprite = item.get_node_or_null("Sprite2D")
			if sprite != null and sprite.material != null:
				# Use a shader parameter to control the removal effect
				# Animate the 'removal_progress' uniform from 0.0 to 1.0
				removal_tween.tween_property(sprite.material, "shader_parameter/removal_progress", 1.0, 0.3)
				final_remove_items.append(item)
				# NEW: Set the shatter_size from the GDScript
				sprite.material.set_shader_parameter("shatter_size", 8)
				final_remove_items.append(item)
			else:
				# Fallback for items without a shader
				item.queue_free()
				_safe_set_grid_item(gx, gy, null)
	
	# Await the completion of the visual effects
	await removal_tween.finished
	
	# Remove items after the effects have finished
	for item in final_remove_items:
		if is_instance_valid(item):
			var pos = Vector2(item.grid_x, item.grid_y)
			_track_goal_progress([pos])
			add_score(1)
			item.queue_free()
			_safe_set_grid_item(item.grid_x, item.grid_y, null)
	
	_cached_matches.clear()
	_grid_hash = ""
	_check_level_completion()
	
	debug_print("Finished removing tiles.")



func _track_goal_progress(matched_positions):
	"""Track progress towards level goals when tiles are matched"""
	var color_counts = {}
	
	for pos in matched_positions:
		var gx = int(pos.x)
		var gy = int(pos.y)
		var item = _safe_get_grid_item(gx, gy)
		if item != null and is_instance_valid(item):
			var base_color_type = _get_base_type(item.item_type)
			
			if not color_counts.has(base_color_type):
				color_counts[base_color_type] = 0
			color_counts[base_color_type] += 1
	
	# Update progress in both local tracking and Global singleton
	for color_type in color_counts.keys():
		if level_goals.has(color_type):
			level_progress[color_type] += color_counts[color_type]
			# Update Global singleton progress
			if Global and Global.has_method("update_progress"):
				Global.update_progress(color_type, color_counts[color_type])
			debug_print("Goal progress for color " + str(color_type) + ": " + str(level_progress[color_type]) + "/" + str(level_goals[color_type]))
	
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
	#print("Applying gravity...")
	#var tween = create_tween().set_parallel(true)
	#var tiles_moved = false
#
	## Process each column from bottom to top
	#for x in range(grid_width):
		#var write_index = grid_height - 1
		#
		## Compact non-null items downward
		#for y in range(grid_height - 1, -1, -1):
			#if grid_data[x][y] != null:
				#if y != write_index:
					#var item_to_move = grid_data[x][y]
					#grid_data[x][write_index] = item_to_move
					#grid_data[x][y] = null
					#
					#item_to_move.grid_x = x
					#item_to_move.grid_y = write_index
					#
					#var new_pos = _get_cell_center(x, write_index)
					#tween.tween_property(item_to_move, "position", new_pos, 0.3)
					#tiles_moved = true
				#write_index -= 1
#
	#if tiles_moved:
		#await tween.finished
	#print("Finished applying gravity.")

func apply_gravity():
	debug_print("Applying gravity...")
	var tween = create_tween().set_parallel(true)
	var tiles_moved = false

	# Process each column from bottom to top
	for x in range(grid_width):
		var write_index = grid_height - 1
		
		# Compact non-null items downward
		for y in range(grid_height - 1, -1, -1):
			var item = _safe_get_grid_item(x, y)
			if item != null and is_instance_valid(item):
				if y != write_index:
					_safe_set_grid_item(x, write_index, item)
					_safe_set_grid_item(x, y, null)
					
					if item.has_method("set_grid_position"):
						item.set_grid_position(x, write_index)
					else:
						item.grid_x = x
						item.grid_y = write_index
					
					var new_pos = _get_cell_center(x, write_index)
					tween.tween_property(item, "position", new_pos, 0.3)
					tiles_moved = true
				write_index -= 1
	
	# Clear cached matches after gravity
	_cached_matches.clear()
	_grid_hash = ""

	if tiles_moved:
		await tween.finished
	debug_print("Finished applying gravity.")

	#print("Refilling grid...")
	#var items_to_create = []
	#
	#for x in range(grid_width):
		#var empty_count = 0
		#for y in range(grid_height):
			#if grid_data[x][y] == null:
				#empty_count += 1
				#items_to_create.append({
					#"x": x,
					#"y": y,
					#"drop_from": y - empty_count
				#})
	#
	#if items_to_create.size() == 0:
		#print("No empty cells to refill.")
		#return
	#
	#var tween = create_tween().set_parallel(true)
	#
	#for item_info in items_to_create:
		#var x = item_info.x
		#var y = item_info.y
		#var drop_from = item_info.drop_from
		#
		#var item_type = _get_safe_refill_type(x, y)
		#var item_instance = _create_item(item_type, x, y)
		#grid_data[x][y] = item_instance
		#
		#var start_pos = _get_cell_center(x, drop_from)
		#item_instance.position = start_pos
		#
		#var end_pos = _get_cell_center(x, y)
		#var drop_distance = y - drop_from
		#var drop_time = 0.1 + (drop_distance * 0.05)
		#
		#tween.tween_property(item_instance, "position", end_pos, drop_time)
	#
	#await tween.finished
	#print("Finished refilling grid.")

func refill_grid():
	debug_print("Refilling grid...")
	var items_to_create = []
	
	for x in range(grid_width):
		var empty_count = 0
		for y in range(grid_height):
			if _safe_get_grid_item(x, y) == null:
				empty_count += 1
				items_to_create.append({
					"x": x,
					"y": y,
					"drop_from": y - empty_count
				})
	
	if items_to_create.size() == 0:
		debug_print("No empty cells to refill.")
		return
	
	var tween = create_tween().set_parallel(true)
	
	for item_info in items_to_create:
		var x = item_info.x
		var y = item_info.y
		var drop_from = item_info.drop_from
		
		var item_type = _get_safe_refill_type(x, y)
		var item_instance = _create_item(item_type, x, y)
		if item_instance != null:
			_safe_set_grid_item(x, y, item_instance)
			
			var start_pos = _get_cell_center(x, drop_from)
			item_instance.position = start_pos
			
			var end_pos = _get_cell_center(x, y)
			var drop_distance = y - drop_from
			var drop_time = 0.1 + (drop_distance * 0.05)
			
			tween.tween_property(item_instance, "position", end_pos, drop_time)
	
	# Clear cached matches after refill
	_cached_matches.clear()
	_grid_hash = ""
	
	await tween.finished
	debug_print("Finished refilling grid.")

	#var possible_types = range(colors.size())
	#var attempts = 0
	#var max_attempts = 10
	#
	#while attempts < max_attempts:
		#var test_type = possible_types[randi() % possible_types.size()]
		#
		#var horizontal_safe = true
		#if x >= 2 and grid_data[x-1][y] != null and grid_data[x-2][y] != null:
			#var t1 = _get_base_type(grid_data[x-1][y].item_type)
			#var t2 = _get_base_type(grid_data[x-2][y].item_type)
			#if t1 == t2 and t1 == test_type:
				#horizontal_safe = false
		#
		#var vertical_safe = true
		#if y >= 2 and grid_data[x][y-1] != null and grid_data[x][y-2] != null:
			#var t1 = _get_base_type(grid_data[x][y-1].item_type)
			#var t2 = _get_base_type(grid_data[x][y-2].item_type)
			#if t1 == t2 and t1 == test_type:
				#vertical_safe = false
		#
		#if horizontal_safe and vertical_safe:
			#return test_type
		#
		#attempts += 1
	#
	#return randi() % colors.size()

func _get_safe_refill_type(x: int, y: int) -> int:
	var possible_types = range(colors.size())
	var attempts = 0
	var max_attempts = 10
	
	while attempts < max_attempts:
		var test_type = possible_types[randi() % possible_types.size()]
		
		var horizontal_safe = true
		if x >= 2:
			var item1 = _safe_get_grid_item(x-1, y)
			var item2 = _safe_get_grid_item(x-2, y)
			if item1 != null and item2 != null:
				var t1 = _get_base_type(item1.item_type)
				var t2 = _get_base_type(item2.item_type)
				if t1 == t2 and t1 == test_type:
					horizontal_safe = false
		
		var vertical_safe = true
		if y >= 2:
			var item1 = _safe_get_grid_item(x, y-1)
			var item2 = _safe_get_grid_item(x, y-2)
			if item1 != null and item2 != null:
				var t1 = _get_base_type(item1.item_type)
				var t2 = _get_base_type(item2.item_type)
				if t1 == t2 and t1 == test_type:
					vertical_safe = false
		
		if horizontal_safe and vertical_safe:
			return test_type
		
		attempts += 1
	
	# Fallback if no safe type found
	return randi() % colors.size()
