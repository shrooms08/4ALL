extends CharacterBody2D

#region Player Variation

@onready var player_animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_buffer_timer: Timer = $Timer/JumpBuffer
@onready var coyote_timer: Timer = $Timer/CoyoteTimer
@onready var hurt_timer: Timer = $Timer/HurtTimer
@onready var States: Node = $States
@onready var stomp_area: Area2D = $StompArea  # Add this as child node
@onready var shoot_particles: CPUParticles2D = $ShootParticles
@onready var shoot_particle_point: Marker2D = $ShootParticlePoint
@onready var weapon_manager: Node2D = $PlayerWeapon


# Camera Ref
@onready var camera_2d: Camera2D = $Camera2D


# Health System
const MAX_HEALTH = 3
var current_health = MAX_HEALTH
var is_invincible = false
const INVINCIBILITY_TIME = 1.0  # Seconds of invincibility after getting hurt
const KNOCKBACK_FORCE = 400  # Horizontal knockback when hurt
const KNOCKBACK_UP = -300  # Upward knockback when hurt

signal health_changed(new_health)
signal player_died()
signal enemy_stomped()

# Shooting
@export var bullet_scene: PackedScene  # Assign your bullet scene in inspector
@onready var shoot_point: Marker2D = $ShootPoint  # Add a Marker2D as child for bullet spawn

# Powerup System
var original_bullet_scene: PackedScene
var powerup_timer: Timer
var has_powerup = false 



const SHOOT_COOLDOWN = 0.15
const BULLETS_PER_SHOT = 1
const BULLET_SPREAD = 15.0  # degrees
const SHOOT_FALL_SLOWDOWN = 0.4
const SHOOT_UPWARD_KICK = -120
const SHOOT_FREEZE_TIME = 0.09 # upward push when shooting
var shoot_freeze_timer = 0.0
const MAX_AMMO = 8  # Maximum ammo capacity

var can_shoot = true
var shoot_timer = 0.0
var current_ammo = MAX_AMMO  # Current ammo (starts at 8)


# Stomp System
const STOMP_BOUNCE = -600  # Bounce velocity after stomping enemy
const STOMP_AMMO_REWARD = 2  # Ammo gained per stomp

# Physics Constants
const RUN_SPEED = 220.0
const JUMP_VELOCITY = -750.0
const GRAVITY_JUMP = 3200
const GRAVITY_FALL = 3500
const MAX_FALL_VELOCITY = 2000
const VARIABLE_JUMP_MULTIPLIER = 0.45
const MAX_JUMPS = 1
const JUMP_BUFFER_TIME = 0.08
const COYOTE_TIME = 0.08

const GROUND_ACCELERATION = 100
const GROUND_DECELERATION = 300
const AIR_ACCELERATION = 600
const AIR_DECELERATION = 500

# Player Variable
var Acceleration = GROUND_ACCELERATION
var Deceleration = GROUND_DECELERATION
var move_direction_x = 0
var jumps = 0
var jump_speed = JUMP_VELOCITY
var move_speed = RUN_SPEED
var facing = 1
var is_dead = false

@onready var jump_paricle_point: Marker2D = $JumpPariclePoint
@export var jump_particle_scene: PackedScene 

# AUDIOS
@onready var jump: AudioStreamPlayer2D = $Audio/Jump
@onready var shoot: AudioStreamPlayer2D = $Audio/Shoot
@onready var hurt: AudioStreamPlayer2D = $Audio/Hurt


# Input Variable
var key_up = false
var key_down = false
var key_left = false
var key_right = false
var key_jump = false
var key_jump_pressed = false


# State Machine
var current_state = null
var previous_state = null
var next_state = null


#endregion


#region Main Loop Functions

func _ready() -> void:
	add_to_group("player")
	
	# Create hurt timer if it doesn't exist
	if not hurt_timer:
		hurt_timer = Timer.new()
		hurt_timer.name = "HurtTimer"
		hurt_timer.one_shot = true
		add_child(hurt_timer)
		hurt_timer.timeout.connect(_on_hurt_timer_timeout)
	
	# Setup stomp area if it doesn't exist
	if not stomp_area:
		setup_stomp_area()
	else:
		stomp_area.body_entered.connect(_on_stomp_area_body_entered)
	
	if stomp_area:
		stomp_area.monitoring = true
		stomp_area.monitorable = true
	
	
	# Initialise State Machine
	for state in States.get_children():
		state.States = States
		state.Player = self
	previous_state = States.fall
	current_state = States.fall


