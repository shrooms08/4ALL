extends CharacterBody2D
class_name BaseEnemy

# Exported variables
@export_group("Stats")
@export var max_health: float = 30.0
@export var move_speed: float = 300.0
@export var damage: float = 10.0
@export var knockback_resistance: float = 0.5

@export_group("Detection")
@export var detection_range: float = 200.0
@export var attack_range: float = 50.0
@export var attack_cooldown: float = 1.0

@export_group("Optimization")
@export var ai_update_rate: float = 0.2
@export var max_active_distance: float = 2000.0

@export_group("Drops")
@export var exp_value: int = 10
@export var gem_drop_chance: float = 1.0
@export var min_gem_drops: int = 1
@export var max_gem_drops: int = 3

# Signals
signal died(enemy: BaseEnemy)
signal player_kill(enemy: BaseEnemy)  # NEW: Specific signal for player kills
signal damaged(amount: float, current_health: float)
signal attack_performed()

# Internal variables
var current_health: float
var player: Node2D = null
var is_dead: bool = false
var can_attack: bool = true
var attack_timer: float = 0.0
var being_stomped: bool = false
var frozen: bool = false
var killed_by_player: bool = false  # NEW: Track if player got the kill

# ⚡ OPTIMIZATION: Cache player reference and update periodically
static var cached_player: Node2D = null
static var player_cache_time: float = 0.0
const PLAYER_CACHE_DURATION: float = 1.0

# ⚡ OPTIMIZATION: AI update timer
var ai_update_timer: float = 0.0
var last_direction: Vector2 = Vector2.ZERO
var is_ai_active: bool = true

# Node references
@onready var sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

func _ready():
	current_health = max_health
	add_to_group("enemies")
	add_to_group("enemy")
	add_to_group("freezable")
	
	# ⚡ Connect screen signals for optimization
	notifier.screen_entered.connect(_on_screen_entered)
	notifier.screen_exited.connect(_on_screen_exited)
	
	# ⚡ Get player once at start
	_update_player_reference()
	
	# ⚡ Random AI update offset to avoid all enemies updating same frame
	ai_update_timer = randf() * ai_update_rate

func _physics_process(delta):
	if is_dead or frozen:
		return
	
	# ⚡ Only process if AI is active (on screen or near player)
	if not is_ai_active:
		return
	
	# ⚡ Early exit if player is far above (cleanup) - NOT A PLAYER KILL
	if player and global_position.y < player.global_position.y - 1500:
		die(false)  # Pass false - not killed by player
		return
	
	# Handle attack cooldown
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
	
	# ⚡ Update AI only periodically, not every frame
	ai_update_timer += delta
	if ai_update_timer >= ai_update_rate:
		ai_update_timer = 0.0
		_update_ai_state()
	
	# ⚡ Continue moving in last known direction (smooth movement)
	if last_direction != Vector2.ZERO:
		velocity = last_direction * move_speed * delta
	
	move_and_slide()

# ⚡ OPTIMIZATION: Separate AI logic from physics
func _update_ai_state():
	# Update player reference periodically
	_update_player_reference()
	
	if not player or player.is_queued_for_deletion():
		last_direction = Vector2.ZERO
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# ⚡ Disable AI if player is too far (but don't delete immediately)
	if distance_to_player > max_active_distance:
		_disable_ai()
		return
	
	# Attack if in range
	if distance_to_player <= attack_range and can_attack:
		perform_attack()
		last_direction = Vector2.ZERO
	# Move toward player if detected
	elif distance_to_player <= detection_range:
		last_direction = (player.global_position - global_position).normalized()
		
		# Flip sprite
		if sprite_2d and last_direction.x != 0:
			sprite_2d.flip_h = last_direction.x < 0
	else:
		# Idle
		last_direction = Vector2.ZERO

# ⚡ OPTIMIZATION: Static player cache shared by all enemies
func _update_player_reference():
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Use cached player if still valid
	if cached_player and is_instance_valid(cached_player):
		if current_time - player_cache_time < PLAYER_CACHE_DURATION:
			player = cached_player
			return
	
	# Update cache
	cached_player = get_tree().get_first_node_in_group("player")
	player_cache_time = current_time
	player = cached_player

# ⚡ OPTIMIZATION: Disable AI when off-screen or far away
func _disable_ai():
	is_ai_active = false
	set_physics_process(false)
	velocity = Vector2.ZERO
	last_direction = Vector2.ZERO

