extends Node2D
class_name PlayerWeapon

@export var default_bullet_scene: PackedScene
var current_bullet_scene: PackedScene
var powerup_timer: float = 0.0

func _ready() -> void:
	# Set base bullet as default if not assigned
	if not default_bullet_scene:
		# Use the bullet_scene from parent player if available
		var player = get_parent()
		if player and player.bullet_scene:
			default_bullet_scene = player.bullet_scene
		else:
			default_bullet_scene = preload("res://BulletBase/bullet_base.tscn")
	
	current_bullet_scene = default_bullet_scene
	
	# Register powerup function with player
	var player = get_parent()
	if player:
		# Add the method directly to the player
		player.set_script(player.get_script())
		if not player.has_method("apply_bullet_powerup"):
			# Create a method on the player that calls this weapon manager
			player.apply_bullet_powerup = func(bullet_scene: PackedScene, duration: float):
				apply_bullet_powerup(bullet_scene, duration)

func _process(delta: float) -> void:
	# Update powerup timer (if you want expiring powerups)
	if powerup_timer > 0:
		powerup_timer -= delta
		if powerup_timer <= 0:
			current_bullet_scene = default_bullet_scene
			print("Powerup expired - back to base bullets")

func apply_bullet_powerup(bullet_scene: PackedScene, duration: float):
	current_bullet_scene = bullet_scene
	
	# If duration is 0 or negative, powerup is permanent
	if duration > 0:
		powerup_timer = duration
		print("Powerup activated: ", get_current_bullet_name(), " for ", duration, " seconds")
	else:
		powerup_timer = 0
		print("Powerup activated: ", get_current_bullet_name(), " (permanent)")

func get_current_bullet_scene() -> PackedScene:
	return current_bullet_scene

func get_powerup_time_remaining() -> float:
	return max(0, powerup_timer)

func get_current_bullet_name() -> String:
	if not current_bullet_scene:
		return "Normal"
	
	var temp_bullet = current_bullet_scene.instantiate()
	var bullet_name = "Normal"
	
	if temp_bullet is ExplosiveBullet:
		bullet_name = "Explosive"
	elif temp_bullet is HomingBullet:
		bullet_name = "Homing"
	elif temp_bullet is HeavyBullet:
		bullet_name = "Heavy"
	elif temp_bullet is SplitBullet:
		bullet_name = "Split"
	
	temp_bullet.queue_free()
	return bullet_name
