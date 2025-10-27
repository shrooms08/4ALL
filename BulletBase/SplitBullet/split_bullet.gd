extends BulletBase
class_name SplitBullet

# No need for split_bullet_scene - it shoots multiple at once
@export var bullets_per_shot: int = 3
@export var bullet_spread_angle: float = 30.0  # Total spread in degrees

func _init(): 
	max_ammo = 5  # Low ammo, but shoots 3 at once
	damage = 8.0  # Reduced damage per bullet
	knockback_force = 6.0

func on_bullet_ready() -> void:
	set_meta("display_name", "Split")
