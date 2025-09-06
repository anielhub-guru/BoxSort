extends Node2D
class_name GameManager2s

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
			# Ensure gravity and refill happen in sequence
			await apply_gravity()
			await refill_grid()
		else:
			debug_print("Cascade Round " + str(cascade_round) + ": No more matches found. Ending cascade.")
			break
	
	if cascade_round >= MAX_CASCADE_ROUNDS:
		debug_print("WARNING: Maximum cascade rounds reached!")
	
	debug_print("--- Cascade Complete ---")
	
	
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

func refill_grid():
	if refill_in_progress:
		debug_print("Refill already in progress. Aborting.")
		return
	
	# Don't refill if game is over or level is complete
	if is_game_over or is_level_complete:
		debug_print("Game over or level complete - skipping refill.")
		return

	debug_print("Refilling grid...")
	refill_in_progress = true	
	
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
		refill_in_progress = false  # Reset flag before returning
		return
	
	var tween = create_tween().set_parallel(true)
	
	for item_info in items_to_create:
		var x = item_info.x
		var y = item_info.y
		var drop_from = item_info.drop_from
		
		var item_type = _get_safe_item_type(x, y)
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
	refill_in_progress = false

# ============================================================================
# GAME STATE HANDLERS
# ============================================================================

func _handle_level_complete():
	current_game_state = GameState.LEVEL_COMPLETE
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
			playerMsg_label.text = "Get ready for Level " + str(current_level_number + 1)
			playerMsg_label.modulate = Color(0, 1, 0, 2)
			playerMsg_label.scale = Vector2(1.1, 1.1)
		
		# Add the flush effect
		flush_all_items()
		debug_print("Grid flushed")
		
		# Show the next level button
		if next_level_btn != null:
			next_level_btn.show()
			
		if restart_level_btn != null:
			restart_level_btn.show()

func _handle_game_over():
	current_game_state = GameState.GAME_OVER
	_deactivate_golden_time()
	
	# Show restart button
	if restart_level_btn != null:
		restart_level_btn.show()
	
	var final_score = "Game Over!\nScore: " + str(score)
	if not is_game_over:
		is_game_over = true
		print(final_score)
		if time_label != null:
			time_label.text = final_score
		# Add the flush effect
		flush_all_items()
	else:
		if time_label != null:
			time_label.text = final_score

func flush_all_items():
	"""Highlight and remove all items on the grid when game is over"""
	debug_print("Flushing all items from grid...")
	
	var all_positions = []
	
	# Collect all valid item positions
	for x in range(grid_width):
		for y in range(grid_height):
			var item = _safe_get_grid_item(x, y)
			if item != null and is_instance_valid(item):
				all_positions.append(Vector2(x, y))
	
	if all_positions.size() == 0:
		debug_print("No items to flush")
		return
	
	# Use your existing highlight_and_remove function with game over effect
	highlight_and_remove(all_positions, true)  # true for bomb-like effect
	
	debug_print("Finished flushing " + str(all_positions.size()) + " items")

func _on_next_level_button_pressed():
	if next_level_btn != null:
		next_level_btn.hide()
		restart_level_btn.hide()
	advance_to_next_level()

func _on_restart_level_button_pressed():
	restart_level()

func advance_to_next_level():
	var next_level = current_level_number + 1
	if next_level > max_available_level:
		debug_print("All levels completed!")
		_show_game_complete_message()
		return
	start_level(next_level)

func restart_level():
	var next_level = current_level_number 
	score = 0 # This resets the points from the failed level.
	_deactivate_golden_time()
	golden_time_extensions_used = 0
	time_freeze_active = false
	time_freeze_remaining = 0.0
	debug_print("Restarting level " + str(next_level))
	
	# Reset playerMsg properly
	if playerMsg_label != null:
		playerMsg_label.text = ""
		playerMsg_label.modulate = Color.WHITE
		playerMsg_label.scale = Vector2(1, 1)
	
	start_level(next_level)

func _show_game_complete_message():
	if playerMsg_label:
		playerMsg_label.text = "ALL LEVELS COMPLETE!"
		playerMsg_label.modulate = Color(1, 1, 0, 1)
		playerMsg_label.scale = Vector2(1.2, 1.2)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func _safe_get_grid_item(x: int, y: int):
	if not _is_grid_ready() or not _is_inside_grid(x, y):
		return null
	return grid_data[x][y]

func _safe_set_grid_item(x: int, y: int, item):
	if not _is_grid_ready() or not _is_inside_grid(x, y):
		return false
	grid_data[x][y] = item
	return true

func _is_grid_ready() -> bool:
	return grid_data.size() == grid_width and (grid_data.size() == 0 or grid_data[0].size() == grid_height)

func _is_inside_grid(x: int, y: int) -> bool:
	return x >= 0 and x < grid_width and y >= 0 and y < grid_height

func _get_powerup_type(item_type: int) -> int:
	if item_type >= PowerupType.TIME_FREEZE:
		return PowerupType.TIME_FREEZE
	elif item_type >= PowerupType.FISH:
		return PowerupType.FISH
	elif item_type >= PowerupType.LIGHTNING:
		return PowerupType.LIGHTNING
	elif item_type >= PowerupType.COLOR_BOMB:
		return PowerupType.COLOR_BOMB
	elif item_type >= PowerupType.WRAPPED:
		return PowerupType.WRAPPED
	elif item_type >= PowerupType.STRIPED_V:
		return PowerupType.STRIPED_V
	elif item_type >= PowerupType.STRIPED_H:
		return PowerupType.STRIPED_H
	elif item_type >= PowerupType.BOMB:
		return PowerupType.BOMB
	return PowerupType.NONE

func _get_base_type(item_type: int) -> int:
	if _is_any_powerup(item_type):
		var powerup_type = _get_powerup_type(item_type)
		return item_type - powerup_type
	return item_type

func _is_any_powerup(item_type: int) -> bool:
	return item_type >= PowerupType.BOMB

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

func debug_print(message: String):
	if DEBUG_MODE:
		print_rich(message)

func debug_texture_status():
	debug_print("=== TEXTURE DEBUG STATUS ===")
	debug_print("color_textures size: " + str(color_textures.size()))
	debug_print("powerup_textures size: " + str(powerup_textures.size()))
	debug_print("colors array size: " + str(colors.size()))
	debug_print("=== END TEXTURE DEBUG ===")

	
func _clear_position_cache():
	"""Clear the position cache when grid layout changes"""
	if has_meta("grid_position_cache"):
		set_meta("grid_position_cache", {})

func _execute_callable(callable: Callable):
	"""Helper function to execute deferred callables"""
	callable.call()

# ============================================================================
# POWERUP CONFIGURATION
# ============================================================================

func add_single_powerup(powerup_type: PowerupType, count: int = 1):
	var config = {powerup_type: count}
	initial_powerup_config = config.duplicate()
	debug_print("Single powerup configured: " + str(powerup_type) + " x" + str(count))

# ============================================================================
# RESOURCE LOADING
# ============================================================================

func _preload_powerup_textures():
	"""Preload all power-up sprite textures"""
	powerup_textures = {
		PowerupType.BOMB: load("res://sprites/tnt.svg"),
		PowerupType.STRIPED_H: load("res://sprites/wave_right.svg"),
		PowerupType.STRIPED_V: load("res://sprites/wave_left.svg"),
		PowerupType.WRAPPED: load("res://sprites/volcano.svg"),
		PowerupType.COLOR_BOMB: load("res://sprites/rocket_barrage.svg"),
		PowerupType.LIGHTNING: load("res://sprites/storm.svg"),
		PowerupType.FISH: load("res://sprites/fish.svg"),
		PowerupType.TIME_FREEZE: load("res://sprites/hourglass.svg")
	}
	debug_print("Loaded " + str(powerup_textures.size()) + " power-up textures")

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
			var level_num = int(level["level_number"])
			
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

