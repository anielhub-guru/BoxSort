extends Node2D

# Game board and item properties
var grid_width = 6
var grid_height = 6
var cell_size = 90
var shelf_gap_x = 10  # You can now adjust the horizontal gap between tiles
var shelf_gap_y = 15  # You can now adjust the vertical gap between tiles
var use_shelf_gaps = false  # Set to 'true' for the old shelf gap, 'false' for a uniform gap
var padding = 60 	# Define the padding amount
# Game state and data
var grid_data = []
var draggable_item_scene = preload("res://scene/DraggableItem.tscn")
var colors = [
	Color8(77, 255, 255),    # Cyan Aqua
	Color8(255, 179, 77),    # Warm Orange
	#Color8(255, 77, 179),    # Magenta Pink
	#Color8(77, 125, 255),    # Indigo Blue
	#Color8(128, 149, 255),  # Soft Violet Blue
	#Color8(82, 224, 149),    # Mint Green
	#Color8(182, 47, 69),    # Reddish Rose
	#Color8(255, 202, 125),  # Peach Gold
	#Color8(214, 109, 129),  # Muted Rose
	Color8(255, 186, 161)    # Pastel Coral
]

var score = 0

# Drag and drop variables
var dragging = false
var drag_start_pos = Vector2()
var drag_offset = Vector2()
var dragged_item: Node2D = null
var target_item: Node2D = null
var start_x = 0
var start_y = 0

# --- Timer variables ---
var time_limit = 10.0  # Time limit in seconds
var time_left = 0.0
var is_game_over = false
# --- End Timer variables ---

# References to UI elements
var time_label: Label
var playerMsg_label: Label
@export var bonus_time_per_match: float = 0.5 # Added an exportable variable to control the bonus time
var playerMsg_initial_position: Vector2

func _ready():
	randomize()

	# Calculate the total width and height of the grid
	var grid_total_width = (grid_width * cell_size) + ((grid_width - 1) * shelf_gap_x)
	var grid_total_height = (grid_height * cell_size) + ((grid_height - 1) * shelf_gap_y)

	# Offset the Node2D's position by half of the grid's total size.
	# This makes the grid build outwards from the center of this Node2D.
	position = Vector2(-grid_total_width / 2, -grid_total_height / 2)

	# --- BORDER & BACKGROUND SETUP ---
	# The Panel node should be the first child and the Line2D the second child
	# of this Node2D in the scene tree.
	var background_panel = get_node("Panel")
	if background_panel != null:

		# Set the size to be the grid size plus the padding
		background_panel.size = Vector2(grid_total_width + padding, grid_total_height + padding)
		# Offset the position by half of the padding to center the background
		background_panel.position = Vector2(-padding / 2, -padding / 2)
		
		# Get the StyleBoxFlat resource from the Panel
		var stylebox_panel = background_panel.get_theme_stylebox("panel")
		
		# Check if the resource is a StyleBoxFlat and set the border properties
		if stylebox_panel is StyleBoxFlat:
			stylebox_panel.border_width_top = 10
			stylebox_panel.border_width_bottom = 10
			stylebox_panel.border_width_left = 10
			stylebox_panel.border_width_right = 10
			stylebox_panel.border_color = Color("#c8a13a")
	
	var border_node = get_node("Line2D")
	if border_node != null:
		# The Line2D border now wraps around the Panel to include the padding
		border_node.clear_points() # Clears any existing points
		border_node.add_point(background_panel.position) # Top-left
		border_node.add_point(background_panel.position + Vector2(background_panel.size.x, 0)) # Top-right
		border_node.add_point(background_panel.position + background_panel.size) # Bottom-right
		border_node.add_point(background_panel.position + Vector2(0, background_panel.size.y)) # Bottom-left
		border_node.add_point(background_panel.position) # Connect back to the start
		border_node.default_color = Color("#000000") # Your border color
		border_node.width = 5 # Adjust the width
	# --- END BORDER & BACKGROUND SETUP ---

	_generate_grid()
	time_left = time_limit  # Initialize the timer

	# --- FIX: Correcting the relative path ---
	# The path needs to go up the scene tree from your script's Node2D.
	# The number of ".." depends on your specific scene tree.
	# A common path is three levels up to the root, then down to the UI.
	time_label = get_node("../../../UI/VBoxContainer/Timer")
	playerMsg_label = get_node("../../../UI/VBoxContainer/playerMsg")
	
	if playerMsg_label != null:
		playerMsg_label.hide()
		playerMsg_initial_position = playerMsg_label.position
	# --- END FIX ---

func _process(delta):
	# Add a null check to prevent errors if the label isn't assigned
	if time_label != null:
		if not is_game_over:
			time_left -= delta
			if time_left <= 0:
				time_left = 0
				game_over()
			time_label.text = "Time: " + str(int(time_left)) +"\nScore: " + str(score)
		else:
			game_over()
			
		
