# grid.gd
# Renamed from grid.gd to Game.gd to represent the main game logic.

extends Node2D

class_name Game

# --- Game Board Properties ---
# These variables control the size and layout of the game grid.
var grid_width = 6
var grid_height = 6
var cell_size = 90
var shelf_gap_x = 10
var shelf_gap_y = 15
var use_shelf_gaps = false # Flag to enable/disable visual gaps
var padding = 60

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

# New dictionary to hold a colored texture for each type
var color_textures: Dictionary = {}

# --- Processing State ---
var is_processing_cascade = false # Prevents input during match cascades

# --- Utility Functions for Item Types ---
func _is_powerup_bomb(item_type):
	return item_type >= POWERUP_BOMB_TYPE

func _get_base_type(item_type):
	if _is_powerup_bomb(item_type):
		return item_type - POWERUP_BOMB_TYPE
	return item_type

# --- Core Functions ---
func _ready():
	print("--- Game Started ---")
	randomize()
	color_textures = {}
	
	# Create the textures
	await _preload_color_textures() 
	# Calculate total grid dimensions and position the grid in the center of the viewport.
	var grid_total_width = (grid_width * cell_size) + ((grid_width - 1) * shelf_gap_x)
	var grid_total_height = (grid_height * cell_size) + ((grid_height - 1) * shelf_gap_y)
	
	position = Vector2(-grid_total_width / 2, -grid_total_height / 2)
	
	# Configure the background panel and border.
	var background_panel = get_node("Panel")
	if background_panel != null:
		background_panel.size = Vector2(grid_total_width + padding, grid_total_height + padding)
		background_panel.position = Vector2(-padding / 2, -padding / 2)
		var stylebox_panel = background_panel.get_theme_stylebox("panel")
		if stylebox_panel is StyleBoxFlat:
			stylebox_panel.border_width_top = 10
			stylebox_panel.border_width_bottom = 10
			stylebox_panel.border_width_left = 10
			stylebox_panel.border_width_right = 10
			stylebox_panel.border_color = Color("#c8a13a")



	#Function to populate the color dictionary for display
	_preload_color_textures()
	# Generate the initial grid and set up the level.
	_generate_grid()
	_setup_level_goals()
	time_left = time_limit
	
	# Get references to the UI nodes.
	time_label = get_node("../../../UI/VBoxContainer/Timer")
	playerMsg_label = get_node("../../../UI/VBoxContainer/playerMsg")
	goal_label = get_node("../../../UI/VBoxContainer/Goals")

	if playerMsg_label != null:
		playerMsg_initial_position = playerMsg_label.position

func _process(delta):
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
func _setup_level_goals():
	"""Setup goals for the current level. This can be customized per level."""
	print("=== SETUP LEVEL GOALS DEBUG ===")
	print("Setting up level goals...")
	
	# Clear level-specific dictionaries (NOT color_textures!)
	level_goals.clear()
	level_progress.clear()
	
	# Example goals for different levels - you can modify these or make them configurable
	var goals_to_set: Dictionary = {
		0: 15, # Cyan tiles
		1: 10, # Orange tiles
		2: 8,  # Green tiles
	}
	
	print_rich("[color=yellow]level goals[/color]: ","[color=15]goal1[/color]")
	
	# DEBUG: Check color_textures before using it
	print("color_textures dictionary: ", color_textures)
	print("color_textures size: ", color_textures.size())
	for key in color_textures.keys():
		print("  Key ", key, ": ", color_textures[key], " (size: ", color_textures[key].get_size() if color_textures[key] else "null", ")")
	
	# Pass the preloaded textures directly
	var tile_info_to_set = color_textures.duplicate()  # Make a copy to be safe
	level_goals = goals_to_set.duplicate()
	
	for color_type in level_goals.keys():
		level_progress[color_type] = 0
	
	is_level_complete = false
	print("Level goals set: ", level_goals)
	print("tile_info_to_set: ", tile_info_to_set)
	
	# Send goals and tile info to Global singleton.
	Global.set_goals(level_goals, tile_info_to_set, colors)
	print("=== SETUP LEVEL GOALS COMPLETE ===")

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
	_setup_level_goals()



func set_custom_level_goals(goals_dict: Dictionary, tile_info_to_set: Dictionary):
	"""Allow setting custom goals for different levels"""
	level_goals = goals_dict.duplicate()
	level_progress.clear()
	
	for color_type in level_goals.keys():
		level_progress[color_type] = 0
	
	is_level_complete = false
	print("Custom level goals set: ", level_goals)
	
	# Send goals to Global singleton
	Global.set_goals(level_goals, tile_info_to_set, colors)

func _update_goal_display():
	"""Update the goal display UI - now handled by Global singleton"""
	# Since Global singleton handles the display updates,
	# we just need to check for level completion
	_check_level_completion()

func _check_level_completion():
	"""Check if all level goals have been met"""
	# Check using Global singleton
	var goals_complete = Global.are_goals_complete()
	if goals_complete and not is_level_complete:
		is_level_complete = true
		return true
	return false

func level_complete():
	"""Handle level completion"""
	var completion_text = "LEVEL COMPLETE!\nScore: " + str(score) + "\nTime Bonus: " + str(int(time_left * 10))
	if not is_game_over:
		is_game_over = true
		score += int(time_left * 10)
		print("You win! Final Score: ", score)
		print("Ending level!!!")
		if time_label != null:
			time_label.text = completion_text
			game_over(completion_text)

func game_over(completion_text = null):
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