func _parse_color_from_string(color_str: String) -> Color:
	"""Parse color from hex string or color name"""
	if color_str.begins_with("#"):
		# Hex color parsing
		var hex = color_str.substr(1)
		if hex.length() == 6:
			var r = ("0x" + hex.substr(0, 2)).hex_to_int() / 255.0
			var g = ("0x" + hex.substr(2, 2)).hex_to_int() / 255.0
			var b = ("0x" + hex.substr(4, 2)).hex_to_int() / 255.0
			return Color(r, g, b, 1.0)
	
	# Fallback to white if parsing fails
	return Color.WHITE

func _get_safe_item_type(x: int, y: int) -> int:
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

# ============================================================================
# MISSING IMPLEMENTATIONS FOR COMPATIBILITY
# ============================================================================

func _apply_powerup_visual_effects(material, item_type: int, base_color: Color):
	"""Apply visual effects based on power-up type"""
	var powerup_type = _get_powerup_type(item_type)
	
	# Reset all shader parameters first
	_reset_shader_parameters(material)
	
	# Set base color
	material.set_shader_parameter("base_color", base_color)
	
	match powerup_type:
		PowerupType.BOMB:
			material.set_shader_parameter("fire_effect", true)
			material.set_shader_parameter("fire_speed", 0.5)
			material.set_shader_parameter("pulse_strength", 0.3)
			material.set_shader_parameter("pulse_speed", 0.8)
		
		PowerupType.STRIPED_H:
			material.set_shader_parameter("stripe_horizontal", true)
			material.set_shader_parameter("stripe_color", Color.WHITE)
			material.set_shader_parameter("stripe_width", 0.15)
			material.set_shader_parameter("stripe_speed", 1.8)
		
		PowerupType.STRIPED_V:
			material.set_shader_parameter("stripe_vertical", true)
			material.set_shader_parameter("stripe_color", Color.WHITE)
			material.set_shader_parameter("stripe_width", 0.15)
			material.set_shader_parameter("stripe_speed", 1.8)
		
		PowerupType.WRAPPED:
			material.set_shader_parameter("is_wrapped", true)
			material.set_shader_parameter("glow_strength", 0.6)
			material.set_shader_parameter("glow_color", base_color.lightened(0.4))
			material.set_shader_parameter("pulse_strength", 0.2)
			material.set_shader_parameter("pulse_speed", 1.2)
		
		PowerupType.COLOR_BOMB:
			material.set_shader_parameter("fire_effect", true)
			material.set_shader_parameter("fire_speed", 1.5)
			material.set_shader_parameter("pulse_strength", 0.3)
			material.set_shader_parameter("pulse_speed", 1.8)
		
		PowerupType.LIGHTNING:
			material.set_shader_parameter("lightning_effect", true)
			material.set_shader_parameter("lightning_intensity", 5)
			material.set_shader_parameter("lightning_speed", 3.0)
			material.set_shader_parameter("lightning_color", Color.WHITE)
		
		PowerupType.FISH:
			material.set_shader_parameter("fish_effect", true)
			material.set_shader_parameter("wave_strength", 0.4)
			material.set_shader_parameter("wave_frequency", 3.0)

		PowerupType.TIME_FREEZE:
			material.set_shader_parameter("fish_effect", true)
			material.set_shader_parameter("wave_strength", 0.2)
			material.set_shader_parameter("wave_frequency", 2.0)

func _reset_shader_parameters(material):
	"""Reset all shader parameters to default values"""
	material.set_shader_parameter("is_bomb", false)
	material.set_shader_parameter("stripe_horizontal", false)
	material.set_shader_parameter("stripe_vertical", false)
	material.set_shader_parameter("is_wrapped", false)
	material.set_shader_parameter("fire_effect", false)
	material.set_shader_parameter("lightning_effect", false)
	material.set_shader_parameter("fish_effect", false)
	
	material.set_shader_parameter("pulse_strength", 0.0)
	material.set_shader_parameter("pulse_speed", 2.0)
	material.set_shader_parameter("stripe_width", 0.2)
	material.set_shader_parameter("stripe_speed", 1.5)
	material.set_shader_parameter("glow_strength", 0.0)
	material.set_shader_parameter("sparkle_intensity", 0.0)
	material.set_shader_parameter("wave_strength", 0.0)

func _check_for_square_matches() -> Dictionary:
	"""Check for 2x2 square matches and return positions to create fish powerups"""
	var fish_positions = {}
	
	for x in range(grid_width - 1):
		for y in range(grid_height - 1):
			if _is_2x2_square_match(x, y):
				fish_positions[Vector2(x, y)] = true
				debug_print("Found 2x2 square match at (" + str(x) + "," + str(y) + ")")
	
	return fish_positions

func _is_2x2_square_match(x: int, y: int) -> bool:
	"""Check if there's a 2x2 square of the same color starting at position (x,y)"""
	var top_left = _safe_get_grid_item(x, y)
	var top_right = _safe_get_grid_item(x + 1, y)
	var bottom_left = _safe_get_grid_item(x, y + 1)
	var bottom_right = _safe_get_grid_item(x + 1, y + 1)
	
	if top_left == null or top_right == null or bottom_left == null or bottom_right == null:
		return false
	
	if not is_instance_valid(top_left) or not is_instance_valid(top_right) or not is_instance_valid(bottom_left) or not is_instance_valid(bottom_right):
		return false
	
	var type1 = _get_base_type(top_left.item_type)
	var type2 = _get_base_type(top_right.item_type)
	var type3 = _get_base_type(bottom_left.item_type)
	var type4 = _get_base_type(bottom_right.item_type)
	
	return type1 == type2 and type2 == type3 and type3 == type4

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

func _is_corner_match(x: int, y: int, length: int) -> bool:
	"""Check if match occurs at board corners, edges, or specific patterns for wrapped candy"""
	
	if length < 4:
		return false
	
	# Near corners (within 1-2 cells of any corner)
	var near_left_edge = x <= 1
	var near_right_edge = x >= grid_width - 2
	var near_top_edge = y <= 1
	var near_bottom_edge = y >= grid_height - 2
	
	var near_corner = (near_left_edge or near_right_edge) and (near_top_edge or near_bottom_edge)
	if near_corner:
		debug_print("Near-corner match detected at (" + str(x) + "," + str(y) + ")")
		return true
	
	# Edge matches with sufficient length (5+ tiles)
	if length >= 5:
		var is_edge = (x == 0 or x == grid_width-1 or y == 0 or y == grid_height-1)
		if is_edge:
			debug_print("Edge match with length " + str(length) + " detected at (" + str(x) + "," + str(y) + ")")
			return true
	
	return false

func _check_powerup_combination(item1, item2, to_remove: Dictionary):
	"""Check if two power-ups are being combined and trigger special effects"""
	if not _is_any_powerup(item1.item_type) or not _is_any_powerup(item2.item_type):
		return false
	
	var powerup1 = _get_powerup_type(item1.item_type)
	var powerup2 = _get_powerup_type(item2.item_type)
	var pos1 = Vector2(item1.grid_x, item1.grid_y)
	var pos2 = Vector2(item2.grid_x, item2.grid_y)
	
	debug_print("Power-up combination detected: " + str(powerup1) + " + " + str(powerup2))
	
	# Same power-up combinations
	if powerup1 == powerup2:
		_trigger_same_powerup_combination(powerup1, pos1, pos2, to_remove)
		return true
	
	# Different power-up combinations
	_trigger_mixed_powerup_combination(powerup1, powerup2, pos1, pos2, to_remove)
	return true

