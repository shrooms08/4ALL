extends BulletPickupBase
class_name HeavyPickup

func _ready() -> void:
	bullet_scene = preload("res://BulletBase/HeavyBullet/heavy_bullet.tscn")
	super._ready()

func setup_visual() -> void:
	modulate = Color.DARK_GRAY
