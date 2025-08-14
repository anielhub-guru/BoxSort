extends Node2D

var grid_width = 6
var grid_height = 12
var cell_size = 90
var shelf_gap_x = 10
var shelf_gap_y = 15

var grid_data = []
var draggable_item_scene = preload("res://scene/DraggableItem.tscn")
var colors = [Color.RED, Color.BLUE, Color.GREEN, Color.ORANGE]

var dragging = false
var drag_start_pos = Vector2()
var drag_offset = Vector2()
var dragged_item: Node2D = null
var target_item: Node2D = null
var start_x = 0
var start_y = 0

func _ready():
	randomize()
	_generate_grid()

func _generate_grid():
	grid_data.resize(grid_width)
	for x in range(grid_width):
		grid_data[x] = []
		for y in range(grid_height):
			var item_type = _get_random_item_type(x, y)
			var item_instance = _create_item(item_type, x, y)
			grid_data[x].append(item_instance)

func _get_random_item_type(x, y):
	var possible_types = range(colors.size())
	if x >= 2:
		var t1 = grid_data[x-1][y].item_type
		var t2 = grid_data[x-2][y].item_type
		if t1 == t2:
			possible_types.erase(t1)
	return possible_types[randi() % possible_types.size()]

func _create_item(item_type, x, y):
	var item_instance = draggable_item_scene.instantiate()
	item_instance.item_type = item_type

	var sprite_instance = item_instance.get_node("Sprite2D")
	sprite_instance.modulate = colors[item_type]
	var tex_size = sprite_instance.texture.get_size()
	var scale_factor = cell_size / tex_size.x
	sprite_instance.scale = Vector2(scale_factor, scale_factor)

	var extra_offset_x = int(x / 3) * shelf_gap_x
	var extra_offset_y = int(y / 1) * shelf_gap_y
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
			dragged_item.position = to_local(event.position) + drag_offset
	elif event is InputEventMouseButton and not event.pressed and dragging:
		end_drag(to_local(event.position))
	elif event is InputEventScreenTouch and not event.pressed and dragging:
		end_drag(to_local(event.position))

func _on_item_clicked(item, click_pos: Vector2):
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

func end_drag(pos):
	dragging = false
	if not dragged_item:
		return

	dragged_item.z_index = 0
	var end_coords = _get_grid_coords_from_position(pos)

	if _is_inside_grid(end_coords.x, end_coords.y):
		target_item = grid_data[end_coords.x][end_coords.y]
		if target_item != null and target_item != dragged_item:
			attempt_swap(dragged_item, target_item, start_x, start_y, end_coords.x, end_coords.y)
			await get_tree().create_timer(0.2).timeout
			
			if check_for_matches():
				pass
			else:
				attempt_swap(dragged_item, target_item, end_coords.x, end_coords.y, start_x, start_y)
		else:
			reset_item_position(dragged_item, start_x, start_y)
	else:
		reset_item_position(dragged_item, start_x, start_y)

	dragged_item = null
	target_item = null

func _get_grid_coords_from_position(pos: Vector2) -> Vector2:
	var x = int((pos.x - (int(pos.x / (cell_size * 3)) * shelf_gap_x)) / cell_size)
	var y = int((pos.y - (int(pos.y / cell_size) * shelf_gap_y)) / cell_size)
	return Vector2(x, y)

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

func _get_cell_center(x, y):
	var extra_offset_x = int(x / 3) * shelf_gap_x
	var extra_offset_y = int(y / 1) * shelf_gap_y
	return Vector2(
		x * cell_size + cell_size / 2 + extra_offset_x,
		y * cell_size + cell_size / 2 + extra_offset_y
	)

## Match Detection and Removal Logic

func check_for_matches() -> bool:
	var to_remove = {}

	for y in range(grid_height):
		for cell_x in range(grid_width / 3):  # Loop through each cell
			var start_x = cell_x * 3  # The starting x-index for this cell

			for x in range(start_x, start_x + 1): # Check for a set of three within the cell
				var item1 = grid_data[x][y]
				var item2 = grid_data[x+1][y]
				var item3 = grid_data[x+2][y]

				if item1 and item2 and item3 and item1.item_type == item2.item_type and item2.item_type == item3.item_type:
					to_remove[Vector2(x, y)] = true
					to_remove[Vector2(x+1, y)] = true
					to_remove[Vector2(x+2, y)] = true

	if to_remove.size() > 0:
		highlight_and_remove(to_remove.keys())
		return true
	return false

func highlight_and_remove(matched_positions):
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