func _generate_grid():
	grid_data.resize(grid_width)
	for x in range(grid_width):
		grid_data[x] = []
		for y in range(grid_height):
			var item_type = _get_random_item_type(x, y)
			var item_instance = _create_item(item_type, x, y)
			grid_data[x].append(item_instance)

# This function checks for both horizontal and vertical matches
# to prevent the game from starting with pre-existing matches.
func _get_random_item_type(x, y):
	var possible_types = range(colors.size())
	# Check for horizontal match
	if x >= 2:
		var t1 = grid_data[x-1][y].item_type
		var t2 = grid_data[x-2][y].item_type
		if t1 == t2:
			if possible_types.has(t1):
				possible_types.erase(t1)
	# Check for vertical match
	if y >= 2:
		var t1 = grid_data[x][y-1].item_type
		var t2 = grid_data[x][y-2].item_type
		if t1 == t2:
			if possible_types.has(t1):
				possible_types.erase(t1)
	return possible_types[randi() % possible_types.size()]

# UPDATED: The position now uses the new shelf_gap variables for a consistent gap
func _create_item(item_type, x, y):
	var item_instance = draggable_item_scene.instantiate()
	item_instance.item_type = item_type
	var sprite_instance = item_instance.get_node("Sprite2D")
	sprite_instance.modulate = colors[item_type]
	var tex_size = sprite_instance.texture.get_size()
	var scale_factor = cell_size / tex_size.x
	sprite_instance.scale = Vector2(scale_factor, scale_factor)
	
	# This is the key change: Position is now relative to this Node2D's origin (0,0)
	var extra_offset_x = 0.0
	var extra_offset_y = 0.0
	if use_shelf_gaps:
		extra_offset_x = (x / 3) * shelf_gap_x
		extra_offset_y = (y / 1) * shelf_gap_y
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
	if event is InputEventMouseMotion and dragging:
		if dragged_item:
			# Use to_local to get the mouse position relative to this Node2D
			dragged_item.position = to_local(event.position) + drag_offset
	elif event is InputEventMouseButton and not event.pressed and dragging:
		# Use to_local to get the mouse position relative to this Node2D
		end_drag(to_local(event.position))
	elif event is InputEventScreenTouch and not event.pressed and dragging:
		# Use to_local to get the touch position relative to this Node2D
		end_drag(to_local(event.position))

func _on_item_clicked(item, click_pos: Vector2):
	start_drag(item, click_pos)

func start_drag(item, pos):
	dragging = true
	dragged_item = item
	drag_start_pos = item.position
	dragged_item.z_index = 1
	# Use to_local to calculate the offset correctly
	drag_offset = item.position - to_local(pos)
	var grid_coords = _get_grid_coords_from_position(dragged_item.position)
	start_x = grid_coords.x
	start_y = grid_coords.y

func end_drag(pos):
	dragging = false
	if not dragged_item:
		return

	dragged_item.z_index = 0
	var end_coords = _get_grid_coords_from_position(pos)

	if _is_inside_grid(end_coords.x, end_coords.y):
		target_item = grid_data[end_coords.x][end_coords.y]
		if target_item != null and target_item != dragged_item:
			# Check if the swap is to an adjacent tile, including diagonal
			var dx = abs(start_x - end_coords.x)
			var dy = abs(start_y - end_coords.y)
			if (dx == 1 and dy == 0) or (dx == 0 and dy == 1) or (dx == 1 and dy == 1):
				attempt_swap(dragged_item, target_item, start_x, start_y, end_coords.x, end_coords.y)
				await get_tree().create_timer(0.2).timeout
				
				# Check for matches after the swap
				if check_for_matches():
					# Match found, do nothing, the game will handle the rest
					pass
				else:
					# No match found, swap the tiles back
					attempt_swap(dragged_item, target_item, end_coords.x, end_coords.y, start_x, start_y)
			else:
				# If not adjacent, reset position
				reset_item_position(dragged_item, start_x, start_y)
		else:
			reset_item_position(dragged_item, start_x, start_y)
	else:
		reset_item_position(dragged_item, start_x, start_y)

	dragged_item = null
	target_item = null

# The calculation now uses a more reliable method
# by finding the closest grid cell center to the drop position.
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

func _is_inside_grid(x, y):
	return x >= 0 and x < grid_width and y >= 0 and y < grid_height

func attempt_swap(item1, item2, x1, y1, x2, y2):
	var pos1 = _get_cell_center(x1, y1)
	var pos2 = _get_cell_center(x2, y2)

	grid_data[x1][y1] = item2
	grid_data[x2][y2] = item1

	create_tween().tween_property(item1, "position", pos2, 0.15)
	create_tween().tween_property(item2, "position", pos1, 0.15)

func reset_item_position(item, grid_x, grid_y):
	item.position = _get_cell_center(grid_x, grid_y)

