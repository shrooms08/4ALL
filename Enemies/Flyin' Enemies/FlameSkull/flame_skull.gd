extends BaseEnemy
class_name FlameSkull

# Flying-specific properties
@export var hover_height_variation: float = 20.0
@export var hover_speed: float = 2.0
@export var acceleration: float = 300.0
@export var deceleration: float = 200.0
@export var player_knockback_force: float = 350.0
@export var self_recoil_force: float = 200.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var hover_offset: float = 0.0
var time_passed: float = 0.0
var is_pursuing: bool = false

func _ready():
	add_to_group("audience_enemies")
	# Set bat stats
	max_health = 50.0
	current_health = max_health
	move_speed = 140.0
	damage = 15.0
	detection_range = 200.0
	attack_range = 20.0  # Contact range for collision damage
	attack_cooldown = 1.0
	exp_value = 30
	
	super._ready()
	
	# Random starting hover offset for variety
	hover_offset = randf() * PI * 2.0
	
	# Start with idle animation
	if animated_sprite_2d and animated_sprite_2d.sprite_frames:
		if animated_sprite_2d.sprite_frames.has_animation("idle"):
			animated_sprite_2d.play("idle")

func _physics_process(delta):
	if is_dead:
		return
	
	time_passed += delta
	
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
		
		# Always move toward player when detected
		if distance_to_player <= detection_range:
			is_pursuing = true
			move_toward_player(delta)
			
			# Play pursue animation
			if animated_sprite_2d and animated_sprite_2d.sprite_frames:
				if animated_sprite_2d.sprite_frames.has_animation("pursue"):
					if animated_sprite_2d.animation != "pursue":
						animated_sprite_2d.play("pursue")
			
			# Check if touching player (attack on contact)
			if distance_to_player <= attack_range and can_attack:
				perform_attack()
		else:
			# Idle hovering when player is out of range
			is_pursuing = false
			idle_behavior(delta)
			
			# Play idle animation
			if animated_sprite_2d and animated_sprite_2d.sprite_frames:
				if animated_sprite_2d.sprite_frames.has_animation("idle"):
					if animated_sprite_2d.animation != "idle":
						animated_sprite_2d.play("idle")
	
	move_and_slide()

func move_toward_player(delta):
	if not player:
		return
	
	# Calculate direction to player
	var direction = (player.global_position - global_position).normalized()
	
	# Add slight hovering motion for more organic feel
	var hover_y = sin(time_passed * hover_speed + hover_offset) * hover_height_variation
	var target_velocity = direction * move_speed
	target_velocity.y += hover_y
	
	# Smooth acceleration toward target velocity
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	
	# Flip sprite based on direction
	if animated_sprite_2d and direction.x != 0:
		animated_sprite_2d.flip_h = direction.x < 0

func idle_behavior(delta):
	# Gentle hovering in place
	var hover_y = sin(time_passed * hover_speed + hover_offset) * hover_height_variation
	velocity = velocity.move_toward(Vector2(0, hover_y), deceleration * delta)
	
	# Keep sprite facing current direction (don't reset flip during idle)

func attack():
	# Deal damage to player on contact
	if player and player.has_method("take_damage"):
		var knockback_dir = (player.global_position - global_position).normalized()
		player.take_damage(self)
	
	# Optional: Add a small recoil/bounce back effect
	if player:
		var recoil_direction = (global_position - player.global_position).normalized()
		velocity += recoil_direction * 150.0
