extends Area2D
class_name BulletPickupBase

@export var duration: float = 0.0
@export var bullet_scene: PackedScene
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
		if body.has_method("apply_bullet_powerup"):
			body.apply_bullet_powerup(get_bullet_scene(), duration)
			on_collected()
		else:
			print("WARNING: Player doesn't have apply_bullet_powerup method!")


func on_collected() -> void:
	queue_free()