func setup_stomp_area():
	# Create stomp area programmatically if not in scene
	stomp_area = Area2D.new()
	stomp_area.name = "StompArea"
	add_child(stomp_area)
	
	# Set collision layers - CRITICAL for detection
	stomp_area.collision_layer = 0  # Don't be on any layer
	stomp_area.collision_mask = 2   # Detect layer 2 (enemies should be on layer 2)
	
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 10)  # Adjust size as needed
	collision_shape.shape = shape
	collision_shape.position = Vector2(0, 20)  # Position at player's feet
	stomp_area.add_child(collision_shape)
	
	stomp_area.body_entered.connect(_on_stomp_area_body_entered)
	
	print("StompArea created programmatically")


func _draw() -> void:
	current_state.draw()


func _physics_process(delta: float) -> void:
	# Don't process if dead
	if is_dead:
		return
	
	# Get Input States
	get_input_states()

	# Shooting while airborne (Downwell-style)
	if not is_on_floor() and key_jump_pressed:
		handle_shoot()
	
	# Update shoot cooldown
	if shoot_timer > 0:
		shoot_timer -= delta
		if shoot_timer <= 0:
			can_shoot = true

	#Short freeze when shooting 
	if shoot_freeze_timer > 0:
		shoot_freeze_timer -= delta
		velocity.x = 0
		return

	# Check for enemy collisions
	check_enemy_collision()
	
	# Reset being_stomped flags on all enemies after collision check
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if "being_stomped" in enemy:
			enemy.being_stomped = false
	
	# Update current state
	current_state.update(delta)

	# handle movement
	handle_max_fall_velocity()

	# Commit movement
	move_and_slide()

	# handle state changes
	handle_state_change()


func change_state(target_state):
	if target_state:
		next_state = target_state


func handle_state_change():
	if next_state != null:
		if current_state != next_state:
			previous_state = current_state
			current_state.exit_state()
			current_state = null
			current_state = next_state
			current_state.enter_state()
		next_state = null


#endregion


#region Particle Effects

func spawn_jump_particle():
	# Spawns jump particle at the player's feet
	if jump_particle_scene == null:
		return
	
	var particle = jump_particle_scene.instantiate()
	
	# add to parent (the scene root) so it's not affected by player's movement
	get_parent().add_child(particle)
	
	# Position at the jump particle point 
	if jump_paricle_point:
		particle.global_position = jump_paricle_point.global_position
	
	# Play animation
	if particle is AnimatedSprite2D:
		particle.play()



#endregion

#region Stomp System

func check_stomp_collisions(velocity_y_before: float):
	# Check if StompArea is overlapping any enemies
	if not stomp_area:
		return
	
	var overlapping_bodies = stomp_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if (body.is_in_group("enemy") or body.is_in_group("enemies")) and velocity_y_before > 0:
			# Mark enemy as being stomped to prevent damage to player
			if body.has_method("set"):
				body.set("being_stomped", true)
			stomp_enemy(body)
			break  # Only stomp one enemy per frame


func _on_stomp_area_body_entered(body):
	# This is now just for debugging - actual stomp check happens in check_stomp_collisions
	print("StompArea detected body: ", body.name)
	print("Body groups: ", body.get_groups())
	
	# Check if it's an enemy and player is moving downward
	if (body.is_in_group("enemy") or body.is_in_group("enemies")) and velocity.y > 0:
		if "being_stomped" in body and body.being_stomped:
			return
		stomp_enemy(body)


