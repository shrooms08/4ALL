extends Area2D
class_name BulletPickupBase

@export var duration: float = 0.0
@export var bullet_scene: PackedScene
@export var health_increase: int = 1
@export var ammo_increase: int = 2

@onready var sprite = $Sprite2D
@onready var animation_player = $AnimationPlayer

func _ready() -> void:
	# Enable monitoring
	monitoring = true
	monitorable = false
	
	# Ensure we're scanning the right layer
	collision_layer = 5  # We are on layer 5
	collision_mask = 2   # We detect layer 2 (player)
	
	setup_visual()
	
	print("Pickup ready: ", name)
	print("  Layer: ", collision_layer, " (binary: ", String.num_int64(collision_layer, 2), ")")
	print("  Mask: ", collision_mask, " (binary: ", String.num_int64(collision_mask, 2), ")")
	print("  Monitoring: ", monitoring)

func setup_visual() -> void:
	pass

func get_bullet_scene() -> PackedScene:
	return bullet_scene

func _on_body_entered(body: Node2D) -> void:
	print("Body entered pickup: ", body.name, " | Groups: ", body.get_groups())
	
	if body.is_in_group("player"):
		print("Player detected! Applying powerup...")
		
		# Randomly choose between health or ammo
		var random_choice = randi() % 2  # Returns 0 or 1
		
		if random_choice == 0:
			# Give health (uses existing heal method)
			if body.has_method("heal"):
				body.heal(health_increase)
				print("Gave +", health_increase, " health")
			else:
				print("WARNING: Player doesn't have heal method!")
		else:
			# Give ammo (directly modify current_ammo)
			if "current_ammo" in body:
				# Cap ammo at MAX_AMMO
				var max_ammo = body.MAX_AMMO if "MAX_AMMO" in body else 8
				body.current_ammo = min(body.current_ammo + ammo_increase, max_ammo)
				print("Gave +", ammo_increase, " ammo (now: ", body.current_ammo, "/", max_ammo, ")")
			else:
				print("WARNING: Player doesn't have current_ammo property!")
		
		# Still apply bullet powerup if it exists
		if body.has_method("apply_bullet_powerup"):
			body.apply_bullet_powerup(get_bullet_scene(), duration)
		
		on_collected()

func on_collected() -> void:
	queue_free()