func _trigger_same_powerup_combination(powerup_type: int, pos1: Vector2, pos2: Vector2, to_remove: Dictionary):
	"""Handle combinations of the same power-up type"""
	match powerup_type:
		PowerupType.BOMB:
			_trigger_mega_bomb_effect(pos1, to_remove)
			debug_print("Mega bomb effect triggered!")
		
		PowerupType.STRIPED_H:
			_trigger_triple_row_effect(int(pos1.y), to_remove)
			debug_print("Triple row clear effect triggered!")
		
		PowerupType.STRIPED_V:
			_trigger_triple_column_effect(int(pos1.x), to_remove)
			debug_print("Triple column clear effect triggered!")
		
		PowerupType.WRAPPED:
			_trigger_double_wrapped_effect(pos1, to_remove)
			debug_print("Double wrapped explosion triggered!")
		
		PowerupType.COLOR_BOMB:
			_trigger_clear_board_effect(to_remove)
			debug_print("Board clear effect triggered!")
		
		PowerupType.LIGHTNING:
			_trigger_star_constellation_effect(to_remove)
			debug_print("Star constellation effect triggered!")
		
		PowerupType.FISH:
			_trigger_fish_swarm_effect(to_remove)
			debug_print("Fish swarm effect triggered!")
			
		PowerupType.TIME_FREEZE:
			_trigger_mega_bomb_effect(pos1, to_remove)
			debug_print("Mega bomb effect triggered!")
			
			
func _trigger_mixed_powerup_combination(powerup1: int, powerup2: int, pos1: Vector2, pos2: Vector2, to_remove: Dictionary):
	"""Handle combinations of different power-up types"""
	var types = [powerup1, powerup2]
	types.sort()
	
	# Color bomb combinations (always clear specific patterns)
	if PowerupType.COLOR_BOMB in types:
		if PowerupType.STRIPED_H in types or PowerupType.STRIPED_V in types:
			_trigger_color_to_striped_effect(to_remove)
		elif PowerupType.WRAPPED in types:
			_trigger_color_to_wrapped_effect(to_remove)
		elif PowerupType.BOMB in types:
			_trigger_color_to_bomb_effect(to_remove)
	
	# Striped + Wrapped = L-shaped mega explosion
	elif (PowerupType.STRIPED_H in types or PowerupType.STRIPED_V in types) and PowerupType.WRAPPED in types:
		_trigger_striped_wrapped_combo(pos1, to_remove)
	
	# Other combinations default to both effects
	else:
		debug_print("Mixed combo: applying both effects")
		_trigger_powerup_effect(pos1, to_remove)
		_trigger_powerup_effect(pos2, to_remove)

func _trigger_mega_bomb_effect(pos: Vector2, to_remove: Dictionary):
	"""5x5 explosion around position"""
	var x = int(pos.x)
	var y = int(pos.y)
	
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				to_remove[Vector2(new_x, new_y)] = true

func _trigger_triple_row_effect(center_row: int, to_remove: Dictionary):
	"""Clear 3 rows centered on the given row"""
	for row_offset in range(-1, 2):
		var target_row = center_row + row_offset
		if target_row >= 0 and target_row < grid_height:
			for x in range(grid_width):
				to_remove[Vector2(x, target_row)] = true

func _trigger_triple_column_effect(center_col: int, to_remove: Dictionary):
	"""Clear 3 columns centered on the given column"""
	for col_offset in range(-1, 2):
		var target_col = center_col + col_offset
		if target_col >= 0 and target_col < grid_width:
			for y in range(grid_height):
				to_remove[Vector2(target_col, y)] = true

func _trigger_double_wrapped_effect(pos: Vector2, to_remove: Dictionary):
	"""3x3 explosion followed by 7x7 explosion"""
	var x = int(pos.x)
	var y = int(pos.y)
	
	# First explosion (3x3)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				to_remove[Vector2(new_x, new_y)] = true
	
	# Schedule larger explosion - FIXED
	var delayed_callable = func(): _trigger_delayed_explosion(x, y, 3)
	call_deferred("_execute_callable", delayed_callable)
	
	
func _trigger_delayed_explosion(x: int, y: int, radius: int):
	"""Delayed larger explosion for wrapped combo"""
	await get_tree().create_timer(0.5).timeout
	
	var delayed_remove = {}
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				delayed_remove[Vector2(new_x, new_y)] = true
	
	if delayed_remove.size() > 0:
		highlight_and_remove(delayed_remove.keys(), true)
		
	

func _trigger_clear_board_effect(to_remove: Dictionary):
	"""Remove all tiles on the board"""
	for x in range(grid_width):
		for y in range(grid_height):
			to_remove[Vector2(x, y)] = true

func _trigger_star_constellation_effect(to_remove: Dictionary):
	"""Remove corners and center cross pattern"""
	# Corner positions
	var corners = [
		Vector2(0, 0), Vector2(grid_width-1, 0),
		Vector2(0, grid_height-1), Vector2(grid_width-1, grid_height-1)
	]
	
	for corner in corners:
		to_remove[corner] = true
	
	# Center cross
	var center_x = grid_width / 2
	var center_y = grid_height / 2
	
	for x in range(grid_width):
		to_remove[Vector2(x, center_y)] = true
	for y in range(grid_height):
		to_remove[Vector2(center_x, y)] = true

func _trigger_fish_swarm_effect(to_remove: Dictionary):
	"""Target 8-12 random positions"""
	var available_positions = []
	for x in range(grid_width):
		for y in range(grid_height):
			available_positions.append(Vector2(x, y))
	
	available_positions.shuffle()
	var target_count = min(randi_range(8, 12), available_positions.size())
	
	for i in range(target_count):
		to_remove[available_positions[i]] = true

func _trigger_color_to_striped_effect(to_remove: Dictionary):
	"""Convert random color to striped, then activate all"""
	var target_color = _find_most_common_color()
	if target_color >= 0:
		for x in range(grid_width):
			for y in range(grid_height):
				var item = _safe_get_grid_item(x, y)
				if item != null and _get_base_type(item.item_type) == target_color:
					_trigger_striped_horizontal_effect(x, y, to_remove)

func _trigger_color_to_wrapped_effect(to_remove: Dictionary):
	"""Create 3 random wrapped explosions"""
	var available_positions = []
	for x in range(grid_width):
		for y in range(grid_height):
			available_positions.append(Vector2(x, y))
	
	available_positions.shuffle()
	for i in range(min(3, available_positions.size())):
		var pos = available_positions[i]
		_trigger_wrapped_effect(int(pos.x), int(pos.y), to_remove)

func _trigger_color_to_bomb_effect(to_remove: Dictionary):
	"""Convert random color to bombs then explode all"""
	var target_color = _find_most_common_color()
	if target_color >= 0:
		for x in range(grid_width):
			for y in range(grid_height):
				var item = _safe_get_grid_item(x, y)
				if item != null and _get_base_type(item.item_type) == target_color:
					_trigger_bomb_effect(x, y, to_remove)

