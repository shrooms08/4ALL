extends BaseEnemy
class_name SlimeSkull

@export var crawl_speed: float = 80.0
@export var contact_damage: float = 10.0
@export var direction_change_delay: float = 0.5

var crawl_direction: int = 1  # 1 = right, -1 = left
var is_changing_direction: bool = false

@onready var edge_detector: RayCast2D = $EdgeDetector if has_node("EdgeDetector") else null
@onready var wall_detector: RayCast2D = $WallDetector if has_node("WallDetector") else null
@onready var hitbox: Area2D = $Hitbox if has_node("Hitbox") else null
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	add_to_group("audience_enemies")
	
	max_health = 30
	move_speed = crawl_speed
	damage = contact_damage
	exp_value = 5
	
	super._ready()
	
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	setup_raycasts()
	
	# Pick random initial direction
	crawl_direction = [-1, 1].pick_random()
	update_raycast_directions()
	
	# Play spawn animation first
	if animated_sprite_2d and animated_sprite_2d.sprite_frames.has_animation("spawn"):
		animated_sprite_2d.play("spawn")
		await animated_sprite_2d.animation_finished
	
	start_crawl()

func start_crawl():
	if animated_sprite_2d and animated_sprite_2d.sprite_frames.has_animation("crawl"):
		animated_sprite_2d.play("crawl")

func _physics_process(delta):
	if is_dead:
		return
	
	crawl(delta)
	
	# Gravity
	if not is_on_floor():
		velocity.y += 980 * delta
	
	move_and_slide()
	check_environment()

func crawl(delta):
	velocity.x = crawl_direction * move_speed
	
	if animated_sprite_2d:
		animated_sprite_2d.flip_h = crawl_direction < 0
		if animated_sprite_2d.sprite_frames.has_animation("crawl"):
			if not animated_sprite_2d.is_playing() or animated_sprite_2d.animation != "crawl":
				animated_sprite_2d.play("crawl")

func check_environment():
	if is_changing_direction:
		return
	
	var should_turn = false
	
	if edge_detector and not edge_detector.is_colliding():
		should_turn = true
	if wall_detector and wall_detector.is_colliding():
		should_turn = true
	
	if should_turn:
		change_direction()

func change_direction():
	if is_changing_direction:
		return
	
	is_changing_direction = true
	crawl_direction *= -1
	update_raycast_directions()
	await get_tree().create_timer(direction_change_delay).timeout
	is_changing_direction = false

func update_raycast_directions():
	if edge_detector:
		edge_detector.target_position.x = abs(edge_detector.target_position.x) * crawl_direction
	if wall_detector:
		wall_detector.target_position.x = abs(wall_detector.target_position.x) * crawl_direction

func setup_raycasts():
	if not edge_detector:
		edge_detector = RayCast2D.new()
		edge_detector.name = "EdgeDetector"
		add_child(edge_detector)
		edge_detector.enabled = true
		edge_detector.target_position = Vector2(20 * crawl_direction, 20)
		edge_detector.collision_mask = 1
	
	if not wall_detector:
		wall_detector = RayCast2D.new()
		wall_detector.name = "WallDetector"
		add_child(wall_detector)
		wall_detector.enabled = true
		wall_detector.target_position = Vector2(15 * crawl_direction, 0)
		wall_detector.collision_mask = 1
	
	if not hitbox:
		hitbox = Area2D.new()
		hitbox.name = "Hitbox"
		add_child(hitbox)
		var hitbox_shape = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(20, 20)
		hitbox_shape.shape = shape
		hitbox.add_child(hitbox_shape)
		hitbox.collision_layer = 4
		hitbox.collision_mask = 1
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _on_hitbox_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		var knockback_dir = (body.global_position - global_position).normalized()
		body.take_damage(damage, knockback_dir)

func death_effects():
	if animated_sprite_2d and animated_sprite_2d.sprite_frames.has_animation("die"):
		animated_sprite_2d.play("die")
		await animated_sprite_2d.animation_finished
	queue_free()
