extends BaseEnemy
class_name Worm

# Worm-specific stats (overriding base values)
@export var crawl_speed: float = 50.0
@export var contact_damage: float = 5.0
@export var direction_change_delay: float = 0.5

# Movement variables
var crawl_direction: int = 1  # 1 for right, -1 for left
var is_changing_direction: bool = false

# Raycasts for edge detection and wall detection
@onready var edge_detector: RayCast2D = $EdgeDetector if has_node("EdgeDetector") else null
@onready var wall_detector: RayCast2D = $WallDetector if has_node("WallDetector") else null
@onready var hitbox: Area2D = $Hitbox if has_node("Hitbox") else null
@onready var animated_sprite_2d_2: AnimatedSprite2D = $AnimatedSprite2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D2

func _ready():
	# Set worm stats
	max_health = 10.0
	move_speed = crawl_speed
	damage = contact_damage
	detection_range = 0  # Worm doesn't detect player
	attack_range = 0  # Worm doesn't have attacks
	exp_value = 5
	
	# Call parent ready
	super._ready()
	
	# Setup hitbox for contact damage
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# Setup raycasts if they don't exist
	setup_raycasts()

func _physics_process(delta):
	if is_dead:
		return
	
	# Worm doesn't use the base enemy AI, it just crawls
	crawl(delta)
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += 980 * delta
	
	move_and_slide()
	
	# Check for edges and walls
	check_environment()

func crawl(delta):
	# Simple back and forth movement
	velocity.x = crawl_direction * move_speed
	
	# Flip sprite based on direction using scale instead of flip_h
	if animated_sprite_2d:
		animated_sprite_2d.scale.x = abs(animated_sprite_2d.scale.x) * (-1 if crawl_direction < 0 else 1)
	
	# Play crawl animation
	if animated_sprite_2d and animated_sprite_2d.sprite_frames:
		if animated_sprite_2d.sprite_frames.has_animation("crawl"):
			if not animated_sprite_2d.is_playing() or animated_sprite_2d.animation != "crawl":
				animated_sprite_2d.play("crawl")

func check_environment():
	if is_changing_direction:
		return
	
	var should_turn = false
	
	# Check for edge (no ground ahead)
	if edge_detector and not edge_detector.is_colliding():
		should_turn = true
	
	# Check for wall
	if wall_detector and wall_detector.is_colliding():
		should_turn = true
	
	# Turn around if needed
	if should_turn:
		change_direction()

func change_direction():
	if is_changing_direction:
		return
	
	is_changing_direction = true
	crawl_direction *= -1
	
	# Update raycast directions
	update_raycast_directions()
	
	# Small delay before checking again
	await get_tree().create_timer(direction_change_delay).timeout
	is_changing_direction = false

func update_raycast_directions():
	if edge_detector:
		edge_detector.target_position.x = abs(edge_detector.target_position.x) * crawl_direction
	if wall_detector:
		wall_detector.target_position.x = abs(wall_detector.target_position.x) * crawl_direction

func setup_raycasts():
	# Create edge detector if it doesn't exist
	if not edge_detector:
		edge_detector = RayCast2D.new()
		edge_detector.name = "EdgeDetector"
		add_child(edge_detector)
		edge_detector.enabled = true
		edge_detector.target_position = Vector2(20 * crawl_direction, 20)  # Check ahead and down
		edge_detector.collision_mask = 1  # Check for ground/platforms
	
	# Create wall detector if it doesn't exist
	if not wall_detector:
		wall_detector = RayCast2D.new()
		wall_detector.name = "WallDetector"
		add_child(wall_detector)
		wall_detector.enabled = true
		wall_detector.target_position = Vector2(15 * crawl_direction, 0)  # Check ahead horizontally
		wall_detector.collision_mask = 1  # Check for walls
	
	# Create hitbox if it doesn't exist
	if not hitbox:
		hitbox = Area2D.new()
		hitbox.name = "Hitbox"
		add_child(hitbox)
		
		var hitbox_shape = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(20, 20)  # Adjust based on your sprite size
		hitbox_shape.shape = shape
		hitbox.add_child(hitbox_shape)
		
		hitbox.collision_layer = 4  # Enemy hitbox layer
		hitbox.collision_mask = 1   # Detect player layer
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _on_hitbox_body_entered(body):
	# Deal contact damage to player
	if body.is_in_group("player") and body.has_method("take_damage"):
		var knockback_dir = (body.global_position - global_position).normalized()
		body.take_damage(damage, knockback_dir)

func idle_behavior(delta):
	# Override: Worm doesn't idle, it always crawls
	crawl(delta)

func move_toward_player(delta):
	# Override: Worm doesn't chase player, it just crawls
	crawl(delta)

func attack():
	# Override: Worm doesn't attack
	pass

func death_effects():
	# Optional: Add worm-specific death effects
	# Example: spawn goo particles, play squelch sound
	pass
