extends RefCounted
class_name PowerupEffectsw

# External dependencies injected/referenced by the caller
var grid_width
var grid_height
var draggable_item_scene
var colors
var powerup_textures
var _safe_get_grid_item
var _is_inside_grid
var highlight_and_remove
var launch_synchronized_missiles
var grid_to_world_position
var _get_base_type
var randi_range

var create_tween
var get_tree
var _processing_bomb_effects = false

# --- Powerup effect functions moved from grid.gd ---

func _trigger_powerup_effect(pos: Vector2, to_remove: Dictionary):
	if _processing_bomb_effects:
		return
	
	_processing_bomb_effects = true
	
	var x = int(pos.x)
	var y = int(pos.y)
	var item = _safe_get_grid_item(x, y)
	
	if item == null:
		_processing_bomb_effects = false
		return
	
	var powerup_type = item.item_type
	powerup_type = powerup_type - (_get_base_type(powerup_type)) # get the powerup base

	match powerup_type:
		100: # POWERUP_BOMB_TYPE
			_trigger_bomb_effect(x, y, to_remove)
		200: # POWERUP_STRIPED_H_TYPE
			_trigger_striped_horizontal_effect(x, y, to_remove)
		300: # POWERUP_STRIPED_V_TYPE
			_trigger_striped_vertical_effect(x, y, to_remove)
		400: # POWERUP_WRAPPED_TYPE
			_trigger_wrapped_effect(x, y, to_remove)
		500: # POWERUP_COLOR_BOMB_TYPE
			_trigger_color_bomb_effect(x, y, to_remove)
		600: # POWERUP_LIGHTNING_TYPE
			_trigger_lightning_effect(x, y, to_remove)
		700: # POWERUP_FISH_TYPE
			_trigger_fish_effect(x, y, to_remove)
		800: # POWERUP_TIME_FREEZE_TYPE
			_trigger_time_freeze_effect(x, y, to_remove)
		
	_processing_bomb_effects = false

func _trigger_bomb_effect(x: int, y: int, to_remove: Dictionary):
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				to_remove[Vector2(new_x, new_y)] = true

func _trigger_striped_horizontal_effect(x: int, y: int, to_remove: Dictionary):
	for i in range(grid_width):
		if _is_inside_grid(i, y):
			to_remove[Vector2(i, y)] = true

func _trigger_striped_vertical_effect(x: int, y: int, to_remove: Dictionary):
	for i in range(grid_height):
		if _is_inside_grid(x, i):
			to_remove[Vector2(x, i)] = true

func _trigger_wrapped_effect(x: int, y: int, to_remove: Dictionary):
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				to_remove[Vector2(new_x, new_y)] = true
	call_deferred("_trigger_wrapped_second_explosion", x, y)

func _trigger_wrapped_second_explosion(x: int, y: int):
	await get_tree().create_timer(0.3).timeout
	var second_to_remove = {}
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				second_to_remove[Vector2(new_x, new_y)] = true
	if second_to_remove.size() > 0:
		highlight_and_remove(second_to_remove.keys(), true)

func _trigger_color_bomb_effect(x: int, y: int, to_remove: Dictionary):
	var bomb_world_pos = grid_to_world_position(x, y)
	var color_counts = {}
	for grid_x in range(grid_width):
		for grid_y in range(grid_height):
			var item = _safe_get_grid_item(grid_x, grid_y)
			if item != null:
				var base_type = _get_base_type(item.item_type)
				color_counts[base_type] = color_counts.get(base_type, 0) + 1
	
	var target_color = -1
	var max_count = 0
	for color_type in color_counts.keys():
		if color_counts[color_type] > max_count:
			max_count = color_counts[color_type]
			target_color = color_type
	
	if target_color >= 0:
		var target_positions = []
		for grid_x in range(grid_width):
			for grid_y in range(grid_height):
				var item = _safe_get_grid_item(grid_x, grid_y)
				if item != null and _get_base_type(item.item_type) == target_color:
					target_positions.append(Vector2(grid_x, grid_y))
		
		var missile_flight_time = 0.5
		var missile_task = await launch_synchronized_missiles(bomb_world_pos, target_positions, target_color, missile_flight_time)
		var removal_task = await highlight_and_remove(target_positions, true, missile_flight_time, target_color)
		await missile_task
		await removal_task
		for grid_pos in target_positions:
			to_remove[grid_pos] = true