func _trigger_striped_wrapped_combo(pos: Vector2, to_remove: Dictionary):
	"""L-shaped mega explosion"""
	var x = int(pos.x)
	var y = int(pos.y)
	
	# Clear entire row and column, then add 3x3 around intersection
	for i in range(grid_width):
		to_remove[Vector2(i, y)] = true
	for i in range(grid_height):
		to_remove[Vector2(x, i)] = true
	
	# Add 3x3 explosion at intersection
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				to_remove[Vector2(new_x, new_y)] = true

func _find_most_common_color() -> int:
	"""Find the most common color type on the board"""
	var color_counts = {}
	for x in range(grid_width):
		for y in range(grid_height):
			var item = _safe_get_grid_item(x, y)
			if item != null:
				var base_type = _get_base_type(item.item_type)
				color_counts[base_type] = color_counts.get(base_type, 0) + 1
	
	var max_count = 0
	var target_color = -1
	for color_type in color_counts.keys():
		if color_counts[color_type] > max_count:
			max_count = color_counts[color_type]
			target_color = color_type
	
	return target_color# grid.gd - Refactored with Critical Fixes


# ============================================================================
# ENUMS AND CONSTANTS
# ============================================================================

enum PowerupType {
	NONE = 0,
	BOMB = 100,
	STRIPED_H = 200,
	STRIPED_V = 300,
	WRAPPED = 400,
	COLOR_BOMB = 500,
	LIGHTNING = 600,
	FISH = 700,
	TIME_FREEZE = 800
}

enum GameState {
	INITIALIZING,
	PLAYING,
	PROCESSING_CASCADE,
	LEVEL_COMPLETE,
	GAME_OVER,
	PAUSED
}

enum MatchDirection {
	HORIZONTAL,
	VERTICAL,
	SQUARE
}

# Game configuration constants
const DEBUG_MODE = true
const MAX_CASCADE_ROUNDS = 10
const ASYNC_TIMEOUT = 5.0

# ============================================================================
# GAME STATE VARIABLES
# ============================================================================

# Core game state
var current_game_state: GameState = GameState.INITIALIZING
var current_level_number: int = 5
var score: int = 0
var total_score: int = 0
var time_left: float = 0.0
var is_level_complete: bool = false
var is_game_over: bool = false
var _game_initialized: bool = false
var _level_completion_processed: bool = false

# Grid properties
var grid_width: int = 6
var grid_height: int = 6
var cell_size: int = 90
var shelf_gap_x: int = 10
var shelf_gap_y: int = 15
var use_shelf_gaps: bool = false
var padding: int = 60
var grid_data: Array = []

# Level management
var levels_data: Dictionary = {}
var max_available_level: int = 1
var level_goals: Dictionary = {}
var level_progress: Dictionary = {}

# Special game mechanics
var golden_time_active: bool = false
var golden_time_extensions_used: int = 0
var golden_time_max_extensions: int = 10
var golden_time_score_multiplier: int = 2
var golden_time_bonus_per_match: float = 0.5
var golden_time_powerup_chance: float = 0.1
var golden_time_tween: Tween = null

var time_freeze_active: bool = false
var time_freeze_duration: float = 5.0
var time_freeze_remaining: float = 0.0

# Input and interaction
var dragging: bool = false
var dragged_item: Node2D = null
var target_item: Node2D = null
var drag_start_pos: Vector2
var drag_offset: Vector2
var start_x: int = 0
var start_y: int = 0

# Processing flags
var is_processing_cascade: bool = false
var _processing_bomb_effects: bool = false
var refill_in_progress: bool = false
var is_matching_in_progress: bool = false

# Resources and references
var draggable_item_scene = preload("res://scene/DraggableItem.tscn")
var missile_scene = preload("res://scene/missile.tscn")
var explosion_scene = preload("res://scene/explosion_particle.tscn")

var powerup_textures: Dictionary = {}
var color_textures: Dictionary = {}
var colors: Array = [
	Color8(77, 255, 255), Color8(255, 179, 77), Color8(82, 224, 149),
	Color8(255, 128, 191), Color8(255, 235, 77), Color8(77, 149, 255),
	Color8(255, 96, 77), Color8(149, 77, 255)
]

# UI references
@onready var time_label: Label = get_node_or_null("../../../UI/VBoxContainer/Timer")
@onready var playerMsg_label: Label = get_node_or_null("../../../UI/VBoxContainer/playerMsg")
@onready var goal_label: Label = get_node_or_null("../../../UI/VBoxContainer/Goals")
@onready var tile_match_audio: AudioStreamPlayer = get_node_or_null("../TileMatchAudio")

var playerMsg_initial_position: Vector2
var next_level_btn
var restart_level_btn
@export var bonus_time_per_match: float = 0.2

# Cache and optimization
var _cached_matches: Dictionary = {}
var _grid_hash: String = ""
var initial_powerup_config: Dictionary = {}

# ============================================================================
# INITIALIZATION AND SETUP
# ============================================================================

func _ready():
	debug_print("--- Game Started ---")
	randomize()
	_initialize_game()

func _initialize_game():
	current_game_state = GameState.INITIALIZING
	color_textures = {}
	
	load_levels_data()
	_setup_ui_references()
	await _create_color_textures_safe()
	_preload_powerup_textures()
	
	# Mark as initialized
	_game_initialized = true
	
	# Add test powerups for development
	_configure_test_powerups()
	
	current_game_state = GameState.PLAYING
	call_deferred("start_level", current_level_number)
	call_deferred("debug_texture_status")

func _setup_ui_references():
	if playerMsg_label != null:
		playerMsg_initial_position = playerMsg_label.position
	
	next_level_btn = get_node_or_null("../../../MarginContainer/VBoxContainer/NextLevelButton")
	restart_level_btn = get_node_or_null("../../../MarginContainer/VBoxContainer/RestartButton")
	
	if next_level_btn != null:
		next_level_btn.pressed.connect(_on_next_level_button_pressed)
		next_level_btn.hide()
	
	if restart_level_btn != null:
		restart_level_btn.pressed.connect(_on_restart_level_button_pressed)

func _configure_test_powerups():
	add_single_powerup(PowerupType.COLOR_BOMB, 2)

# ============================================================================
# LEVEL MANAGEMENT
# ============================================================================

func start_level(level_number: int):
	if not _game_initialized:
		debug_print("Game not fully initialized, deferring level start")
		call_deferred("start_level", level_number)
		return
	
	total_score += score
	score = 0
	debug_print("Starting level " + str(level_number) + ", total score is " + str(total_score))
	
	current_game_state = GameState.PLAYING
	_reset_special_states()
	_clear_grid()
	
	if not await load_level(level_number):
		debug_print("Failed to load level, using default")
		await load_level(1)
	
	_recalculate_grid_position()
	_generate_grid()
	_update_level_display(level_number)

func load_level(level_number: int) -> bool:
	debug_print("Loading level " + str(level_number))
	
	if not levels_data.has(level_number):
		debug_print("Level " + str(level_number) + " not found")
		return false
	
	var level_data = levels_data[level_number]
	current_level_number = level_number
	
	# Validate required fields
	var required_fields = ["grid_size", "level_goals", "time_limit_seconds"]
	for field in required_fields:
		if not level_data.has(field):
			debug_print("ERROR: Level " + str(level_number) + " missing required field: " + field)
			return false
	
	# Apply level configuration
	_apply_level_grid_size(level_data.get("grid_size", {}))
	_apply_level_goals(level_data.get("level_goals", {}))
	_apply_level_colors(level_data.get("colors_array", []))
	
	time_left = float(level_data.get("time_limit_seconds", 60))
	
	# Clear level-specific dictionaries (NOT color_textures!)
	level_goals.clear()
	level_progress.clear()
	
	# Set the goals in the Global singleton for other nodes to access
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
	
	await _create_color_textures_safe()
	
	# FIXED: Proper Global singleton communication
	_update_global_singleton(level_goals, color_textures, colors)
	
	# Reset level state
	is_level_complete = false
	_level_completion_processed = false
	is_game_over = false
	
	return true

