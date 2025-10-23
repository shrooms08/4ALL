extends BulletBase
class_name SplitBullet

@export var split_count: int = 3
@export var split_angle_spread: float = PI / 4  # 45 degrees
var has_split: bool = false

func on_max_distance_reached() -> void:
	if not has_split:
		split_bullet()
	queue_free()

func split_bullet():
	has_split = true
	var base_angle = direction.angle()
	
	for i in range(split_count):
		var angle_offset = split_angle_spread * (i - split_count / 2.0) / split_count
		var new_bullet = BulletBase.new()
		get_parent().add_child(new_bullet)
		new_bullet.global_position = global_position
		new_bullet.setup(base_angle + angle_offset, damage * 0.7)

func get_max_distance() -> float:
	return MAX_DISTANCE * 0.5  # Split halfway
