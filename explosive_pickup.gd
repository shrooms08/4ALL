extends BulletPickupBase
class_name ExplosivePickup

func _ready() -> void:
	bullet_scene = preload("res://BulletBase/ExplosiveBullet/explosive_bullet.tscn")
	super._ready()

func setup_visual() -> void:
	modulate = Color.ORANGE_RED
