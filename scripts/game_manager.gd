extends CanvasLayer

#signals
signal next_level_requested
signal restart_level_requested


func _on_next_level_button_pressed() -> void:
	emit_signal("next_level_requested")
	print("signal emitted: next level")
	pass # Replace with function body.


func _on_next_level_button_focus_entered() -> void:
	print("entered")
	pass # Replace with function body.


func _on_restart_button_pressed() -> void:
	emit_signal("restart_level_requested")
	print("signal emitted: restart level")
	pass # Replace with function body.


func _on_restart_button_mouse_entered() -> void:
	print("entered")
	pass # Replace with function body.



# Screen shake
var original_ui_position: Vector2
var shake_tween: Tween

func _ready():
	# Store the original position of your UI container
	var ui_container = $UI
	if ui_container:
		original_ui_position = ui_container.position

func create_screen_shake(intensity: float, duration: float):
	"""Create screen shake effect by moving the UI container"""
	var ui_container = $UI
	if ui_container == null:
		return
	
	# Stop existing shake
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
	
	shake_tween = create_tween()
	shake_tween.set_parallel(true)
	
	# Create shake pattern
	var shake_count = int(duration * 60)  # 60 shakes per second
	for i in range(shake_count):
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_tween.tween_property(ui_container, "position", original_ui_position + shake_offset, 1.0/60.0)
	
	# Return to original position
	shake_tween.tween_property(ui_container, "position", original_ui_position, 0.1)