func stomp_enemy(enemy):
	print("Stomping enemy: ", enemy.name)
	
	# Call on_stomped method if it exists (for custom stomp behavior)
	if enemy.has_method("on_stomped"):
		print("Calling on_stomped()")
		enemy.on_stomped()
	
	# Kill the enemy
	if enemy.has_method("die"):
		print("Calling die()")
		enemy.die()
	elif enemy.has_method("kill"):
		print("Calling kill()")
		enemy.kill()
	else:
		# Fallback: just remove the enemy
		print("Fallback: queue_free()")
		enemy.queue_free()
	
	# Reload ammo (capped at MAX_AMMO)
	current_ammo = min(current_ammo + STOMP_AMMO_REWARD, MAX_AMMO)
	
	# Apply bounce
	velocity.y = STOMP_BOUNCE
	
	# Reset jump count to allow chaining stomps
	jumps = 0
	
	# Emit signal for feedback (sound, particles, etc.)
	emit_signal("enemy_stomped")
	
	print("Enemy stomped! Ammo: ", current_ammo)


#endregion

#region Health and Damage System

func check_enemy_collision():
	# Check if player is touching any enemies
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Check if collider is an enemy
		if collider and (collider.is_in_group("enemy") or collider.is_in_group("enemies")):
			# Skip danage if this enemy is being stomped
			if "being_stomped" in collider and collider.being_stomped:
				continue
			take_damage(collider)


func take_damage(enemy):
	# Don't take damage if invincible or already dead
	if is_invincible or is_dead:
		return
	
	# Reduce health
	current_health -= 1
	emit_signal("health_changed", current_health)
	
	if hurt:
		hurt.play()
	
	
	# Check if dead
	if current_health <= 0:
		die()
		return
	
	# Apply knockback away from enemy
	var knockback_direction = sign(global_position.x - enemy.global_position.x)
	if knockback_direction == 0:
		knockback_direction = -facing  # Knockback opposite to facing direction
	
	velocity.x = knockback_direction * KNOCKBACK_FORCE
	velocity.y = KNOCKBACK_UP
	
	# Start invincibility
	is_invincible = true
	hurt_timer.start(INVINCIBILITY_TIME)
	
	# Optional: Add visual feedback (flashing)
	start_hurt_flash()


func die():
	is_dead = true
	emit_signal("player_died")
	
	# Stop all movement
	velocity = Vector2.ZERO
	
	# Play death animation
	player_animation.play("die")
	await player_animation.animation_finished
	
	# Optional: Play death animation or effects here
	print("Player died!")
	
	# You can restart the level, show game over screen, etc.
	# For now, we'll just reload the scene after a delay
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()


func _on_hurt_timer_timeout():
	is_invincible = false
	stop_hurt_flash()


func start_hurt_flash():
	player_animation.play("hurt")
	# Create a flashing effect during invincibility
	var tween = create_tween()
	tween.set_loops(int(INVINCIBILITY_TIME / 0.2))
	tween.tween_property(self, "modulate:a", 0.3, 0.1)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)


func stop_hurt_flash():
	# Ensure player is fully visible
	modulate.a = 1.0


func heal(amount: int = 1):
	current_health = min(current_health + amount, MAX_HEALTH)
	emit_signal("health_changed", current_health)


#endregion


func apply_bullet_powerup(bullet_scene: PackedScene, duration: float) -> void:
	if weapon_manager:
		weapon_manager.apply_bullet_powerup(bullet_scene, duration)
	else:
		# Fallback if no weapon manager
		self.bullet_scene = bullet_scene
		print("Powerup applied directly to player")


func get_input_states():
	key_up = Input.is_action_pressed("up")
	key_down = Input.is_action_pressed("down")
	key_jump = Input.is_action_pressed("jump")
	key_jump_pressed = Input.is_action_just_pressed("jump")
	key_left = Input.is_action_pressed("left")
	key_right = Input.is_action_pressed("right")

	if key_right: facing = 1
	if key_left: facing = -1


func horizontal_movement(acceleration: float = Acceleration, deceleration: float = Deceleration):
	move_direction_x = Input.get_axis("left", "right")
	if move_direction_x != 0:
		velocity.x = move_toward(velocity.x, move_direction_x * move_speed, acceleration)
	else:
		velocity.x = move_toward(velocity.x, move_direction_x * move_speed, deceleration)


func handle_fall():
	#see if we walked off a ledge, if so we go to fall state
	if !is_on_floor():
		# Start coyote timer
		coyote_timer.start(COYOTE_TIME)
		change_state(States.fall)


func handle_max_fall_velocity():
	if velocity.y > MAX_FALL_VELOCITY:
		velocity.y = MAX_FALL_VELOCITY


