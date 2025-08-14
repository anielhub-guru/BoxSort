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



##############TOTESTDRAGING


#extends Node2D
#
## Simple draggable item for testing
#var selected = false
#var drag_start_pos = Vector2()
#var item_type: int = 0  # default value
#
#
#func _process(delta: float) -> void:
	#if selected:
		#follow_mouse()
#
#func follow_mouse():
	#position = get_global_mouse_position() + drag_start_pos
#
#func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	#if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		#if event.pressed:
			## Mouse button pressed on this node
			#print("Clicked")
			#start_drag(event.position)
		#else:
			## Mouse button released
			#print("Released")
			#end_drag()
#
	#elif event is InputEventScreenTouch and event.index == 0:
		#if event.pressed:
			#start_drag(event.position)
		#else:
			#end_drag()
#
	#elif event is InputEventMouseMotion and selected:
		## Update position while dragging
		#position = event.position - drag_start_pos
#
#
#
#func start_drag(pos: Vector2) -> void:
	#selected = true
	##drag_start_pos = pos
	#z_index = 1  # bring to front
#
#func end_drag() -> void:
	#selected = false
	#z_index = 0
#