func _apply_level_grid_size(grid_size_data: Dictionary):
	if grid_size_data.has("rows") and grid_size_data.has("cols"):
		grid_height = int(grid_size_data["rows"])
		grid_width = int(grid_size_data["cols"])
		debug_print("Set grid size to " + str(grid_width) + "x" + str(grid_height))

func _apply_level_goals(goals_data: Dictionary):
	level_goals.clear()
	level_progress.clear()
	
	for key in goals_data.keys():
		var color_type = int(key)
		var goal_count = int(goals_data[key])
		level_goals[color_type] = goal_count
		level_progress[color_type] = 0

func _apply_level_colors(colors_data: Array):
	if colors_data.size() > 0:
		var level_colors = []
		for color_item in colors_data:
			if color_item is String:
				level_colors.append(_parse_color_from_string(color_item))
			else:
				level_colors.append(color_item)
		colors = level_colors
		debug_print("Updated colors array to: " + str(colors))

func _reset_special_states():
	_deactivate_golden_time()
	golden_time_extensions_used = 0
	time_freeze_active = false
	time_freeze_remaining = 0.0

# FIXED: Proper Global singleton communication
func _update_global_singleton(goals: Dictionary, textures: Dictionary, colors_array: Array):
	if Global and Global.has_method("set_goals"):
		Global.set_goals(goals, textures, colors_array)
		debug_print("Updated Global singleton with goals and textures")
	else:
		debug_print("WARNING: Global singleton not available or missing set_goals method")

# ============================================================================
# GAME LOOP AND STATE MANAGEMENT
# ============================================================================

func _process(delta):
	if not _game_initialized:
		return
	

	_update_time_system(delta)
	_check_and_activate_golden_time()
	_update_ui_display()
	_update_goal_display()

func _update_time_system(delta):
	if time_label == null:
		return
		
	if not is_game_over and not is_level_complete:
		# Only decrease time if time freeze is not active
		if not time_freeze_active:
			time_left -= delta
		else:
			# Update time freeze remaining
			time_freeze_remaining -= delta
			if time_freeze_remaining <= 0:
				time_freeze_active = false
				debug_print("Time freeze ended")
				_update_time_freeze_display()
		
		if time_left <= 0:
			time_left = 0
			_deactivate_golden_time()
			_handle_game_over()
		if time_left > 3:
			_deactivate_golden_time()
	elif is_level_complete:
		_handle_level_complete()
	else:
		_handle_game_over()

func _update_ui_display():
	if time_label == null:
		return
	
	var time_text = "Time: " + str(int(time_left)) + "\nScore: " + str(score)
	if time_freeze_active:
		time_text += "\nFROZEN: " + str(int(time_freeze_remaining))
	time_label.text = time_text

func _update_goal_display():
	"""Update the goal display UI - now handled by Global singleton"""
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

# ============================================================================
# GRID MANAGEMENT
# ============================================================================

func _generate_grid():
	if initial_powerup_config.size() > 0:
		_generate_grid_with_powerups()
	else:
		_generate_standard_grid()

func _generate_standard_grid():
	debug_print("Generating standard grid " + str(grid_width) + "x" + str(grid_height))
	
	_initialize_grid_data()
	
	for x in range(grid_width):
		for y in range(grid_height):
			var item_type = _get_safe_item_type(x, y)
			var item_instance = _create_item(item_type, x, y)
			
			if item_instance != null:
				grid_data[x][y] = item_instance

func _generate_grid_with_powerups():
	debug_print("Generating grid with powerups")
	
	_initialize_grid_data()
	var powerup_positions = _calculate_powerup_positions()
	
	for x in range(grid_width):
		for y in range(grid_height):
			var pos = Vector2(x, y)
			var item_instance = null
			
			if powerup_positions.has(pos):
				var powerup_type = powerup_positions[pos]
				var base_color = randi() % colors.size()
				item_instance = _create_item(base_color, x, y, powerup_type)
				debug_print("Created " + str(powerup_type) + " powerup with color " + str(base_color) + " at (" + str(x) + "," + str(y) + ")")
			else:
				var item_type = _get_safe_item_type(x, y)
				item_instance = _create_item(item_type, x, y)
			
			if item_instance != null:
				grid_data[x][y] = item_instance
			else:
				debug_print("ERROR: Failed to create item at (" + str(x) + "," + str(y) + ")")
	
	initial_powerup_config.clear()

func _initialize_grid_data():
	grid_data.clear()
	grid_data.resize(grid_width)
	for x in range(grid_width):
		grid_data[x] = []
		grid_data[x].resize(grid_height)
		for y in range(grid_height):
			grid_data[x][y] = null

func _calculate_powerup_positions() -> Dictionary:
	var all_positions = []
	for x in range(grid_width):
		for y in range(grid_height):
			all_positions.append(Vector2(x, y))
	all_positions.shuffle()
	
	var powerup_positions = {}
	var position_index = 0
	
	for powerup_type in initial_powerup_config.keys():
		var count = initial_powerup_config[powerup_type]
		for i in range(count):
			if position_index < all_positions.size():
				powerup_positions[all_positions[position_index]] = powerup_type
				position_index += 1
	
	return powerup_positions

func _clear_grid():
	debug_print("Clearing existing grid...")
	
	if grid_data.size() > 0:
		for x in range(grid_data.size()):
			if grid_data[x] is Array and grid_data[x].size() > 0:
				for y in range(grid_data[x].size()):
					var item = grid_data[x][y]
					if item != null and is_instance_valid(item):
						item.queue_free()
						grid_data[x][y] = null
	
	grid_data.clear()
	_cached_matches.clear()
	_grid_hash = ""
	debug_print("Grid cleared successfully")

# FIXED: Restore grid centering functionality
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
		debug_print("Updated background panel size and position")
	else:
		debug_print("WARNING: Background panel not found")

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


func grid_to_world_position(grid_x: int, grid_y: int) -> Vector2:
	"""Convert grid coordinates to world position - optimized version"""
	# Cache the calculation for better performance
	if not has_meta("grid_position_cache"):
		set_meta("grid_position_cache", {})
	
	var cache = get_meta("grid_position_cache")
	var cache_key = str(grid_x) + "," + str(grid_y)
	
	if cache.has(cache_key):
		return cache[cache_key]
	
	var extra_offset_x = 0.0
	var extra_offset_y = 0.0
	
	if use_shelf_gaps:
		extra_offset_x = (grid_x / 3.0) * shelf_gap_x
		extra_offset_y = (grid_y / 1.0) * shelf_gap_y
	else:
		extra_offset_x = grid_x * shelf_gap_x
		extra_offset_y = grid_y * shelf_gap_y
	
	var world_pos = Vector2(
		grid_x * cell_size + cell_size / 2 + extra_offset_x,
		grid_y * cell_size + cell_size / 2 + extra_offset_y
	)
	
	# Cache the result
	cache[cache_key] = world_pos
	return world_pos


# ============================================================================
# ITEM CREATION AND MANAGEMENT
# ============================================================================

