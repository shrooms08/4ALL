extends StaticBody2D

@export var health: float = 10 # how many hits it can take
@export var break_sound: AudioStreamPlayer2D

func _ready():
	pass  # optional: preload sound, particles, etc.

func hit(damage: float):
	health -= damage
	if health <= 0:
		break_tile()

func break_tile():
	# play particles or sound if available
	#if $Particles2D:
		#$Particles2D.emitting = true
	#if break_sound:
		#break_sound.play()

	# disable collision and sprite
	$CollisionShape2D.disabled = true
	$Sprite2D.hide()

	# remove tile after short delay
	await get_tree().create_timer(0.3).timeout
	queue_free()
