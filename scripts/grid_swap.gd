extends Node2D

var grid_width = 6
var grid_height = 12
var cell_size = 90
var grid_data = []
var draggable_item_scene = preload("res://scene/DraggableItem.tscn")

var dragging = false
var drag_start_pos = Vector2()
var drag_offset = Vector2() # new - stores mouse offset from item center
var dragged_item = null
var target_item = null

func _ready():
	grid_data.resize(grid_width)
	randomize()
	var colors = [Color(1,0,0), Color(0,1,0), Color(0,0,1)]

	for i in range(grid_width):
		grid_data[i] = []
		for j in range(grid_height):
			var item_instance = draggable_item_scene.instantiate()
			item_instance.item_type = randi() % colors.size()
			var sprite_instance = item_instance.get_node("Sprite2D")
			sprite_instance.modulate = colors[item_instance.item_type]

			var tex_size = sprite_instance.texture.get_size()
			var scale_factor = cell_size / tex_size.x
			sprite_instance.scale = Vector2(scale_factor, scale_factor)

			item_instance.position = Vector2(
				i * cell_size + cell_size / 2,
				j * cell_size + cell_size / 2
			)

			# Connect click signal from item
			item_instance.clicked.connect(_on_item_clicked)

			add_child(item_instance)
			grid_data[i].append(item_instance)

func _input(event):
	if event is InputEventMouseMotion and dragging:
		# keep mouse offset so no jumping
		dragged_item.position = to_local(event.position) + drag_offset

	elif event is InputEventMouseButton and not event.pressed and dragging:
		end_drag(to_local(event.position))

	elif event is InputEventScreenTouch and not event.pressed and dragging:
		end_drag(to_local(event.position))

func _on_item_clicked(item, click_pos: Vector2):
	start_drag(item, click_pos)

func start_drag(item, pos):
	dragging = true
	drag_start_pos = pos
	dragged_item = item
	dragged_item.z_index = 1
	# store offset so the sprite stays under cursor where clicked
	drag_offset = item.position - pos

func end_drag(pos):
	dragging = false
	dragged_item.z_index = 0

	var start_x = floor(drag_start_pos.x / cell_size)
	var start_y = floor(drag_start_pos.y / cell_size)
	var end_x = floor(pos.x / cell_size)
	var end_y = floor(pos.y / cell_size)

	# Always allow swapping
	if end_x >= 0 and end_x < grid_width and end_y >= 0 and end_y < grid_height:
		target_item = grid_data[end_x][end_y]

		if target_item != null and target_item != dragged_item:
			attempt_swap(dragged_item, target_item, start_x, start_y, end_x, end_y)
		else:
			reset_item_position(dragged_item, Vector2(start_x * cell_size, start_y * cell_size))
	else:
		reset_item_position(dragged_item, Vector2(start_x * cell_size, start_y * cell_size))

	dragged_item = null
	target_item = null

func attempt_swap(item1, item2, x1, y1, x2, y2):
	var pos1 = item1.position
	var pos2 = item2.position

	grid_data[x1][y1] = item2
	grid_data[x2][y2] = item1

	# Swap visually
	create_tween().tween_property(item1, "position", pos2, 0.2)
	create_tween().tween_property(item2, "position", pos1, 0.2)

func reset_item_position(item, grid_pos):
	item.position = Vector2(
		grid_pos.x + cell_size / 2,
		grid_pos.y + cell_size / 2
	)

func check_for_matches():
	return false