# FIXED: Proper item creation with sprite support
func _create_item(item_type: int, x: int, y: int, powerup_type: int = 0) -> Node2D:
	var item_instance = draggable_item_scene.instantiate()
	
	# Determine the actual item type - FIXED VERSION
	var final_item_type = item_type
	if powerup_type > 0:
		# Use the provided powerup type
		final_item_type = powerup_type + item_type
		debug_print("Creating powerup item: base=" + str(item_type) + " powerup=" + str(powerup_type) + " final=" + str(final_item_type))
	
	item_instance.item_type = final_item_type
	item_instance.grid_x = x
	item_instance.grid_y = y
	
	var sprite_instance = item_instance.get_node("Sprite2D")
	if sprite_instance == null:
		debug_print("ERROR: Sprite2D not found in draggable item!")
		return null
	
	# Set the appropriate texture for powerups
	var powerup_offset = _get_powerup_type(final_item_type)
	
	if powerup_offset > 0 and powerup_textures.has(powerup_offset):
		sprite_instance.texture = powerup_textures[powerup_offset]
		debug_print("Applied powerup texture for type: " + str(powerup_offset))
	
	# Create new material instance - IMPORTANT for shader effects
	var new_material = null
	if sprite_instance.material != null:
		new_material = sprite_instance.material.duplicate()
	else:
		# Create a new ShaderMaterial if none exists
		new_material = ShaderMaterial.new()
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
	
	# FIXED: Position calculation with proper offset
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

# ============================================================================
# MATCH DETECTION AND PROCESSING
# ============================================================================

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

	# Check for 2x2 square matches first (for fish powerups)
	var square_matches = _check_for_square_matches()
	for square_pos in square_matches.keys():
		var x = int(square_pos.x)
		var y = int(square_pos.y)
		
		# Get the color type from one of the square tiles
		var sample_item = _safe_get_grid_item(x, y)
		if sample_item != null:
			var base_type = _get_base_type(sample_item.item_type)
			
			# Mark all 4 tiles in the square for removal
			to_remove[Vector2(x, y)] = true
			to_remove[Vector2(x + 1, y)] = true
			to_remove[Vector2(x, y + 1)] = true
			to_remove[Vector2(x + 1, y + 1)] = true
			
			# Create fish powerup at the top-left position of the square
			new_bombs_to_create[square_pos] = {"type": base_type, "powerup": PowerupType.FISH}
			debug_print("Creating fish powerup from 2x2 square at (" + str(x) + "," + str(y) + ")")

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
					_process_match(x - 1, y, MatchDirection.HORIZONTAL, current_run_length, to_remove, new_bombs_to_create)
				current_run_length = 1
		if current_run_length >= 3:
			_process_match(grid_width - 1, y, MatchDirection.HORIZONTAL, current_run_length, to_remove, new_bombs_to_create)

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
					_process_match(x, y - 1, MatchDirection.VERTICAL, current_run_length, to_remove, new_bombs_to_create)
				current_run_length = 1
		if current_run_length >= 3:
			_process_match(x, grid_height - 1, MatchDirection.VERTICAL, current_run_length, to_remove, new_bombs_to_create)

	debug_print("Matches found: " + str(to_remove.size() > 0 or new_bombs_to_create.size() > 0))
	if to_remove.size() > 0 or new_bombs_to_create.size() > 0:
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
				powerup_type = bomb_data.get("powerup", PowerupType.BOMB)
			else:
				# Old format - just the base type, default to bomb
				base_type = bomb_data
				powerup_type = PowerupType.BOMB
			
			# Create the item with proper parameters
			var new_item = _create_item(base_type, int(pos.x), int(pos.y), powerup_type)
			if new_item != null:
				_safe_set_grid_item(int(pos.x), int(pos.y), new_item)

		return true

	return false

func _process_match(x: int, y: int, direction: MatchDirection, length: int, to_remove: Dictionary, new_bombs_to_create: Dictionary):
	var grid_item = _safe_get_grid_item(x, y)
	if grid_item == null:
		debug_print("ERROR: No item at match position (" + str(x) + "," + str(y) + ")")
		return
		
	debug_print("Processing a " + str(length) + " match at (" + str(x) + "," + str(y) + ")")
	var base_type = _get_base_type(grid_item.item_type)
	var matched_items = []

	# Collect matched items
	if direction == MatchDirection.HORIZONTAL:
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

	# Create appropriate power-up based on match length and pattern
	if merge_pos.x != -1 and not has_powerup_in_match:
		var powerup_to_create = _determine_powerup_type(length, direction, merge_pos)
		if powerup_to_create > 0:
			new_bombs_to_create[merge_pos] = {"type": base_type, "powerup": powerup_to_create}

	# Mark all matched items for removal
	for item in matched_items:
		if item != null:
			var item_pos = Vector2(item.grid_x, item.grid_y)
			if not to_remove.has(item_pos):
				to_remove[item_pos] = true

func highlight_and_remove(matched_positions: Array, is_bomb_effect: bool = false, delay_time: float = 0.0, color_type: int = 0):
	"""Highlight and remove tiles with audio per removal event"""
	debug_print("Highlighting and removing " + str(matched_positions.size()) + " tiles")
	
	# Only play audio if tiles are actually being removed
	if matched_positions.size() > 0:
		_play_tile_removal_audio()
	
	# Track progress and score immediately (don't wait for missiles)
	_track_goal_progress(matched_positions) 
	add_score(matched_positions.size())
	
	# For color bomb effects, wait for missiles to hit
	if delay_time > 0.0 or (is_bomb_effect and color_type >= 0):
		var missile_delay = 0.2  # Wait for missiles to hit
		await get_tree().create_timer(missile_delay).timeout
	
	# Visual effects based on effect type
	if is_bomb_effect:
		var tween = create_tween().set_parallel(true)
		for pos in matched_positions:
			var gx = int(pos.x)
			var gy = int(pos.y)
			var item = _safe_get_grid_item(gx, gy)
			if item != null and is_instance_valid(item):
				# Get the original tile color before modifying it
				var explosion_color = colors[color_type] if color_type < colors.size() else Color.WHITE
				var sprite = item.get_node_or_null("Sprite2D")
				if sprite != null:
					tween.tween_property(item, "scale", Vector2(1.2, 1.2), 0.05)
					tween.tween_property(item, "scale", Vector2(0, 0), 0.15).set_delay(0.05)
				
				# Use item's local position relative to grid
				_create_missile_explosion(item.position, color_type)
		
		await tween.finished
	else:
		# Standard match highlighting
		for pos in matched_positions:
			var gx = int(pos.x)
			var gy = int(pos.y)
			var item = _safe_get_grid_item(gx, gy)
			if item != null and is_instance_valid(item):
				var sprite = item.get_node_or_null("Sprite2D")
				if sprite != null:
					sprite.modulate = Color(1, 1, 0)
					if sprite.material != null:
						var removal_tween = create_tween()
						removal_tween.tween_property(sprite.material, "shader_parameter/removal_progress", 1.0, 0.2)
		
		await get_tree().create_timer(0.15).timeout
	
	# Remove items from grid immediately
	for pos in matched_positions:
		var gx = int(pos.x)
		var gy = int(pos.y)
		var item = _safe_get_grid_item(gx, gy)
		if item != null and is_instance_valid(item):
			item.queue_free()
			_safe_set_grid_item(gx, gy, null)
	
	# Clear cache and check completion
	_cached_matches.clear()
	_grid_hash = ""
	_check_level_completion()
	
	debug_print("Finished removing tiles - grid ready for refill")


func _track_goal_progress(matched_positions: Array):
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
		# Add score and get the time bonus (but don't display it here)
		add_score(total_progress)
		
		# Show progress message which now handles the time bonus display
		_show_goal_progress_message(color_counts)

