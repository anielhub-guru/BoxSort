extends Node2D

# Signal emitted when missile reaches its target
signal target_reached(target_position)

@onready var sprite: Sprite2D = $Sprite2D
var tween: Tween

# Visual properties
var missile_color: Color = Color.WHITE

func _ready():
	# Set default missile appearance
	sprite.modulate = missile_color

func setup_missile(color: Color = Color.WHITE):
	"""Setup missile appearance - call before firing"""
	missile_color = color
	
	if sprite:
		sprite.modulate = color

func fire(start_position: Vector2, target_position: Vector2, duration: float = 1.0):
	"""Fire missile from start to target position over specified duration"""
	
	# Set starting position
	position = start_position
	
	# Calculate rotation to face target
	var direction = target_position - start_position
	rotation = direction.angle()
	
	# Stop existing tween if it exists
	if tween != null and tween.is_valid():
		tween.kill()
	
	# Create smooth movement tween with easing for homing effect
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Animate position
	tween.tween_property(self, "position", target_position, duration)
	
	# Connect completion signal
	tween.finished.connect(_on_tween_finished.bind(target_position))

func fire_with_arc(start_position: Vector2, target_position: Vector2, target_time: float, arc_height: float = 50.0):
	"""Fire missile to arrive at target_position at exactly target_time - IMPROVED VERSION"""
	
	position = start_position
	
	# Ensure minimum flight time
	var flight_duration = max(target_time, 0.3)
	
	# Calculate distance for arc height scaling
	var distance = start_position.distance_to(target_position)
	var scaled_arc_height = arc_height * min(distance / 200.0, 1.5)  # Scale arc with distance
	
	# Calculate midpoint with arc
	var midpoint = (start_position + target_position) * 0.5
	midpoint.y -= scaled_arc_height
	
	# Initial rotation towards target
	var direction = target_position - start_position
	rotation = direction.angle()
	
	# Stop existing tween if it exists
	if tween != null and tween.is_valid():
		tween.kill()
	
	tween = create_tween()
	tween.set_parallel(true)
	
	# Improved two-phase movement with better easing
	var phase1_time = flight_duration * 0.4
	var phase2_time = flight_duration * 0.6
	
	# Phase 1: Accelerate to midpoint
	tween.tween_property(self, "position", midpoint, phase1_time)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_SINE)
	
	# Phase 2: Decelerate to target (missile-like homing)
	tween.tween_property(self, "position", target_position, phase2_time)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_delay(phase1_time)
	
	# Smooth rotation that follows trajectory
	var rotation_tween = tween.tween_method(_update_rotation_to_target, 0.0, 1.0, flight_duration)
	rotation_tween.set_ease(Tween.EASE_IN_OUT)
	
	# Connect completion
	tween.finished.connect(_on_tween_finished.bind(target_position))

func _update_rotation_to_target(progress: float):
	"""Update missile rotation to follow trajectory - IMPROVED VERSION"""
	# Calculate current trajectory direction based on progress
	var start_pos = position
	var distance = start_pos.distance_to(position)
	
	# Get velocity from tween movement
	var next_pos = position + global_transform.x * 10  # Look ahead slightly
	var velocity_direction = (next_pos - position).normalized()
	
	if velocity_direction.length() > 0.1:
		var target_angle = velocity_direction.angle()
		# Smooth rotation with faster response
		rotation = lerp_angle(rotation, target_angle, 0.15)
		
		
func _on_tween_finished(target_pos: Vector2):
	"""Called when missile reaches target - create impact effects"""
	
	# Create explosion effect (simple scale burst)
	var explosion_tween = create_tween()
	explosion_tween.set_parallel(true)
	
	# Scale burst effect
	var original_scale = sprite.scale
	explosion_tween.tween_property(sprite, "scale", original_scale * 2.0, 0.15)
	explosion_tween.tween_property(sprite, "modulate", Color.TRANSPARENT, 0.15)
	
	# Screen shake (you can adjust intensity)
	_create_screen_shake(5.0, 0.2)
	
	# Emit signal after brief delay for impact
	await get_tree().create_timer(0.1).timeout
	target_reached.emit(target_pos)
	
	# Clean up after explosion animation
	await explosion_tween.finished
	queue_free()

func _create_screen_shake(intensity: float, duration: float):
	"""Create screen shake effect using UI container"""
	var hud_node = get_tree().current_scene
	if hud_node and hud_node.has_method("create_screen_shake"):
		hud_node.create_screen_shake(intensity, duration)
		print_rich("[color=gold] has_create_screen_shake [/color]")
	else:
		print("Could not find HUD node for screen shake")


# Utility function to create missile programmatically
static func create_missile(parent: Node, color: Color = Color.WHITE) -> Node2D:
	"""Static helper to create and setup a missile instance"""
	var missile_scene = preload("res://scene/missile.tscn") # Adjust path as needed
	var missile = missile_scene.instantiate()
	
	parent.add_child(missile)
	missile.setup_missile(color)
	
	return missile