func handle_jump_buffer():
	if key_jump_pressed:
		jump_buffer_timer.start(JUMP_BUFFER_TIME)


func handle_landing():
	if is_on_floor():
		
		# Check for stomp right before landing
		check_for_stomp()
		
		# Spawn landing particle
		spawn_jump_particle()
		
		jumps = 0
		current_ammo = MAX_AMMO  # Reload ammo when landing
		change_state(States.idle)


func handle_gravity(delta, gravity: float = GRAVITY_JUMP) -> void:
	if !is_on_floor():
		velocity.y += gravity * delta
	handle_variable_jump()


func handle_variable_jump():
	if velocity.y < 0 and not key_jump:
		velocity.y *= VARIABLE_JUMP_MULTIPLIER

func play_jump_sound():
	if jump:
		jump.play()


func handle_jump():
	if is_on_floor():
		if jumps < MAX_JUMPS:
			if key_jump_pressed or jump_buffer_timer.time_left > 0:
				jump_buffer_timer.stop()
				jumps += 1
				
				# Spawn jump particle
				spawn_jump_particle()
				if jump:
					jump.play()
				change_state(States.jump)
				
	else:
		# SHOOTING: When in air, jump button shoots instead
		if not is_on_floor() and Input.is_action_just_pressed("jump"):
			handle_shoot()
			return
			
		# Double jump logic (if MAX_JUMPS > 1)
		if jumps < MAX_JUMPS and jumps > 0 and key_jump_pressed:
			jumps += 1
			change_state(States.jump)
			
		# handle coyote time jumps
		if coyote_timer.time_left > 0:
			if key_jump_pressed and jumps < MAX_JUMPS:
				coyote_timer.stop()
				jumps += 1
				change_state(States.jump)
	
	check_for_stomp()


func check_for_stomp():
	# Helper function to check stomps from handle_jump
	if not stomp_area or velocity.y <= 0:
		return
	
	var overlapping_bodies = stomp_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("enemy") or body.is_in_group("enemies"):
			_on_stomp_area_body_entered(body)
			#break


func handle_shoot():
	# Check if we can shoot (have ammo, not on cooldown, bullet scene exists)
	if !can_shoot or bullet_scene == null or current_ammo <= 0:
		return
	
	# Shoot downward
	shoot_bullets()
	
	# Emit shoot particles
	if shoot_particles and shoot_particle_point:
		shoot_particles.global_position = shoot_particle_point.global_position
		shoot_particles.emitting = false
		shoot_particles.restart()
		shoot_particles.emitting = true
	
	if shoot:
		shoot.play()
	
	# Consume ammo
	current_ammo = max(0, current_ammo - 1)
	
	#  Shootin freeze time
	shoot_freeze_timer = SHOOT_FREEZE_TIME
	
	# Slow down fall speed when shooting
	if velocity.y > 0:
		velocity.y *= SHOOT_FALL_SLOWDOWN
		velocity.y += SHOOT_UPWARD_KICK
	
	# Add Camera Shake Here
	if camera_2d and camera_2d.has_method("shake"):
		camera_2d.shake(5.0) 
	
	# Start cooldown
	can_shoot = false
	shoot_timer = SHOOT_COOLDOWN


func shoot_bullets():
	var base_angle = 90  # Shooting downward (90 deg rees)
	
	# Get current bullet scene from weapon manager
	var bullet_to_use = bullet_scene # Default fallback
	
	if weapon_manager:
		bullet_to_use = weapon_manager.get_current_bullet_scene()
	
	for i in range(BULLETS_PER_SHOT):
		var bullet = bullet_to_use.instantiate()
		get_parent().add_child(bullet)
		
		# Position bullet at shoot point
		if shoot_point:
			bullet.global_position = shoot_point.global_position
		else:
			bullet.global_position = global_position
		
		# Calculate spread angle
		var spread_offset = 0
		if BULLETS_PER_SHOT > 1:
			spread_offset = (i - (BULLETS_PER_SHOT - 1) / 2.0) * BULLET_SPREAD
		
		var angle = deg_to_rad(base_angle + spread_offset)
		
		# Set bullet direction
		if bullet.has_method("setup"):
			bullet.setup(angle)


func handle_flip_h():
	player_animation.flip_h = facing < 0