func _show_goal_progress_message(color_counts: Dictionary):
	"""Show a message about goal progress with time bonus display"""
	if playerMsg_label == null:
		return
	
	var progress_text = ""
	var phrases = []
	var message_color = Color.WHITE
	
	# Show discouraging messages when game is over
	if is_game_over and not is_level_complete:
		phrases = ["Unfortunate...", "Try again..", "Maybe next time..", "So close!", "Don't give up!"]
		message_color = Color(1, 0.6, 0.6, 1)  # Light red tint
		progress_text = phrases.pick_random()
	
	# Show encouraging messages with time bonus during normal gameplay
	elif not is_game_over and not is_level_complete:
		var has_goal_progress = false
		var total_matched = 0
		
		for color_type in color_counts.keys():
			if level_goals.has(color_type):
				has_goal_progress = true
				total_matched += color_counts[color_type]
		
		if has_goal_progress and total_matched > 0:
			# Calculate and display time bonus
			var time_bonus = total_matched * bonus_time_per_match
			
			phrases = ["Great Job!", "Well done!", "Amazing!", "Wow!", "Nice!", "Excellent!"]
			message_color = Color(0.6, 1, 0.6, 1)  # Light green tint
			
			var encouragement = phrases.pick_random()
			progress_text = encouragement + " +" + str(time_bonus) + "s"
	
	# Display the message if we have text
	if not progress_text.is_empty():
		playerMsg_label.position = playerMsg_initial_position
		playerMsg_label.scale = Vector2(1, 1)
		playerMsg_label.modulate = message_color
		playerMsg_label.text = progress_text
		playerMsg_label.show()
		
		# Auto-fade the message after a delay - FIXED
		var fade_callable = func(): 
			var fade_tween = create_tween()
			fade_tween.tween_property(playerMsg_label, "modulate", Color.TRANSPARENT, 2.0)
		
		get_tree().create_timer(0.25).timeout.connect(fade_callable)
		
		
func add_score(matched_count: int):
	if is_game_over or is_level_complete:
		return
	
	var base_points = matched_count * 10
	var actual_points = base_points
	
	# Apply golden time multiplier
	if golden_time_active:
		actual_points = base_points * golden_time_score_multiplier
	
	score += actual_points
	
	# Enhanced time bonus during golden time
	var time_added = 0.0
	if golden_time_active and golden_time_extensions_used < golden_time_max_extensions:
		time_added = matched_count * golden_time_bonus_per_match
		golden_time_extensions_used += 1
		debug_print("Golden time bonus: +" + str(time_added) + "s (extension " + str(golden_time_extensions_used) + "/" + str(golden_time_max_extensions) + ")")
	else:
		time_added = matched_count * bonus_time_per_match
	
	time_left += time_added
	
	# Try to spawn golden time powerup
	if golden_time_active:
		_try_spawn_golden_time_powerup()
	
	# Return the time bonus for use in progress message
	return time_added


# ============================================================================
# AUDIO MANAGEMENT
# ============================================================================
func _play_tile_removal_audio():
	"""Play audio for tile removal events"""
	if tile_match_audio != null:
		tile_match_audio.play()
		debug_print("Audio played for tile removal")


# ============================================================================
# POWERUP SYSTEM
# ============================================================================

func _determine_powerup_type(length: int, direction: MatchDirection, position: Vector2) -> int:
	# Check for special patterns first
	if _check_for_l_or_t_shape(int(position.x), int(position.y)):
		debug_print("Creating BOMB from L/T shape at (" + str(position.x) + "," + str(position.y) + ")")
		return PowerupType.BOMB
	
	if _is_corner_match(int(position.x), int(position.y), length):
		debug_print("Creating WRAPPED from corner match at (" + str(position.x) + "," + str(position.y) + ")")
		return PowerupType.WRAPPED
	
	# Length-based powerup creation
	match length:
		8, 9, 10:
			debug_print("Creating TIME_FREEZE from " + str(length) + " match")
			return PowerupType.TIME_FREEZE
		7:
			return PowerupType.FISH
		6:
			return PowerupType.LIGHTNING
		5:
			return PowerupType.COLOR_BOMB
		4:
			if direction == MatchDirection.HORIZONTAL:
				return PowerupType.STRIPED_V  # Horizontal match creates vertical striped
			else:
				return PowerupType.STRIPED_H  # Vertical match creates horizontal striped
		_:
			return PowerupType.NONE

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
		PowerupType.BOMB:
			_trigger_bomb_effect(x, y, to_remove)
		PowerupType.STRIPED_H:
			_trigger_striped_horizontal_effect(x, y, to_remove)
		PowerupType.STRIPED_V:
			_trigger_striped_vertical_effect(x, y, to_remove)
		PowerupType.WRAPPED:
			_trigger_wrapped_effect(x, y, to_remove)
		PowerupType.COLOR_BOMB:
			_trigger_color_bomb_effect(x, y, to_remove)
		PowerupType.LIGHTNING:
			_trigger_lightning_effect(x, y, to_remove)
		PowerupType.FISH:
			_trigger_fish_effect(x, y, to_remove)
		PowerupType.TIME_FREEZE:
			_trigger_time_freeze_effect(x, y, to_remove)
	
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
	
	# Schedule second explosion (5x5) - FIXED
	var second_explosion_callable = func(): _trigger_wrapped_second_explosion(x, y)
	call_deferred("_execute_callable", second_explosion_callable)
	
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
	"""Remove all tiles of the most common color on the board with optimized missile animation"""
	debug_print("Triggering color bomb effect")
	
	# Get the color bomb world position
	var bomb_world_pos = grid_to_world_position(x, y)
	
	# Count colors and find target color
	var color_counts = {}
	for grid_x in range(grid_width):
		for grid_y in range(grid_height):
			var item = _safe_get_grid_item(grid_x, grid_y)
			if item != null:
				var base_type = _get_base_type(item.item_type)
				if not color_counts.has(base_type):
					color_counts[base_type] = 0
				color_counts[base_type] += 1
	
	var target_color = -1
	var max_count = 0
	for color_type in color_counts.keys():
		if color_counts[color_type] > max_count:
			max_count = color_counts[color_type]
			target_color = color_type
	
	if target_color >= 0:
		# Collect all target positions
		var target_positions = []
		for grid_x in range(grid_width):
			for grid_y in range(grid_height):
				var item = _safe_get_grid_item(grid_x, grid_y)
				if item != null and _get_base_type(item.item_type) == target_color:
					target_positions.append(Vector2(grid_x, grid_y))
					to_remove[Vector2(grid_x, grid_y)] = true
		
		# Launch missiles with faster timing
		_launch_missiles_async(bomb_world_pos, target_positions, target_color)
		
		
func _trigger_lightning_effect(x: int, y: int, to_remove: Dictionary):
	"""Remove tiles in diagonal directions"""
	debug_print("Triggering lightning effect at (" + str(x) + "," + str(y) + ")")
	
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

func _trigger_time_freeze_effect(x: int, y: int, to_remove: Dictionary):
	"""Activate time freeze powerup - freezes timer for 5 seconds"""
	debug_print("Triggering time freeze effect")
	_activate_time_freeze()
	
	# Small bonus: removes 3x3 area around the powerup
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				var tile_pos = Vector2(new_x, new_y)
				to_remove[tile_pos] = true

# ============================================================================
# ANIMATIONS
# ============================================================================


