extends Node2D

signal clicked(item: Node2D, click_pos: Vector2)

var drag_offset = Vector2()
var item_type: int = 0

func _ready():
	$Area2D.input_event.connect(_on_area_2d_input_event)

func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		drag_offset = position - event.position
		emit_signal("clicked", self, event.position)

	elif event is InputEventScreenTouch and event.index == 0 and event.pressed:
		drag_offset = position - event.position
		emit_signal("clicked", self, event.position)

func follow_mouse(pos: Vector2) -> void:
	position = pos + drag_offset
