extends BaseEnemy
class_name Spider

@export var crawl_speed: float = 50.0
@export var contact_damage: float = 8.0
@export var ray_length: float = 30.0
@export var turn_delay: float = 0.3
@export var wall_stick_distance: float = 50.0
@export var rotation_speed: float = 10.0
@export var sprite_base_rotation: float = 90.0  # Add this to account for your 90° setup

var crawl_direction: int = 1
var is_turning: bool = false
var turn_timer: float = 0.0
var surface_normal: Vector2 = Vector2.UP
var target_rotation: float = 0.0
var on_surface: bool = false

var wall_check_ray: RayCast2D
var forward_ray: RayCast2D
var edge_ray: RayCast2D


@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var hitbox: Area2D = $Hitbox if has_node("Hitbox") else null

func _ready():
	max_health = 25.0
	move_speed = crawl_speed
	damage = contact_damage
	exp_value = 7
	super._ready()

	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

	setup_detection_rays()
	await get_tree().process_frame
	find_initial_surface()

# ---------- find starting surface ----------
func find_initial_surface():
	var directions = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
	var space_state = get_world_2d().direct_space_state
	var closest_dist = INF
	var closest_normal = Vector2.UP
	for d in directions:
		var from = global_position
		var to = global_position + d * ray_length * 2
		var q = PhysicsRayQueryParameters2D.create(from, to)
		q.collision_mask = 1
		q.exclude = [self]
		var res = space_state.intersect_ray(q)
		if res:
			var dist = global_position.distance_to(res.position)
			if dist < closest_dist:
				closest_dist = dist
				closest_normal = res.normal
	if closest_dist < INF:
		on_surface = true
		surface_normal = closest_normal.normalized()
		target_rotation = surface_normal.angle() + PI/2
		rotation = target_rotation
		set_crawl_direction_for_surface()

# ---------- physics ----------
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# turning timer; while turning we don't move
	if is_turning:
		turn_timer -= delta
		if turn_timer <= 0.0:
			is_turning = false
		# still smooth rotation to target
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
		update_sprite_orientation()  # Update sprite during turning too
		return

	# keep rays updated to current surface/rotation
	update_detection_rays()

	# Stick to wall if we're touching one
	stick_to_wall(delta)

	if on_surface:
		move_along_surface(delta)
		check_obstacles()
	else:
		# when not on surface, let gravity act
		velocity.y += 980 * delta

	# move (BaseEnemy/CharacterBody2D assumed to use `velocity` property)
	move_and_slide()

	# smooth rotation to target rotation (so spider aligns to wall)
	if on_surface:
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)

	# sprite flip - REPLACED with separate function
	update_sprite_orientation()

	queue_redraw()

# ---------- sprite orientation (replaces inline sprite flip logic) ----------
func update_sprite_orientation():
	if not animated_sprite_2d or not on_surface:
		return
	
	# Calculate the tangent direction in global space
	var tangent = Vector2(-surface_normal.y, surface_normal.x) * crawl_direction
	
	# Reset flips
	animated_sprite_2d.flip_h = false
	animated_sprite_2d.flip_v = false
	
	# Determine orientation based on which wall we're on
	# Adjust based on surface normal
	if abs(surface_normal.x) > abs(surface_normal.y):
		# On left or right wall
		if surface_normal.x > 0:  # Left wall (normal points right)
			animated_sprite_2d.flip_v = crawl_direction < 0
		else:  # Right wall (normal points left)
			animated_sprite_2d.flip_v = crawl_direction > 0
	else:
		# On floor or ceiling
		if surface_normal.y > 0:  # Floor (normal points up)
			animated_sprite_2d.flip_h = crawl_direction < 0
		else:  # Ceiling (normal points down)
			animated_sprite_2d.flip_h = crawl_direction > 0

# ---------- stick to wall ----------
func stick_to_wall(delta: float) -> void:
	# Cast from global_position towards -surface_normal (i.e. into the wall)
	var global_target = global_position - surface_normal.normalized() * ray_length
	wall_check_ray.target_position = to_local(global_target)

	if wall_check_ray.is_colliding():
		var coll_pt = wall_check_ray.get_collision_point()
		var coll_norm = wall_check_ray.get_collision_normal().normalized()

		# if surface changed significantly, adjust crawl direction for the new surface
		var normal_change = surface_normal.dot(coll_norm)
		if on_surface and normal_change < 0.8:
			set_crawl_direction_for_surface_transition(coll_norm)

		on_surface = true
		surface_normal = coll_norm
		target_rotation = surface_normal.angle() + PI/2

		# push slightly toward wall to maintain contact (gentle)
		var dist = global_position.distance_to(coll_pt)
		if dist > 4.0:
			var to_surf = (coll_pt - global_position).normalized()
			velocity += to_surf * wall_stick_distance * delta
	else:
		# lost contact
		on_surface = false

# ---------- move along surface ----------
func move_along_surface(delta: float) -> void:
	# tangent in global space (right-hand tangent of surface_normal)
	var tangent_global = Vector2(-surface_normal.y, surface_normal.x).normalized() * crawl_direction
	# set global velocity along the tangent
	velocity = tangent_global * crawl_speed
	# slight damping
	velocity *= 0.98

