extends CanvasLayer

#signals
signal next_level_requested
signal restart_level_requested

# Screen shake
@onready var shake_camera: Camera2D = $Camera2D
var original_camera_position: Vector2
var shake_tween: Tween

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


func _process(delta):
	# Simple test for screen shake
	if Input.is_action_just_pressed("ui_accept"):
		create_screen_shake(10.0, 0.5)
		print("Test shake called")



func _ready():
	
	# Store original camera position
	if shake_camera:
		original_camera_position = shake_camera.position
		print_rich("[color=green] Camera found and position stored: " + str(original_camera_position) + " [/color]")
	else:
		print_rich("[color=red] Camera NOT found in _ready [/color]")

	test_simple_shake()

func create_screen_shake(intensity: float, duration: float):
	"""Create screen shake effect by moving the camera"""
	if shake_camera == null:
		return

	# Stop existing shake
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()

	shake_tween = create_tween()
	shake_tween.set_parallel(true)

	# Create shake pattern
	var shake_count = int(duration * 60)
	for i in range(shake_count):
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_tween.tween_property(shake_camera, "position", original_camera_position + shake_offset, 1.0/60.0)

	# Return to original position
	shake_tween.tween_property(shake_camera, "position", original_camera_position, 0.1)


# Alternative simpler version for testing
func test_simple_shake():
	"""Simple test shake to verify it works"""
	if shake_camera == null:
		print_rich("[color=red] Simple test: Camera is NULL [/color]")
		return

	print_rich("[color=green] Simple test: Moving Camera [/color]")
	var test_tween = create_tween()
	test_tween.tween_property(shake_camera, "position", shake_camera.position + Vector2(50, 0), 0.2)
	test_tween.tween_property(shake_camera, "position", shake_camera.position, 0.2)
