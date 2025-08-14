extends Node2D

var grid_width = 6
var grid_height = 12
var cell_size = 90
var grid_data = []
var draggable_item_scene = preload("res://scene/DraggableItem.tscn")

var dragging = false
var drag_start_pos = Vector2()
var drag_offset = Vector2()
var dragged_item = null
var target_item = null
var start_x
var start_y

func _ready():
	grid_data.resize(grid_width)
	randomize()
	var colors = [Color(1,0,0), Color(0,1,0), Color(0,0,1)]

	for i in range(grid_width):
		grid_data[i] = []
		for j in range(grid_height):
			var item_instance = draggable_item_scene.instantiate()

			# Pick a random type, avoiding horizontal triples
			var new_type = randi() % colors.size()
			while i >= 2 and grid_data[i-1][j].item_type == new_type and grid_data[i-2][j].item_type == new_type:
				new_type = randi() % colors.size()

			item_instance.item_type = new_type

			var sprite_instance = item_instance.get_node("Sprite2D")
			sprite_instance.modulate = colors[item_instance.item_type]

			var tex_size = sprite_instance.texture.get_size()
			var scale_factor = cell_size / tex_size.x
			sprite_instance.scale = Vector2(scale_factor, scale_factor)

			item_instance.position = Vector2(
				i * cell_size + cell_size / 2,
				j * cell_size + cell_size / 2
			)

			item_instance.clicked.connect(_on_item_clicked)

			add_child(item_instance)
			grid_data[i].append(item_instance)

func _input(event):
	if event is InputEventMouseMotion and dragging:
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

	start_x = floor(drag_start_pos.x / cell_size)
	start_y = floor(drag_start_pos.y / cell_size)

func end_drag(pos):
	dragging = false
	dragged_item.z_index = 0

	var end_x = floor(pos.x / cell_size)
	var end_y = floor(pos.y / cell_size)

	if end_x >= 0 and end_x < grid_width and end_y >= 0 and end_y < grid_height:
		target_item = grid_data[end_x][end_y]
		if target_item != null and target_item != dragged_item:
			attempt_swap(dragged_item, target_item, start_x, start_y, end_x, end_y)
			check_for_matches()
		else:
			reset_item_position(dragged_item, start_x, start_y)
	else:
		reset_item_position(dragged_item, start_x, start_y)

	dragged_item = null
	target_item = null

func attempt_swap(item1, item2, x1, y1, x2, y2):
	var pos1 = Vector2(
		x1 * cell_size + cell_size / 2,
		y1 * cell_size + cell_size / 2
	)
	var pos2 = Vector2(
		x2 * cell_size + cell_size / 2,
		y2 * cell_size + cell_size / 2
	)

	grid_data[x1][y1] = item2
	grid_data[x2][y2] = item1

	create_tween().tween_property(item1, "position", pos2, 0.15)
	create_tween().tween_property(item2, "position", pos1, 0.15)

func reset_item_position(item, grid_x, grid_y):
	item.position = Vector2(
		grid_x * cell_size + cell_size / 2,
		grid_y * cell_size + cell_size / 2
	)

# -------------------------------
# MATCH DETECTION + REMOVAL LOGIC
# -------------------------------
func check_for_matches():
	var to_remove = []

	# Horizontal matches
	for y in range(grid_height):
		var match_count = 1
		for x in range(1, grid_width):
			if grid_data[x][y] != null and grid_data[x-1][y] != null and grid_data[x][y].item_type == grid_data[x-1][y].item_type:
				match_count += 1
			else:
				if match_count >= 3:
					for k in range(match_count):
						to_remove.append(Vector2(x-1-k, y))
				match_count = 1
		if match_count >= 3:
			for k in range(match_count):
				to_remove.append(Vector2(grid_width-1-k, y))

	# Vertical matches
	for x in range(grid_width):
		var match_count = 1
		for y in range(1, grid_height):
			if grid_data[x][y] != null and grid_data[x][y-1] != null and grid_data[x][y].item_type == grid_data[x][y-1].item_type:
				match_count += 1
			else:
				if match_count >= 3:
					for k in range(match_count):
						to_remove.append(Vector2(x, y-1-k))
				match_count = 1
		if match_count >= 3:
			for k in range(match_count):
				to_remove.append(Vector2(x, grid_height-1-k))

	# Remove matched items
	for pos in to_remove:
		var gx = int(pos.x)
		var gy = int(pos.y)
		if gx >= 0 and gx < grid_width and gy >= 0 and gy < grid_height:
			if grid_data[gx][gy] != null:
				grid_data[gx][gy].queue_free()
				grid_data[gx][gy] = null
