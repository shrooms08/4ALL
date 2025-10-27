# bullet_base.gd
extends Area2D
class_name BulletBase

const SPEED = 800
const LIFETIME = 2.0
const MAX_DISTANCE = 300

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

# Virtual method for child classes to override
func on_bullet_ready() -> void:
	pass

# Virtual method for when lifetime expires
func on_lifetime_expired() -> void:
	queue_free()

func setup(angle: float, bullet_damage: float = 10.0):
	direction = Vector2(cos(angle), sin(angle)).normalized()
	velocity = direction * get_bullet_speed()
	rotation = angle
	damage = bullet_damage
	on_setup_complete()

# Virtual method for additional setup in child classes
func on_setup_complete() -> void:
	pass

# Virtual method to allow child classes to modify speed
func get_bullet_speed() -> float:
	return SPEED

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

# Virtual method for custom physics behavior
func update_bullet_physics(delta: float) -> void:
	pass

# Virtual method to allow child classes to modify max distance
func get_max_distance() -> float:
	return MAX_DISTANCE

# Virtual method for when max distance is reached
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
	
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		has_been_destroyed = true
		var knockback_dir = direction
		body.take_damage(damage, knockback_dir, knockback_force)
		on_hit_enemy(body)
		return
	
	if !body.is_in_group("player"):
		has_been_destroyed = true
		on_hit_obstacle(body)

func _on_area_entered(area: Area2D) -> void:
	if has_been_destroyed:
		return
	
	var parent = area.get_parent()
	if parent and parent.is_in_group("enemies") and parent.has_method("take_damage"):
		has_been_destroyed = true
		var knockback_dir = direction
		parent.take_damage(damage, knockback_dir, knockback_force)
		on_hit_enemy(parent)

# Virtual methods for hit events that child classes can override
func on_hit_tile(tile: Node2D) -> void:
	queue_free()

func on_hit_enemy(enemy: Node2D) -> void:
	# Register hit for accuracy tracking
	GameManager.register_hit()
	
	# Register kill with combo if it kills the enemy
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
		
		# Check if enemy died and register with combo
		if enemy.has_method("is_alive") and not enemy.is_alive():
			ComboManagr.register_shot_kill()
	queue_free()

func on_hit_obstacle(obstacle: Node2D) -> void:
	queue_free()