# UPDATED: The position calculation now uses a consistent gap
func _get_cell_center(x, y):
	var extra_offset_x = 0.0
	var extra_offset_y = 0.0
	# Use the 'use_shelf_gaps' variable to determine the offset
	if use_shelf_gaps:
		extra_offset_x = (x / 3) * shelf_gap_x
		extra_offset_y = (y / 1) * shelf_gap_y
	else:
		extra_offset_x = x * shelf_gap_x
		extra_offset_y = y * shelf_gap_y
		
	return Vector2(
		x * cell_size + cell_size / 2 + extra_offset_x,
		y * cell_size + cell_size / 2 + extra_offset_y
	)

# -------------------------------
# Match Detection and Gameplay Logic
# -------------------------------

func check_for_matches() -> bool:
	var to_remove = {}

	# Check for horizontal matches of 3 or more
	for y in range(grid_height):
		var current_run_length = 1
		for x in range(grid_width):
			if x > 0 and grid_data[x][y] and grid_data[x][y].item_type == grid_data[x-1][y].item_type:
				current_run_length += 1
			else:
				if current_run_length >= 3:
					for i in range(current_run_length):
						to_remove[Vector2(x - 1 - i, y)] = true
				current_run_length = 1
		# Check at the end of the row
		if current_run_length >= 3:
			for i in range(current_run_length):
				to_remove[Vector2(grid_width - 1 - i, y)] = true

	# Check for vertical matches of 3 or more
	for x in range(grid_width):
		var current_run_length = 1
		for y in range(grid_height):
			if y > 0 and grid_data[x][y] and grid_data[x][y].item_type == grid_data[x][y-1].item_type:
				current_run_length += 1
			else:
				if current_run_length >= 3:
					for i in range(current_run_length):
						to_remove[Vector2(x, y - 1 - i)] = true
				current_run_length = 1
		# Check at the end of the column
		if current_run_length >= 3:
			for i in range(current_run_length):
				to_remove[Vector2(x, grid_height - 1 - i)] = true

	if to_remove.size() > 0:
		highlight_and_remove(to_remove.keys())
		return true
	return false

func highlight_and_remove(matched_positions):
	add_score(matched_positions.size())
	
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
	
	apply_gravity()

func add_score(matched_count):
	if is_game_over:
		return
		
	score += matched_count * 10
	
	# UPDATED: Calculate bonus time using the new variable
	var time_added = matched_count * bonus_time_per_match
	time_left += time_added
	
	# Improved pop-up animation for the player message
	if playerMsg_label != null:
		# Reset position, scale, and modulate to initial state
		playerMsg_label.position = playerMsg_initial_position
		playerMsg_label.scale = Vector2(1, 1)
		playerMsg_label.modulate = Color(1, 1, 1, 1)
		playerMsg_label.text = "+" + str(time_added) + "s"
		playerMsg_label.show()
		
		# Create a tween for the fancy animation
		var tween = create_tween()
		
		# Move the label up, scale it down, and fade it out simultaneously
		tween.tween_property(playerMsg_label, "position", playerMsg_initial_position - Vector2(0, 30), 1.0)
		tween.tween_property(playerMsg_label, "scale", Vector2(0.5, 0.5), 1.0)
		tween.tween_property(playerMsg_label, "modulate", Color(1, 1, 1, 0), 1.0).set_delay(0.25)
		
		# After the tween is finished, hide the label
		tween.tween_callback(Callable(playerMsg_label, "hide"))
		
func game_over():
	var final_score = "Game Over! \nScore: " + str(score)
	if not is_game_over:
		is_game_over = true
		print(final_score)
		# Add a null check before accessing the label
		if time_label != null:
			time_label.text = final_score
		# You can add code here to show a game over screen,
	else:
		time_label.text = final_score
		
func apply_gravity():
	var tween = create_tween().set_parallel(true)
	var should_refill = false
	
	for x in range(grid_width):
		for y in range(grid_height - 1, 0, -1):
			if grid_data[x][y] == null:
				for y_above in range(y - 1, -1, -1):
					if grid_data[x][y_above] != null:
						var item_to_move = grid_data[x][y_above]
						grid_data[x][y] = item_to_move
						grid_data[x][y_above] = null
						
						var new_pos = _get_cell_center(x, y)
						tween.tween_property(item_to_move, "position", new_pos, 0.2)
						should_refill = true
						break
	
	if should_refill:
		await tween.finished
	
	refill_grid()

func refill_grid():
	var tween = create_tween().set_parallel(true)
	var new_items_created = false
	
	for x in range(grid_width):
		for y in range(grid_height):
			if grid_data[x][y] == null:
				var item_type = randi() % colors.size()
				var item_instance = _create_item(item_type, x, y)
				grid_data[x][y] = item_instance
				
				var start_pos = _get_cell_center(x, -1)
				item_instance.position = start_pos
				
				var end_pos = _get_cell_center(x, y)
				tween.tween_property(item_instance, "position", end_pos, 0.2)
				new_items_created = true
	
	if new_items_created:
		await tween.finished
	
	check_for_matches()
