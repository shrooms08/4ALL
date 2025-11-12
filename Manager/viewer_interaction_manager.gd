extends Node
class_name ViewerInteractionManager

## ViewerInteractionManager
## Connects to Vorld Arena Arcade via WebSocket bridge
## Handles real-time viewer interactions (boosts, spawns, events)

# WebSocket configuration
const BRIDGE_URL = "ws://localhost:9080"
var socket: WebSocketPeer
var connection_status := WebSocketPeer.STATE_CLOSED

# Game references
var player: CharacterBody2D
var game_scene: Node2D
var audience_spawner

# Viewer interaction state
var arena_active := false
var countdown_seconds := 0
var last_boost_data := {}

# Signals for game integration
signal arena_countdown_started(seconds: int)
signal arena_live()
signal viewer_boost_received(booster_name: String, amount: int, coins_spent: int)
signal viewer_item_dropped(item_id: String, item_name: String, metadata: Dictionary)
signal viewer_package_dropped(items: Array)
signal viewer_custom_event(event_name: String, data: Dictionary)
signal countdown_update(seconds_remaining: int)

# Effect configuration
const BOOST_SPEED_MULTIPLIER = 1.5
const BOOST_DURATION = 5.0
var active_boost_timer := 0.0

func _ready() -> void:
	add_to_group("viewer_manager")
	print("🎮 ViewerInteractionManager ready")
	
	# Don't auto-connect, wait for game to start
	call_deferred("_delayed_connect")

func _delayed_connect() -> void:
	await get_tree().create_timer(1.0).timeout
	connect_to_bridge()

func _process(delta: float) -> void:
	if socket:
		socket.poll()
		var state = socket.get_ready_state()
		
		if state != connection_status:
			connection_status = state
			_on_connection_state_changed(state)
		
		if state == WebSocketPeer.STATE_OPEN:
			while socket.get_available_packet_count() > 0:
				var packet = socket.get_packet()
				var message = packet.get_string_from_utf8()
				_handle_message(message)
	
	# Update active boost timer
	if active_boost_timer > 0:
		active_boost_timer -= delta
		if active_boost_timer <= 0:
			_end_boost()

## Connect to the Node.js bridge server
func connect_to_bridge() -> void:
	print("🔌 Attempting to connect to Vorld bridge at ", BRIDGE_URL)
	
	socket = WebSocketPeer.new()
	var err = socket.connect_to_url(BRIDGE_URL)
	
	if err != OK:
		push_error("❌ Failed to initiate WebSocket connection: " + str(err))
		# Retry after delay
		await get_tree().create_timer(5.0).timeout
		connect_to_bridge()
	else:
		print("✅ WebSocket connection initiated")

func _on_connection_state_changed(state: int) -> void:
	match state:
		WebSocketPeer.STATE_CONNECTING:
			print("🔄 Connecting to Vorld bridge...")
		WebSocketPeer.STATE_OPEN:
			print("✅ Connected to Vorld bridge!")
			_send_ping()
		WebSocketPeer.STATE_CLOSING:
			print("⏹️  Closing connection...")
		WebSocketPeer.STATE_CLOSED:
			print("🔌 Disconnected from Vorld bridge")
			# Auto-reconnect after delay
			await get_tree().create_timer(5.0).timeout
			connect_to_bridge()

func _send_ping() -> void:
	if socket and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var ping_data = JSON.stringify({"type": "ping"})
		socket.send_text(ping_data)

## Handle incoming WebSocket messages
func _handle_message(message: String) -> void:
	var json = JSON.new()
	var parse_result = json.parse(message)
	
	if parse_result != OK:
		push_error("Failed to parse WebSocket message: " + message)
		return
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return
	
	# Route based on event type
	if data.has("type"):
		_route_event(data)
	else:
		# Some events come as arrays with event name as key
		for key in data.keys():
			if data[key] is Dictionary:
				data[key]["_event_type"] = key
				_route_event(data[key])

func _route_event(event: Dictionary) -> void:
	var event_type = event.get("type", event.get("_event_type", event.get("0", "")))
	
	print("📨 Received event: ", event_type)
	
	match event_type:
		"pong":
			pass  # Ignore pong responses
		
		"arena_countdown_started":
			_handle_countdown_started(event)
		
		"countdown_update":
			_handle_countdown_update(event)
		
		"arena_begins":
			_handle_arena_begins(event)
		
		"player_boost":
			_handle_player_boost(event)
		
		"package_drop":
			_handle_package_drop(event)
		
		"immediate_item_drop":
			_handle_immediate_item_drop(event)
		
		"custom_event":
			_handle_custom_event(event)
		
		"game_completed":
			_handle_game_completed(event)
		
		_:
			print("⚠️  Unknown event type: ", event_type)

