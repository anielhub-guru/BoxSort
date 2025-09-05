extends GPUParticles2D

@onready var time_created = Time.get_ticks_msec()

func _ready():
	# Configure particle properties if needed
	emitting = false
	

func explode(explosion_color=null):
	"""Start the particle explosion effect"""
	emitting = true
	modulate = explosion_color
	restart()


func _process(delta: float) -> void:
	if Time.get_ticks_msec() - time_created > 10000:
		queue_free()
