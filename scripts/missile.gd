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
	
	# FIXED: Calculate rotation to face target properly
	var direction = target_position - start_position
	rotation = direction.angle() + PI/2  # Add PI/2 to correct sprite orientation
	
	# Stop existing tween if it exists
	if tween != null and tween.is_valid():
		tween.kill()
	
	# FIXED: Use faster easing for quick missile movement
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	
	# Animate position with faster timing
	tween.tween_property(self, "position", target_position, duration)
	
	# Connect completion signal
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