## Event Handlers

func _handle_countdown_started(event: Dictionary) -> void:
	countdown_seconds = event.get("countdown", 60)
	print("⏱️  Arena countdown started: ", countdown_seconds, " seconds")
	emit_signal("arena_countdown_started", countdown_seconds)
	
	# Show countdown to player
	_show_notification("Arena starting in %d seconds!" % countdown_seconds, Color.YELLOW)

func _handle_countdown_update(event: Dictionary) -> void:
	countdown_seconds = event.get("secondsRemaining", 0)
	if countdown_seconds <= 10 and countdown_seconds > 0:
		_show_notification(str(countdown_seconds), Color.YELLOW, 0.8)
	emit_signal("countdown_update", countdown_seconds)

func _handle_arena_begins(event: Dictionary) -> void:
	arena_active = true
	print("🎮 Arena is LIVE! Viewers can now interact")
	emit_signal("arena_live")
	
	_show_notification("ARENA LIVE! Viewers can now boost!", Color.GREEN, 3.0)

func _handle_player_boost(event: Dictionary) -> void:
	var booster = event.get("boosterUsername", "Viewer")
	var amount = event.get("boostAmount", 0)
	var coins = event.get("coinsSpent", 0)
	
	print("💪 %s boosted player with %d points (%d coins)" % [booster, amount, coins])
	emit_signal("viewer_boost_received", booster, amount, coins)
	
	# Apply boost effect
	_apply_boost(amount, booster)
	
	# Show notification
	_show_notification("%s boosted you! (+%d)" % [booster, amount], Color.CYAN, 2.0)
	_acknowledge_event("player_boost", event)

func _handle_package_drop(event: Dictionary) -> void:
	var items = event.get("items", [])
	print("📦 Package drop! Items: ", items)
	emit_signal("viewer_package_dropped", items)
	
	# Spawn enemies/items based on package data
	for item in items:
		_spawn_item_from_package(item)
	
	_show_notification("Package dropped!", Color.PURPLE, 2.0)
	_acknowledge_event("package_drop", event)

func _handle_immediate_item_drop(event: Dictionary) -> void:
	var item_id = event.get("itemId", "")
	var item_name = event.get("itemName", "Unknown")
	var metadata = event.get("metadata", {})
	
	print("🎁 Immediate item drop: ", item_name)
	emit_signal("viewer_item_dropped", item_id, item_name, metadata)
	
	# Parse item type and spawn
	_spawn_immediate_item(item_id, item_name, metadata)
	
	_show_notification("Item: " + item_name, Color.GOLD, 2.0)
	_acknowledge_event("immediate_item_drop", event)

func _handle_custom_event(event: Dictionary) -> void:
	var event_name = event.get("eventName", "")
	print("⚡ Custom event: ", event_name)
	emit_signal("viewer_custom_event", event_name, event)
	
	# Handle specific custom events
	match event_name:
		"spawn_boss":
			_spawn_boss()
		"double_enemies":
			_double_enemy_spawns()
		"invincibility":
			_give_invincibility()
		_:
			_show_notification("Event: " + event_name, Color.ORANGE, 2.0)

func _handle_game_completed(event: Dictionary) -> void:
	arena_active = false
	print("🏁 Game completed!")
	_show_notification("Arena Complete!", Color.GREEN, 3.0)

## Game Effect Implementations

func _apply_boost(amount: int, booster_name: String) -> void:
	"""Apply boost effect to player"""
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if not player:
		push_warning("No player found to boost")
		return
	
	# Speed boost for duration
	var original_speed = player.RUN_SPEED
	player.move_speed = original_speed * BOOST_SPEED_MULTIPLIER
	active_boost_timer = BOOST_DURATION
	
	# Visual feedback
	if player.has_node("AnimatedSprite2D"):
		var sprite = player.get_node("AnimatedSprite2D")
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.CYAN, 0.3)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
		tween.set_loops(int(BOOST_DURATION / 0.6))
	
	# Add score
	if GameManager:
		GameManager.add_score(amount * 10)

