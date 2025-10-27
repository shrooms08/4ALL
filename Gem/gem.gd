extends RigidBody2D
class_name Gem

# Gem Types
enum GemType { SMALL, LARGE}

@export var gem_type: GemType = GemType.SMALL
@export var auto_collect_range: float = 80.0  # Pixels for magnetic collection
@export var bounce_damping: float = 0.6  # How much velocity is kept on bounce (0-1)
@export var lifetime: float = 10.0

var age: float = 0.0

# Gem values
const GEM_VALUES = {
	GemType.SMALL: 2,
	GemType.LARGE: 10
}

# Visual
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var light: PointLight2D = $PointLight2D  # Optional glow effect
@onready var collect_particles: CPUParticles2D = $CollectParticles
@onready var area: Area2D = $CollectionArea  # Detection area for player

# Audio
@onready var collect_sound: AudioStreamPlayer2D = $CollectSound
@onready var bounce_sound: AudioStreamPlayer2D = $BounceSound

# Physics
var player: CharacterBody2D = null
var magnetic_pull: bool = false
var is_collected: bool = false

# Bouncing
var bounce_count: int = 0
const MAX_BOUNCES: int = 5  # Stop being bouncy after this many bounces
var last_collision_velocity: Vector2 = Vector2.ZERO

# Initial spawn force (shoots out from enemy)
var spawn_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("gems")
	
	# Setup RigidBody2D properties (Downwell-style physics)
	gravity_scale = 1.0
	lock_rotation = true  # Don't spin
	linear_damp = 0.2  # Slight air resistance
	contact_monitor = true
	max_contacts_reported = 4
	
	# Setup collision layers
	collision_layer = 4  # Gems on layer 3 (bit 2)
	collision_mask = 3   # Collide with world (layer 1) and enemies (layer 2)
	
	# Setup collection area
	if area:
		area.collision_layer = 0
		area.collision_mask = 1  # Detect player only
		area.body_entered.connect(_on_collection_area_entered)
	
	# Set sprite based on type
	_setup_visual()
	
	# Connect physics signals
	body_entered.connect(_on_body_entered)
	
	# Apply initial spawn velocity if set
	if spawn_velocity != Vector2.ZERO:
		linear_velocity = spawn_velocity


func _setup_visual() -> void:
	if not sprite:
		return
	
	
	match gem_type:
		GemType.SMALL:
			sprite.play("small")
			if light:
				light.energy = 0.3
				light.texture_scale = 0.5
				light.color = Color(0.5, 0.8, 1.0)  # Blue
		#GemType.MEDIUM:
			#sprite.play("medium")
			#if light:
				#light.energy = 0.5
				#light.texture_scale = 0.75
				#light.color = Color(0.3, 1.0, 0.3)  # Green
		GemType.LARGE:
			sprite.play("large")
			if light:
				light.energy = 0.8
				light.texture_scale = 1.0
				light.color = Color(0.8, 0.3, 1.0)  # Purple
		#GemType.RARE:
			#sprite.play("rare")
			#if light:
				#light.energy = 1.2
				#light.texture_scale = 1.5
				#light.color = Color(1.0, 0.9, 0.3)  # Gold


func _physics_process(delta: float) -> void:
	if is_collected:
		return
	
	age += delta
	if age > lifetime:
		queue_free()
	
	
	# Check for player proximity (magnetic collection)
	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	
	if player and not magnetic_pull:
		var distance = global_position.distance_to(player.global_position)
		if distance < auto_collect_range:
			magnetic_pull = true
			# Disable physics when magnetized
			freeze = true
	
	# Magnetic pull towards player
	if magnetic_pull and player:
		var direction = (player.global_position - global_position).normalized()
		var pull_speed = 600.0  # Fast magnetic pull
		global_position += direction * pull_speed * delta
		
		# Check if reached player
		if global_position.distance_to(player.global_position) < 20:
			collect(player)


func _on_body_entered(body: Node) -> void:
	if is_collected:
		return
	
	# Play bounce sound on collision with world
	if not body.is_in_group("player") and bounce_count < MAX_BOUNCES:
		_play_bounce_sound()
		bounce_count += 1
		
		# Apply bounce damping (lose energy each bounce - Downwell style)
		linear_velocity *= bounce_damping
		
		# Stop being bouncy after max bounces
		if bounce_count >= MAX_BOUNCES:
			linear_damp = 5.0  # Come to rest quickly
			physics_material_override = null


func _on_collection_area_entered(body: Node2D) -> void:
	if is_collected:
		return
	
	if body.is_in_group("player"):
		collect(body)


func collect(collector: Node2D) -> void:
	if is_collected:
		return
	
	is_collected = true
	
	# Collect gem (refreshes combo timer)
	var value = GEM_VALUES.get(gem_type, 2)
	ComboManagr.collect_gem(value)
	
	# Visual feedback
	_play_collect_effects()
	
	# Remove gem after effects
	await get_tree().create_timer(0.15).timeout
	queue_free()


func _play_collect_effects() -> void:
	# Hide sprite
	if sprite:
		sprite.hide()
	
	# Hide light
	if light:
		light.hide()
	
	# Play particles
	if collect_particles:
		collect_particles.emitting = true
		collect_particles.one_shot = true
	
	# Play sound
	if collect_sound:
		collect_sound.play()
	
	# Disable physics
	freeze = true
	collision_layer = 0
	collision_mask = 0
	
	if area:
		area.collision_mask = 0


func _play_bounce_sound() -> void:
	if not bounce_sound:
		return
	
	# Vary pitch based on bounce count (gets lower each bounce)
	var pitch = 1.2 - (bounce_count * 0.15)
	bounce_sound.pitch_scale = clamp(pitch, 0.6, 1.5)
	
	# Vary volume based on velocity
	var velocity_magnitude = linear_velocity.length()
	var volume = remap(velocity_magnitude, 0, 500, -20, -5)
	bounce_sound.volume_db = clamp(volume, -20, 0)
	
	bounce_sound.play()


func spawn_with_force(direction: Vector2, force: float = 200.0) -> void:
	"""Call this when spawning gem from enemy death"""
	# Add random spread
	var spread_angle = randf_range(-30, 30)
	var spread_direction = direction.rotated(deg_to_rad(spread_angle))
	
	# Set initial velocity
	spawn_velocity = spread_direction.normalized() * force
	
	# Add slight upward bias for more interesting arcs
	spawn_velocity.y -= 100
	
	if is_inside_tree():
		linear_velocity = spawn_velocity


func get_value() -> int:
	return GEM_VALUES.get(gem_type, 50)


# Create physics material for bounciness
func setup_physics_material() -> void:
	var mat = PhysicsMaterial.new()
	mat.bounce = 0.6  # Bouncy!
	mat.friction = 0.3  # Some friction
	physics_material_override = mat