func _enable_ai():
	is_ai_active = true
	set_physics_process(true)

func _on_screen_entered():
	if not is_dead and not frozen:
		_enable_ai()

func _on_screen_exited():
	# ⚡ Only disable AI when off-screen
	_disable_ai()
	
	# Don't auto-delete based on screen visibility
	# Let the chunk cleanup handle deletion when chunk is despawned

func set_frozen(value: bool):
	frozen = value
	set_physics_process(!value)
	if value:
		velocity = Vector2.ZERO
		last_direction = Vector2.ZERO

func move_toward_player(delta):
	# This is now handled in _update_ai_state
	pass

func idle_behavior(delta):
	# Handled in _update_ai_state
	pass

func perform_attack():
	if not can_attack:
		return
	
	can_attack = false
	attack_timer = attack_cooldown
	velocity = Vector2.ZERO
	
	attack()
	attack_performed.emit()

func attack():
	# Override in inherited classes
	pass

# ✅ FIXED: Now tracks WHO caused the damage
func take_damage(amount: float, knockback_direction: Vector2 = Vector2.ZERO, knockback_force: float = 300.0, from_player: bool = true):
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(0, current_health)
	
	GameManager.register_hit()
	
	# Apply knockback
	if knockback_direction != Vector2.ZERO:
		var knockback = knockback_direction.normalized() * knockback_force * (1.0 - knockback_resistance)
		velocity = knockback
		last_direction = Vector2.ZERO  # Stop AI movement during knockback
	
	# Flash effect
	damage_feedback()
	
	damaged.emit(amount, current_health)
	
	if current_health <= 0:
		die(from_player)  # Pass along who killed it

func damage_feedback():
	# ⚡ OPTIMIZATION: Use modulate tween instead of timer
	if sprite_2d:
		var tween = create_tween()
		tween.tween_property(sprite_2d, "modulate", Color(1, 0.3, 0.3), 0.05)
		tween.tween_property(sprite_2d, "modulate", Color.WHITE, 0.05)

func heal(amount: float):
	current_health = min(current_health + amount, max_health)

# ✅ FIXED: Only count kills when player actually killed the enemy
func die(from_player: bool = false):
	if is_dead:
		return
	
	is_dead = true
	killed_by_player = from_player
	set_physics_process(false)
	
	# ✅ ONLY count as kill if player did it
	if from_player:
		ComboManagr.register_kill()
		GameManager.register_kill(exp_value)
		
		var base_score = exp_value
		var final_score = ComboManagr.calculate_score(base_score)
		GameManager.add_score(final_score)
		
		# Debug print - only for player kills
		print("PLAYER KILL - Score:", GameManager.score, " | Enemies killed:", GameManager.enemies_killed)
		
		# Emit player kill signal
		player_kill.emit(self)
	else:
		# Debug print for non-player deaths
		print("Enemy died (not player kill) - despawned/fell/etc")
	
	# Disable collision
	if collision_shape_2d:
		collision_shape_2d.set_deferred("disabled", true)
	
	# Spawn effects and gems ONLY if killed by player
	if from_player:
		death_effects()
		spawn_gems()
	
	died.emit(self)
	
	# ⚡ Quick fade and delete
	if sprite_2d:
		var tween = create_tween()
		tween.tween_property(sprite_2d, "modulate:a", 0.0, 0.3)
		tween.finished.connect(queue_free)
	else:
		queue_free()

func spawn_gems() -> void:
	if GemSpawner:
		GemSpawner.spawn_gems_from_enemy(
			self,
			gem_drop_chance,
			min_gem_drops,
			max_gem_drops
		)

func death_effects():
	# Override for custom death effects
	pass

func get_damage_amount() -> float:
	return damage

func is_alive() -> bool:
	return not is_dead

func get_health_percentage() -> float:
	return current_health / max_health if max_health > 0 else 0.0

# ✅ FIXED: Kill function now assumes player kill
func kill():
	die(true)  # Assume manual kill() calls are from player

# NEW: Stomp damage function (call this from your stomp mechanic)
func take_stomp_damage(stomp_damage: float = 999.0):
	"""Special function for stomp kills - always counts as player kill"""
	take_damage(stomp_damage, Vector2.DOWN, 0.0, true)
