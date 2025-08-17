extends Control

@onready var play_label = $MarginContainer/playLabel

func _ready() -> void:
	play_label.mouse_filter = Control.MOUSE_FILTER_STOP  # IMPORTANT!
	play_label.pivot_offset = play_label.size / 2
	play_label.gui_input.connect(_on_play_label_gui_input)
	play_label.mouse_entered.connect(_on_play_label_mouse_entered)
	play_label.mouse_exited.connect(_on_play_label_mouse_exited)
	

func _on_play_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("good")
		get_tree().change_scene_to_file("res://scene/game.tscn")


func _on_play_label_mouse_entered() -> void:
	_tween_scale(Vector2(1.2, 1.2))  # 20% bigger

func _on_play_label_mouse_exited() -> void:
	_tween_scale(Vector2(1, 1))  # Back to normal

func _tween_scale(target_scale: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(play_label, "scale", target_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

#extends Control
#
#@onready var play_label = $MarginContainer/playLabel# adjust if nested deeper
#
#func _ready() -> void:
	## Connect signals for hover and click
	#play_label.mouse_entered.connect(_on_play_label_mouse_entered)
	#play_label.mouse_exited.connect(_on_play_label_mouse_exited)
	#play_label.gui_input.connect(_on_play_label_gui_input)
#
#func _on_play_label_mouse_entered() -> void:
	#play_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2)) # Gold-ish
	#play_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
#
#func _on_play_label_mouse_exited() -> void:
	#play_label.add_theme_color_override("font_color", Color(1, 1, 1)) # White
#
#func _on_play_label_gui_input(event: InputEvent) -> void:
	#if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		## Optional click flash effect
		#play_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
		#await get_tree().create_timer(0.1).timeout
		#get_tree().change_scene_to_file("res://grid.tscn")
