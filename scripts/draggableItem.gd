extends Node2D

signal clicked(item: Node2D, click_pos: Vector2)

# Properties to hold the item's type and grid coordinates
var item_type: int = -1
var grid_x: int = -1
var grid_y: int = -1

func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self, get_global_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		clicked.emit(self, get_global_mouse_position())

# Functions to get the item's grid coordinates
func get_grid_x():
	return grid_x

func get_grid_y():
	return grid_y