func _launch_missiles_async(start_pos: Vector2, target_positions: Array, color_type: int):
	"""Launch missiles asynchronously without blocking the main thread"""
	if target_positions.is_empty():
		return
	
	# Set missile timing 
	var time_to_hit = 0.15  # Reduced from 0.3 to 0.15 seconds
	
	debug_print("Launching " + str(target_positions.size()) + " missiles with optimized timing")
	
	# Launch missiles with minimal stagger for visual effect
	for i in range(target_positions.size()):
		var grid_pos = target_positions[i]
		var target_world_pos = grid_to_world_position(int(grid_pos.x), int(grid_pos.y))
		
		# Small delay for visual stagger (much smaller than before)
		var launch_delay = i * 0.01  # Reduced from 0.02 to 0.01 for faster launch
		
		# Create callable for missile launch - FIXED
		var launch_callable = func(): _create_and_fire_missile(start_pos, target_world_pos, time_to_hit, color_type)
		
		# Create missile with delay
		get_tree().create_timer(launch_delay).timeout.connect(launch_callable)



func _create_and_fire_missile(start_pos: Vector2, target_pos: Vector2, animation_time: float, color_type: int):
	"""Create and fire a single missile with proper direction and particle effects"""
	var missile = missile_scene.instantiate()
	add_child(missile)
	
	# Setup missile color
	if color_type < colors.size():
		missile.setup_missile(colors[color_type])
	else:
		missile.setup_missile(Color.WHITE)
	
	# Use missile's built-in fire method for proper direction
	missile.fire(start_pos, target_pos, animation_time)
	
	# FIXED: Connect to missile's target_reached signal with grid-relative position
	var particle_callable = func(hit_position: Vector2): _create_missile_explosion(target_pos, color_type)
	missile.target_reached.connect(particle_callable)
	
	# Clean up missile after animation using callable
	var cleanup_callable = func(): 
		if is_instance_valid(missile):
			missile.queue_free()
	
	get_tree().create_timer(animation_time + 0.2).timeout.connect(cleanup_callable)
	
func _create_missile_explosion(position: Vector2, color_type: int):
	"""Create particle explosion effect at missile impact - FIXED POSITIONING"""
	var explosion = explosion_scene.instantiate()
	add_child(explosion)  # Add to grid node instead of current_scene
	explosion.position = position  # Use local position instead of global_position
	
	# Use the appropriate color for the explosion
	var explosion_color = colors[color_type] if color_type < colors.size() else Color.WHITE
	explosion.explode(explosion_color)
	
	debug_print("Missile explosion created at grid position: " + str(position))


	
# ============================================================================
# SPECIAL GAME MECHANICS
# ============================================================================

func _check_and_activate_golden_time():
	if time_left <= 3.0 and not golden_time_active and current_game_state == GameState.PLAYING:
		golden_time_active = true
		golden_time_extensions_used = 0
		_show_golden_time_message()

func _show_golden_time_message():
	if not golden_time_active or playerMsg_label == null:
		return
	
	if golden_time_tween != null:
		golden_time_tween.kill()
	
	playerMsg_label.text = "GOLDEN TIME!"
	playerMsg_label.modulate = Color(1, 0.8, 0, 1)
	playerMsg_label.scale = Vector2(1.5, 1.5)
	
	golden_time_tween = create_tween()
	golden_time_tween.set_loops()
	golden_time_tween.tween_property(playerMsg_label, "modulate", Color(1, 1, 0.5, 1), 0.5)
	golden_time_tween.tween_property(playerMsg_label, "modulate", Color(1, 0.8, 0, 1), 0.5)

func _deactivate_golden_time():
	if not golden_time_active:
		return
	
	golden_time_active = false
	if golden_time_tween != null:
		golden_time_tween.kill()
		golden_time_tween = null
	
	if playerMsg_label != null:
		playerMsg_label.scale = Vector2(1, 1)
		playerMsg_label.modulate = Color.WHITE
		playerMsg_label.text = ""
		
		if time_freeze_active:
			_update_time_freeze_display()

func _activate_time_freeze():
	time_freeze_active = true
	time_freeze_remaining = time_freeze_duration
	debug_print("TIME FREEZE ACTIVATED for " + str(time_freeze_duration) + " seconds!")
	
	if not golden_time_active:
		_update_time_freeze_display()

func _update_time_freeze_display():
	if playerMsg_label == null or golden_time_active:
		return
	
	if time_freeze_active:
		playerMsg_label.text = "TIME FROZEN!"
		playerMsg_label.modulate = Color(0.5, 0.5, 1, 1)
		playerMsg_label.scale = Vector2(1.2, 1.2)
	else:
		playerMsg_label.text = ""
		playerMsg_label.modulate = Color.WHITE
		playerMsg_label.scale = Vector2(1, 1)

func _try_spawn_golden_time_powerup():
	"""Try to spawn a special powerup during golden time"""
	if randf() < golden_time_powerup_chance:
		# Find a random empty spot or replace a random tile
		var available_positions = []
		for x in range(grid_width):
			for y in range(grid_height):
				var item = _safe_get_grid_item(x, y)
				if item != null:
					available_positions.append(Vector2(x, y))
		
		if available_positions.size() > 0:
			var pos = available_positions[randi() % available_positions.size()]
			var old_item = _safe_get_grid_item(int(pos.x), int(pos.y))
			
			if old_item != null and is_instance_valid(old_item):
				old_item.queue_free()
			
			# Include time freeze in special powerups array
			var special_powerups = [PowerupType.COLOR_BOMB, PowerupType.TIME_FREEZE, PowerupType.LIGHTNING]
			var powerup_type = special_powerups[randi() % special_powerups.size()]
			var base_color = randi() % colors.size()
			
			var new_item = _create_item(base_color, int(pos.x), int(pos.y), powerup_type)
			if new_item != null:
				_safe_set_grid_item(int(pos.x), int(pos.y), new_item)
				debug_print("Golden Time spawned special powerup: " + str(powerup_type))
				
				
# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event):
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

func _get_grid_coords_from_position(pos: Vector2) -> Vector2:
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

func reset_item_position(item, grid_x, grid_y):
	if not item or not is_instance_valid(item):
		return
	debug_print("Resetting item position for item at (" + str(grid_x) + "," + str(grid_y) + ")")
	item.position = _get_cell_center(grid_x, grid_y)

func _get_cell_center(x, y):
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

func _handle_swap_attempt(item1, item2, x1, y1, x2, y2):
	"""Handle the swap attempt - audio handled by tile removal events"""
	
	attempt_swap(item1, item2, x1, y1, x2, y2)
	await get_tree().create_timer(0.2).timeout

	debug_print("Checking for power-up combinations...")
	
	var to_remove = {}
	var powerup_combo_triggered = _check_powerup_combination(item1, item2, to_remove)
	
	if powerup_combo_triggered:
		debug_print("Power-up combination triggered!")
		to_remove[Vector2(x1, y1)] = true
		to_remove[Vector2(x2, y2)] = true
		
		# No audio here - highlight_and_remove will handle it
		if to_remove.size() > 0:
			highlight_and_remove(to_remove.keys(), true)
			await get_tree().create_timer(0.3).timeout
			await _handle_cascade()
		return
	
	var initial_match_found = await check_for_matches()
	if initial_match_found:
		debug_print("Initial match found, starting cascade.")
		# No audio here - check_for_matches -> highlight_and_remove handles it
		await _handle_cascade()
	else:
		debug_print("No initial match found, swapping back.")
		attempt_swap(item1, item2, x2, y2, x1, y1)
		
		
func attempt_swap(item1, item2, x1, y1, x2, y2):
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
