extends Camera2D


# Camera shake parameters
var shake_strength: float = 0.0
var shake_decay: float = 5.0
var shake_offset: Vector2 = Vector2.ZERO


# Downwell-style camera settings
@export var downwell_mode: bool = true
@export var scroll_ahead_distance: float = 100.0


# Player offset (slightly off center)
@export var player_offset: Vector2 = Vector2(0, 100)


# Camera limits
@export var use_auto_limits: bool = true
@export var manual_limit_left: int = -10000
@export var manual_limit_top: int = -10000
@export var manual_limit_right: int = 10000
@export var manual_limit_bottom: int = 20000


# Player tracking
var player: CharacterBody2D = null
var lowest_y_position: float = 0.0


func _ready():
	make_current()
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player:
		lowest_y_position = player.global_position.y
		global_position = player.global_position + player_offset
	if use_auto_limits:
		setup_auto_limits()
	else:
		setup_manual_limits()


func _process(delta):
	if downwell_mode and player:
		update_downwell_camera()

	# Camera shake
	if shake_strength > 0:
		shake_strength = lerpf(shake_strength, 0, shake_decay * delta)
		shake_offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		offset = shake_offset
		if shake_strength < 0.01:
			shake_strength = 0
			offset = Vector2.ZERO


func update_downwell_camera():
	if not player:
		return

	var screen_size = get_viewport_rect().size
	var half_height = screen_size.y * 0.5
	var player_y = player.global_position.y
	# Track the lowest Y reached (downwell logic)
	if player_y > lowest_y_position:
		lowest_y_position = player_y
	# Base target Y
	var target_y = lowest_y_position + scroll_ahead_distance
	# --- Keep player always inside the visible frame ---
	var top_edge = global_position.y - half_height
	var bottom_edge = global_position.y + half_height
	# If player goes above the top of view → move camera up immediately
	if player_y < top_edge + 80:  # margin from top
		global_position.y = player_y + half_height - 80
	# If player goes below the bottom of view → move camera down faster
	elif player_y > bottom_edge - 100:
		global_position.y = lerpf(global_position.y, player_y - half_height + 100, 0.2)
	# Ensure we don't scroll upward beyond Downwell rules
	if global_position.y < target_y:
		global_position.y = lerpf(global_position.y, target_y, 0.1)
	# Horizontal follows player
	global_position.x = player.global_position.x + player_offset.x


func setup_auto_limits():
	var tilemap = get_tree().get_first_node_in_group("tilemap")
	if tilemap and tilemap is TileMap:
		var used_rect = tilemap.get_used_rect()
		var tile_size = tilemap.tile_set.tile_size
		var top_left = tilemap.map_to_local(used_rect.position)
		var bottom_right = tilemap.map_to_local(used_rect.position + used_rect.size)
		limit_left = int(top_left.x)
		limit_top = int(top_left.y)
		limit_right = int(bottom_right.x)
		limit_bottom = int(bottom_right.y)
		limit_top -= 100
		limit_bottom += 200
	else:
		push_warning("No TileMap found in 'tilemap' group. Using manual limits.")
		setup_manual_limits()


func setup_manual_limits():
	limit_left = manual_limit_left
	limit_top = manual_limit_top
	limit_right = manual_limit_right
	limit_bottom = manual_limit_bottom


func shake(strength: float, duration: float = 0.0):
	shake_strength = strength
	if duration > 0:
		shake_decay = strength / duration


func reset_lowest_position():
	if player:
		lowest_y_position = player.global_position.y
		global_position.y = player.global_position.y


func set_camera_limits(left: int, top: int, right: int, bottom: int):
	limit_left = left
	limit_top = top
	limit_right = right
	limit_bottom = bottom