func _trigger_time_freeze_effect(x: int, y: int, to_remove: Dictionary):
	if _activate_time_freeze != null:
		_activate_time_freeze.call()
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				to_remove[Vector2(new_x, new_y)] = true

# Placeholder to be set by caller
var _activate_time_freeze: Callable

func _trigger_lightning_effect(x: int, y: int, to_remove: Dictionary):
	var directions = [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]
	for direction in directions:
		var current_x = x
		var current_y = y
		while _is_inside_grid(current_x, current_y):
			to_remove[Vector2(current_x, current_y)] = true
			current_x += direction.x
			current_y += direction.y

func _trigger_fish_effect(x: int, y: int, to_remove: Dictionary):
	var available_positions = []
	for grid_x in range(grid_width):
		for grid_y in range(grid_height):
			var item = _safe_get_grid_item(grid_x, grid_y)
			if item != null:
				available_positions.append(Vector2(grid_x, grid_y))
	available_positions.shuffle()
	var target_count = min(randi_range(3, 5), available_positions.size())
	for i in range(target_count):
		to_remove[available_positions[i]] = true

func _trigger_clear_board_effect(to_remove: Dictionary):
	for x in range(grid_width):
		for y in range(grid_height):
			to_remove[Vector2(x, y)] = true

func _trigger_star_constellation_effect(to_remove: Dictionary):
	var corners = [Vector2(0, 0), Vector2(grid_width-1, 0), Vector2(0, grid_height-1), Vector2(grid_width-1, grid_height-1)]
	for corner in corners:
		to_remove[corner] = true
	var center_x = grid_width / 2
	var center_y = grid_height / 2
	for x in range(grid_width):
		to_remove[Vector2(x, center_y)] = true
	for y in range(grid_height):
		to_remove[Vector2(center_x, y)] = true

func _trigger_double_wrapped_effect(pos: Vector2, to_remove: Dictionary):
	var x = int(pos.x)
	var y = int(pos.y)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				to_remove[Vector2(new_x, new_y)] = true
	call_deferred("_trigger_delayed_explosion", x, y, 3)

func _trigger_delayed_explosion(x: int, y: int, radius: int):
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

func _trigger_striped_wrapped_combo(pos: Vector2, to_remove: Dictionary):
	var x = int(pos.x)
	var y = int(pos.y)
	for i in range(grid_width):
		to_remove[Vector2(i, y)] = true
	for i in range(grid_height):
		to_remove[Vector2(x, i)] = true
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var new_x = x + dx
			var new_y = y + dy
			if _is_inside_grid(new_x, new_y):
				to_remove[Vector2(new_x, new_y)] = true

func _trigger_color_to_striped_effect(to_remove: Dictionary):
	var target_color = _find_most_common_color()
	if target_color >= 0:
		for x in range(grid_width):
			for y in range(grid_height):
				var item = _safe_get_grid_item(x, y)
				if item != null and _get_base_type(item.item_type) == target_color:
					_trigger_striped_horizontal_effect(x, y, to_remove)

func _trigger_color_to_wrapped_effect(to_remove: Dictionary):
	var available_positions = []
	for x in range(grid_width):
		for y in range(grid_height):
			available_positions.append(Vector2(x, y))
	available_positions.shuffle()
	for i in range(min(3, available_positions.size())):
		_trigger_wrapped_effect(int(available_positions[i].x), int(available_positions[i].y), to_remove)

func _trigger_color_to_bomb_effect(to_remove: Dictionary):
	var target_color = _find_most_common_color()
	if target_color >= 0:
		for x in range(grid_width):
			for y in range(grid_height):
				var item = _safe_get_grid_item(x, y)
				if item != null and _get_base_type(item.item_type) == target_color:
					_trigger_bomb_effect(x, y, to_remove)

func _trigger_fish_swarm_effect(to_remove: Dictionary):
	var available_positions = []
	for x in range(grid_width):
		for y in range(grid_height):
			available_positions.append(Vector2(x, y))
	available_positions.shuffle()
	var target_count = min(randi_range(8, 12), available_positions.size())
	for i in range(target_count):
		to_remove[available_positions[i]] = true

func _find_most_common_color() -> int:
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
	return target_color
