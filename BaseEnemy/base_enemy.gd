extends CharacterBody2D
class_name BaseEnemy

# Exported variables - these can be overridden in inherited scenes
@export_group("Stats")
@export var max_health: float = 30.0
@export var move_speed: float = 300.0
@export var damage: float = 10.0
@export var knockback_resistance: float = 0.5

@export_group("Detection")
@export var detection_range: float = 200.0
@export var attack_range: float = 50.0
@export var attack_cooldown: float = 1.0

@export_group("Drops")
@export var exp_value: int = 10

# Signals
signal died(enemy: BaseEnemy)
signal damaged(amount: float, current_health: float)
signal attack_performed()

# Internal variables
var current_health: float
var player: Node2D = null
var is_dead: bool = false
var can_attack: bool = true
var attack_timer: float = 0.0
var being_stomped: bool = false  # Flag to prevent damage when being stomped

var frozen: bool = false

# Node references
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea




func _ready():
	current_health = max_health
	add_to_group("enemies")
	add_to_group("enemy")  # Add both for compatibility
	add_to_group("freezable")


func _physics_process(delta):
	if is_dead or frozen:
		return
	
	# Handle attack cooldown
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
	
	# Find player if not already found
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return
	
	if player and not player.is_queued_for_deletion():
		var distance_to_player = global_position.distance_to(player.global_position)
		
		# Attack if in range and can attack
		if distance_to_player <= attack_range and can_attack:
			perform_attack()
		# Move toward player if detected but not in attack range
		elif distance_to_player <= detection_range:
			move_toward_player(delta)
		else:
			# Idle behavior when player is out of range
			idle_behavior(delta)
	
	move_and_slide()


func set_frozen(value: bool):
	frozen = value
	set_physics_process(!value)
	if value:
		velocity = Vector2.ZERO

func move_toward_player(delta):
	if not player:
		return
	
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * move_speed * delta
	
	# Flip sprite based on direction
	if sprite_2d and direction.x != 0:
		sprite_2d.flip_h = direction.x < 0
	
	## Play walk animation if available
	#if animation_player and animation_player.has_animation("walk"):
		#if not animation_player.is_playing() or animation_player.current_animation != "walk":
			#animation_player.play("walk")

func idle_behavior(delta):
	# Default idle behavior - can be overridden
	velocity = velocity.move_toward(Vector2.ZERO, move_speed * delta)
	
	#if animation_player and animation_player.has_animation("idle"):
		#if not animation_player.is_playing() or animation_player.current_animation != "idle":
			#animation_player.play("idle")

func perform_attack():
	if not can_attack:
		return
	
	can_attack = false
	attack_timer = attack_cooldown
	velocity = Vector2.ZERO
	
	# Play attack animation
	#if animation_player and animation_player.has_animation("attack"):
		#animation_player.play("attack")
	
	# Call the actual attack logic (override this for different attack types)
	attack()
	
	attack_performed.emit()

func attack():
	# Override this in inherited scenes for custom attack behavior
	# This is called during perform_attack()
	# Example: spawn projectiles, deal melee damage, etc.
	pass

func take_damage(amount: float, knockback_direction: Vector2 = Vector2.ZERO, knockback_force: float = 300.0):
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(0, current_health)
	
	
	# Apply knockback
	if knockback_direction != Vector2.ZERO:
		var knockback = knockback_direction.normalized() * knockback_force * (1.0 - knockback_resistance)
		velocity = knockback
	
	# Flash effect
	damage_feedback()
	
	# Emit signal
	damaged.emit(amount, current_health)
	
	# Check for death
	if current_health <= 0:
		die()

func damage_feedback():
	# Simple flash effect - override for custom feedback
	if sprite_2d:
		var original_modulate = sprite_2d.modulate
		sprite_2d.modulate = Color(1, 0.3, 0.3)
		await get_tree().create_timer(0.1).timeout
		if sprite_2d and not is_dead:
			sprite_2d.modulate = original_modulate

func heal(amount: float):
	current_health = min(current_health + amount, max_health)


func die():
	if is_dead:
		return
	
	is_dead = true
	set_physics_process(false)
	
	# Disable collision
	if collision_shape_2d:
		collision_shape_2d.set_deferred("disabled", true)
	
	# Play death animation
	#if animation_player and animation_player.has_animation("death"):
		#animation_player.play("death")
		#await animation_player.animation_finished
	else:
		# Simple fade out if no death animation
		if sprite_2d:
			var tween = create_tween()
			tween.tween_property(sprite_2d, "modulate:a", 0.0, 0.5)
			await tween.finished
	
	# Call death effects (override for custom behavior)
	death_effects()
	
	# Emit died signal
	died.emit(self)
	
	# Clean up
	queue_free()

func death_effects():
	# Override this in inherited scenes for custom death effects
	# Example: spawn particles, drop items, give exp to player, play sound
	pass

func get_damage_amount() -> float:
	return damage

func is_alive() -> bool:
	return not is_dead

func get_health_percentage() -> float:
	return current_health / max_health if max_health > 0 else 0.0


# Additional method for instant kill (used by stomp)
func kill():
	die()
