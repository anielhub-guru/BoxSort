extends GPUParticles2D

@onready var time_created = Time.get_ticks_msec()

func _ready():
	# Configure particle properties if needed
	emitting = false
	

func explode(explosion_color: Color = Color.WHITE):
	"""Start the particle explosion effect with proper color"""
	
	# Set the color before starting emission
	modulate = explosion_color
	
	# Configure particle properties for better visibility
	emitting = true
	restart()
	
	# Auto-cleanup after explosion
	var cleanup_callable = func():
		emitting = false
		queue_free()
	
	get_tree().create_timer(2.0).timeout.connect(cleanup_callable)


func _process(delta: float) -> void:
	if Time.get_ticks_msec() - time_created > 10000:
		queue_free()