func _end_boost() -> void:
	"""End boost effect"""
	if not player:
		return
	
	player.move_speed = player.RUN_SPEED
	print("Boost ended")

func _spawn_item_from_package(item_data: Dictionary) -> void:
	"""Spawn item or enemy from package drop"""
	var item_id = item_data.get("id", "")
	var quantity = int(item_data.get("quantity", "1"))
	
	# Parse item type
	if "Enemy" in item_id or "enemy" in item_id:
		# Spawn enemy
		_spawn_audience_enemy(quantity, item_id)
	elif "Weapon" in item_id or "weapon" in item_id:
		# Spawn weapon pickup (if you have weapon pickups)
		pass
	else:
		# Default: spawn gems
		_spawn_gems(quantity)

func _spawn_immediate_item(item_id: String, item_name: String, metadata: Dictionary) -> void:
	"""Spawn an immediately dropped item"""
	var type = metadata.get("type", "")
	var quantity = int(metadata.get("quantity", "1"))
	
	match type:
		"enemy":
			_spawn_audience_enemy(quantity, item_id)
		"weapon":
			# Spawn weapon powerup
			pass
		_:
			_spawn_gems(quantity)

func _spawn_audience_enemy(count: int, enemy_type: String) -> void:
	"""Spawn enemies near player"""
	if not audience_spawner:
		audience_spawner = get_tree().get_first_node_in_group("audience_spawner")
	
	if not audience_spawner:
		push_warning("No audience spawner found")
		return
	
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if not player:
		return
	
	# Spawn enemies around player
	for i in range(count):
		var offset = Vector2(randf_range(-300, 300), randf_range(-200, -50))
		var spawn_pos = player.global_position + offset
		
		if audience_spawner.has_method("spawn_random_audience_enemy"):
			audience_spawner.spawn_random_audience_enemy(spawn_pos)
		else:
			push_warning("AudienceSpawner doesn't have spawn method")

func _spawn_gems(count: int) -> void:
	"""Spawn gems near player"""
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if not player:
		return
	
	# You'll need your gem scene
	var gem_scene = preload("res://Gem/gem.tscn")
	
	for i in range(count):
		var gem = gem_scene.instantiate()
		get_tree().root.add_child(gem)
		
		var offset = Vector2(randf_range(-100, 100), randf_range(-50, 50))
		gem.global_position = player.global_position + offset

func _spawn_boss() -> void:
	"""Spawn a boss enemy"""
	_show_notification("BOSS SPAWNED!", Color.RED, 3.0)
	# Implement boss spawning

func _double_enemy_spawns() -> void:
	"""Double enemy spawn rate temporarily"""
	_show_notification("ENEMY SURGE!", Color.ORANGE_RED, 2.0)
	# Implement spawn rate increase

func _give_invincibility() -> void:
	"""Give player temporary invincibility"""
	if not player:
		return
	
	player.is_invincible = true
	_show_notification("INVINCIBLE!", Color.GOLD, 3.0)
	
	await get_tree().create_timer(5.0).timeout
	player.is_invincible = false

## UI Feedback

func _show_notification(text: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	"""Show notification to player"""
	# You'll need to implement this based on your UI system
	print("🎮 NOTIFICATION: ", text)
	
	# Try to find and use your HUD or UI
	var ui = get_tree().get_first_node_in_group("player_ui")
	if ui and ui.has_method("show_notification"):
		ui.show_notification(text, color, duration)

func _exit_tree() -> void:
	if socket:
		socket.close()

func _acknowledge_event(event_type: String, payload: Dictionary) -> void:
	if not Engine.has_singleton("VorldClient"):
		return
	var payload_copy: Dictionary = payload.duplicate(true)
	call_deferred("_acknowledge_event_internal", event_type, payload_copy)

func _acknowledge_event_internal(event_type: String, payload: Dictionary) -> void:
	var ack_payload: Dictionary = {
		"eventType": event_type,
		"payload": payload,
		"clientTimestamp": Time.get_unix_time_from_system()
	}
	var response := await VorldClient.acknowledge_event(event_type, ack_payload)
	if not response.get("ok", false):
		var error_msg := VorldClient.get_error_message(response, "Event acknowledgement failed.")
		push_warning("Event ack failed: %s" % error_msg)

