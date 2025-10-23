extends BulletPickupBase
class_name SplitPickup

func _ready() -> void:
	bullet_scene = preload("res://BulletBase/SplitBullet/split_bullet.tscn")
	super._ready()

func setup_visual() -> void:
	modulate = Color.PURPLE