# ---------- obstacle checks ----------
func check_obstacles():
	if is_turning:
		return

	var should_turn = false

	# Edge detection uses edge_ray (pointing slightly away from the surface)
	if not edge_ray.is_colliding():
		should_turn = true

	# Forward obstacle: collision in front along surface tangent
	if forward_ray.is_colliding():
		should_turn = true

	if should_turn:
		turn_around()

# ---------- turn ----------
func turn_around():
	if is_turning:
		return
	is_turning = true
	turn_timer = turn_delay
	crawl_direction *= -1
	# after flipping direction, update rays to new forward
	update_detection_rays()

# ---------- set crawl direction helpers ----------
func set_crawl_direction_for_surface():
	var right_dot = surface_normal.dot(Vector2.RIGHT)
	# if on left wall (normal points right) -> go up by default
	if right_dot > 0.5:
		crawl_direction = 1
	# if on right wall (normal points left) -> go down by default
	elif right_dot < -0.5:
		crawl_direction = -1
	else:
		# floor or ceiling default to move right (but your spider likely won't be on floor)
		crawl_direction = 1

func set_crawl_direction_for_surface_transition(new_normal: Vector2) -> void:
	var rd = new_normal.dot(Vector2.RIGHT)
	var ud = new_normal.dot(Vector2.UP)
	if rd > 0.5:
		crawl_direction = 1
	elif rd < -0.5:
		crawl_direction = -1
	# else keep same for floor/ceiling transitions

# ---------- ray setup & update ----------
func setup_detection_rays():
	# Wall check - cast into wall (we'll set target in stick_to_wall())
	wall_check_ray = RayCast2D.new()
	wall_check_ray.name = "WallCheckRay"
	add_child(wall_check_ray)
	wall_check_ray.enabled = true
	wall_check_ray.exclude_parent = true
	wall_check_ray.collision_mask = 1

	# Forward ray (in front along the surface tangent)
	forward_ray = RayCast2D.new()
	forward_ray.name = "ForwardRay"
	add_child(forward_ray)
	forward_ray.enabled = true
	forward_ray.exclude_parent = true
	forward_ray.collision_mask = 1

	# Edge ray (in front + slightly away from wall to detect drop)
	edge_ray = RayCast2D.new()
	edge_ray.name = "EdgeRay"
	add_child(edge_ray)
	edge_ray.enabled = true
	edge_ray.exclude_parent = true
	edge_ray.collision_mask = 1

	update_detection_rays()

func update_detection_rays():
	if not forward_ray or not edge_ray:
		return

	var check_distance = 24.0

	# compute global forward along surface tangent
	var tangent = Vector2(-surface_normal.y, surface_normal.x).normalized() * crawl_direction
	var forward_global = global_position + tangent * check_distance
	forward_ray.target_position = to_local(forward_global)

	# edge: forward + slightly away from wall (away = -surface_normal)
	var away_global = -surface_normal.normalized() * (ray_length * 0.6)
	var edge_global = forward_global + away_global
	edge_ray.target_position = to_local(edge_global)

	# ensure wall_check_ray remains pointing into the wall
	var wall_target = global_position - surface_normal.normalized() * ray_length
	wall_check_ray.target_position = to_local(wall_target)

# ---------- contact ----------
func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		var knockback_dir = (body.global_position - global_position).normalized()
		body.take_damage(contact_damage, knockback_dir)

# ---------- health ----------
func take_damage(amount: float, knockback_direction: Vector2 = Vector2.ZERO, knockback_force: float = 300.0) -> void:
	if is_dead:
		return
	current_health -= amount
	current_health = max(0, current_health)
	damage_feedback()
	damaged.emit(amount, current_health)
	if current_health <= 0:
		die()

func death_effects() -> void:
	super.death_effects()

# ---------- overrides ----------
func idle_behavior(delta):
	pass

func move_toward_player(delta):
	pass

func attack():
	pass

# ---------- debug draw ----------
func _draw():
	if Engine.is_editor_hint() or OS.is_debug_build():
		if wall_check_ray:
			var c = Color.GREEN if wall_check_ray.is_colliding() else Color.RED
			draw_line(Vector2.ZERO, wall_check_ray.target_position, c, 2.0)
		if forward_ray:
			var c2 = Color.ORANGE if forward_ray.is_colliding() else Color.DARK_ORANGE
			draw_line(Vector2.ZERO, forward_ray.target_position, c2, 2.0)
		if edge_ray:
			var c3 = Color.CYAN if edge_ray.is_colliding() else Color.DARK_CYAN
			draw_line(Vector2.ZERO, edge_ray.target_position, c3, 2.0)
		draw_line(Vector2.ZERO, surface_normal * 20, Color.YELLOW, 3.0)
		if on_surface:
			var move_dir = Vector2(-surface_normal.y, surface_normal.x) * crawl_direction
			draw_line(Vector2.ZERO, move_dir * 30, Color.MAGENTA, 2.0)
