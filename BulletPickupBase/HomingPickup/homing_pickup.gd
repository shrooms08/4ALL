extends BulletPickupBase
class_name HomingPickup

func _ready() -> void:
	bullet_scene = preload("res://BulletBase/HomingBullet/homing_bullet.tscn")
	super._ready()

func setup_visual() -> void:
	modulate = Color.MAGENTA
