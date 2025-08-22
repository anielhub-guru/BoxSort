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
