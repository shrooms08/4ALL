extends Area2D
class_name BulletBase

const SPEED = 800
const LIFETIME = 2.0
const MAX_DISTANCE = 200

@export var damage: float = 10.0
@export var knockback_force: float = 5.0
@export var max_ammo: int = 8

var direction = Vector2.DOWN
var velocity = Vector2.ZERO
var start_position = Vector2.ZERO
var distance_traveled = 0.0
var has_been_destroyed = false

func _ready() -> void:
	rotation = direction.angle()
	start_position = global_position
	on_bullet_ready()
	
	await get_tree().create_timer(LIFETIME).timeout
	if is_instance_valid(self):
		on_lifetime_expired()

func setup(angle: float, bullet_damage: float = 10.0):
	direction = Vector2(cos(angle), sin(angle)).normalized()
	velocity = direction * get_bullet_speed()
	rotation = angle
	damage = bullet_damage
	on_setup_complete()

func on_bullet_ready() -> void:
	pass

func on_lifetime_expired() -> void:
	queue_free()

func on_setup_complete() -> void:
	pass

func get_bullet_speed() -> float:
	return SPEED

func get_max_distance() -> float:
	return MAX_DISTANCE

func update_bullet_physics(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if has_been_destroyed:
		return
	
	update_bullet_physics(delta)
	
	var movement = velocity * delta
	var new_position = global_position + movement
	
	check_tiles_in_path(global_position, new_position)
	
	global_position = new_position
	distance_traveled += movement.length()
	
	if distance_traveled >= get_max_distance():
		on_max_distance_reached()

func on_max_distance_reached() -> void:
	queue_free()

func check_tiles_in_path(from: Vector2, to: Vector2):
	var tilemap = get_tree().get_first_node_in_group("breakable_tiles")
	if not tilemap:
		return
	
	var steps = ceil((to - from).length()/8.0)
	for i in range(int(steps) + 1):
		var t = float(i)/max(steps, 1)
		var check_pos = from.lerp(to, t)
		
		if tilemap.has_method("break_tile_at"):
			tilemap.break_tile_at(check_pos, damage)

func _on_body_entered(body: Node2D) -> void:
	if has_been_destroyed:
		return
	
	if body is TileMapLayer:
		has_been_destroyed = true
		body.break_tile_at(global_position, damage)
		on_hit_tile(body)
		return
	
	# ✅ FIXED: Pass from_player=true to enemy damage
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		has_been_destroyed = true
		var knockback_dir = direction
		
		# This is a player shot, so from_player=true
		body.take_damage(damage, knockback_dir, knockback_force, true)
		
		# Track hit for accuracy (bullet connected)
		GameManager.register_hit()
		
		on_hit_enemy(body)
		return
	
	if not body.is_in_group("player"):
		has_been_destroyed = true
		on_hit_obstacle(body)

func _on_area_entered(area: Area2D) -> void:
	if has_been_destroyed:
		return
	
	var parent = area.get_parent()
	
	# ✅ FIXED: Pass from_player=true to enemy damage
	if parent and parent.is_in_group("enemies") and parent.has_method("take_damage"):
		has_been_destroyed = true
		var knockback_dir = direction
		
		# This is a player shot, so from_player=true
		parent.take_damage(damage, knockback_dir, knockback_force, true)
		
		# Track hit for accuracy (bullet connected)
		GameManager.register_hit()
		
		on_hit_enemy(parent)

func on_hit_tile(tile: Node2D) -> void:
	queue_free()

func on_hit_enemy(enemy: Node2D) -> void:
	"""
	✅ FIXED: Don't register kill here!
	The enemy's die() function will call GameManager.register_kill()
	when health reaches 0 and from_player=true
	
	We only track that the bullet HIT the enemy here.
	"""
	# Hit tracking is already done above in _on_body_entered/_on_area_entered
	# No need to check if enemy died or register kill - enemy handles that!
	
	queue_free()

func on_hit_obstacle(obstacle: Node2D) -> void:
	queue_free()
