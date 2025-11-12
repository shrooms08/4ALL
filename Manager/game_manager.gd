extends Node

# ===== PLAYER IDENTITY =====
var user_id: String = ""
var player_name: String = "Player"
var email: String = ""
var login_type: String = "guest"  # guest, username, wallet
var access_token: String = ""
var refresh_token: String = ""
var profile: Dictionary = {}
var display_name: String = ""

# ===== PLAYER STATS =====
var level: int = 1
var total_xp: int = 0
var score: int = 0
var high_score: int = 0
var enemies_killed: int = 0  # ✅ Now only counts PLAYER kills
var depth: int = 0
var max_depth_reached: int = 0
var gems_collected: int = 0

# ===== COMBAT STATS =====
var shots_fired: int = 0
var accuracy: float = 0.0
var enemies_stomped: int = 0
var perfect_stomp_streak: int = 0
var hits_landed: int = 0  # ✅ NEW: Track successful hits for accuracy

# ===== XP & LEVELING =====
var xp_to_next_level: int = 100
const XP_MULTIPLIER: float = 1.3

# ===== POWERUP SYSTEM =====
var next_powerup_depth: int = 200
var powerup_interval: int = 200
var powerup_selection_ui: CanvasLayer = null

# ===== SESSION DATA =====
var session_start_time: int = 0
var total_play_time: int = 0
var runs_completed: int = 0
var last_login: int = 0
var _stats_sync_pending: bool = false

# ===== SIGNALS =====
signal user_loaded(user_data: Dictionary)
signal enemy_killed(total_kills: int)
signal level_up(new_level: int)
signal xp_gained(amount: int, total: int)
signal score_updated(new_score: int, high_score: int)
signal stats_updated
signal depth_reached(new_depth: int)
signal powerup_available
signal perfect_stomp_achieved(streak: int)
signal profile_saved
signal profile_loaded
signal profile_updated(profile: Dictionary)
signal server_sync_failed(message: String)
signal server_sync_succeeded(timestamp: int)


func _ready() -> void:
	add_to_group("game_manager")
	session_start_time = Time.get_unix_time_from_system()
	
	if not stats_updated.is_connected(_on_stats_updated_internal):
		stats_updated.connect(_on_stats_updated_internal)
	
	# Load user session first
	_load_user_session()
	
	# Initialize subsystems
	call_deferred("_initialize_subsystems")
	
	print("GameManager initialized for user:", user_id)


func _initialize_subsystems() -> void:
	"""Initialize all subsystems in correct order"""
	_find_powerup_ui()
	_connect_combo_manager()
	_connect_powerup_chunks()


# ===== USER SESSION MANAGEMENT =====

func _load_user_session() -> void:
	"""Load user session from login"""
	const SESSION_FILE = "user://session.save"
	
	if not FileAccess.file_exists(SESSION_FILE):
		push_warning("No session file found. Creating guest session.")
		_create_guest_session()
		return
	
	var file = FileAccess.open(SESSION_FILE, FileAccess.READ)
	if file == null:
		push_error("Failed to read session file: " + str(FileAccess.get_open_error()))
		_create_guest_session()
		return
	
	var session_data = file.get_var()
	file.close()
	
	if typeof(session_data) != TYPE_DICTIONARY:
		push_warning("Invalid session data. Creating guest session.")
		_create_guest_session()
		return
	
	# Load session info
	user_id = session_data.get("user_id", "")
	login_type = session_data.get("login_type", "guest")
	email = session_data.get("email", "")
	access_token = session_data.get("access_token", "")
	refresh_token = session_data.get("refresh_token", "")
	profile = session_data.get("profile", {})
	display_name = session_data.get("display_name", "")
	
	if user_id.is_empty():
		push_warning("Empty user ID. Creating guest session.")
		_create_guest_session()
		return

	if not access_token.is_empty():
		VorldClient.set_access_token(access_token)
		var profile_response := await VorldClient.fetch_profile()
		if profile_response.get("ok", false):
			var payload: Dictionary = profile_response.get("payload", {})
			if not payload.is_empty():
				profile = payload
				if payload.has("user") and typeof(payload["user"]) == TYPE_DICTIONARY:
					var user_info: Dictionary = payload["user"]
					if display_name.is_empty() and user_info.has("username"):
						display_name = str(user_info["username"])
				profile_updated.emit(profile)
		else:
			var error_msg := VorldClient.get_error_message(profile_response, "Failed to fetch profile.")
			push_warning("Profile fetch failed: %s" % error_msg)
			server_sync_failed.emit(error_msg)
	
	# Set player name based on login type
	if not display_name.is_empty():
		player_name = display_name
	elif profile.has("username"):
		player_name = str(profile["username"])
	elif login_type == "wallet":
		player_name = "Wallet_" + user_id.substr(0, 8)
	else:
		player_name = user_id
	
	# Display appropriate identifier
	var display_info = player_name
	if email != "" and login_type == "username":
		display_info = "%s (%s)" % [player_name, email]
	
	print("✅ Session loaded: %s (type: %s)" % [display_info, login_type])
	
	# Load player profile data
	_load_profile()
	call_deferred("_sync_stats_with_server")


func _create_guest_session() -> void:
	"""Create a temporary guest session"""
	user_id = "Guest_" + str(Time.get_unix_time_from_system())
	player_name = user_id
	login_type = "guest"
	email = ""
	access_token = ""
	refresh_token = ""
	profile = {}
	display_name = ""
	print("🎮 Guest session created:", user_id)


func _on_stats_updated_internal() -> void:
	if _stats_sync_pending:
		return
	_stats_sync_pending = true
	call_deferred("_sync_stats_with_server")


func _build_stats_payload() -> Dictionary:
	return {
		"userId": user_id,
		"displayName": player_name,
		"loginType": login_type,
		"email": email,
		"level": level,
		"score": score,
		"highScore": high_score,
		"enemiesKilled": enemies_killed,
		"gemsCollected": gems_collected,
		"shotsFired": shots_fired,
		"hitsLanded": hits_landed,
		"accuracy": accuracy,
		"totalXp": total_xp,
		"xpToNextLevel": xp_to_next_level,
		"perfectStompStreak": perfect_stomp_streak,
		"timestamp": Time.get_unix_time_from_system(),
		"arenaCoins": profile.get("arenaCoins", 0),
		"profile": profile
	}


func _sync_stats_with_server() -> void:
	_stats_sync_pending = false

	if access_token.is_empty():
		return

	VorldClient.set_access_token(access_token)

	var payload := _build_stats_payload()
	if payload.is_empty():
		return

	var response := await VorldClient.update_player_stats(payload)
	if not response.get("ok", false):
		var error_msg := VorldClient.get_error_message(response, "Failed to update player stats.")
		push_warning("Stats sync failed: %s" % error_msg)
		server_sync_failed.emit(error_msg)
	else:
		var timestamp: int = Time.get_unix_time_from_system()
		server_sync_succeeded.emit(timestamp)


# ===== POWERUP UI INITIALIZATION =====

func _find_powerup_ui() -> void:
	"""Find PowerupSelection UI in the scene tree"""
	var root = get_tree().root
	for child in root.get_children():
		if child is CanvasLayer and child.name == "PowerupSelection":
			powerup_selection_ui = child
			print("✅ PowerupSelection UI found!")
			return
	
	# Try to load dynamically
	var ui_path = "res://UI/powerup_selection.tscn"
	if ResourceLoader.exists(ui_path):
		var ui_scene = load(ui_path)
		if ui_scene:
			powerup_selection_ui = ui_scene.instantiate()
			get_tree().root.add_child(powerup_selection_ui)
			print("✅ PowerupSelection UI loaded dynamically!")
			return
	
	push_warning("⚠️ PowerupSelection UI not found at: " + ui_path)


# ===== COMBO MANAGER INTEGRATION =====

func _connect_combo_manager() -> void:
	"""Connect to ComboManager autoload"""
	if not has_node("/root/ComboManagr"):
		push_warning("⚠️ ComboManagr autoload not found!")
		return
	
	var combo_mgr = get_node("/root/ComboManagr")
	
	# Connect signals with error checking
	var signals_to_connect = [
		["combo_gained", _on_combo_gained],
		["combo_broken", _on_combo_broken],
		["combo_tier_reached", _on_combo_tier_reached],
		["combo_milestone_reached", _on_combo_milestone]
	]
	
	for signal_info in signals_to_connect:
		var signal_name = signal_info[0]
		var callback = signal_info[1]
		
		if combo_mgr.has_signal(signal_name):
			if not combo_mgr.is_connected(signal_name, callback):
				combo_mgr.connect(signal_name, callback)
		else:
			push_warning("ComboManagr missing signal: " + signal_name)
	
	print("✅ ComboManager signals connected")


func _connect_powerup_chunks() -> void:
	"""Connect to all powerup portal chunks"""
	var chunks = get_tree().get_nodes_in_group("powerup_chunk")
	
	for chunk in chunks:
		if chunk.has_signal("portal_entered"):
			if not chunk.is_connected("portal_entered", _on_portal_entered):
				chunk.portal_entered.connect(_on_portal_entered)
	
	if chunks.size() > 0:
		print("✅ Connected %d powerup chunks" % chunks.size())


# ===== XP & LEVELING SYSTEM =====

func add_xp(amount: int) -> void:
	"""Add experience points and check for level up"""
	if amount <= 0:
		return
	
	total_xp += amount
	xp_gained.emit(amount, total_xp)
	
	# Check for level ups
	while total_xp >= xp_to_next_level:
		_level_up_player()
	
	stats_updated.emit()


func _level_up_player() -> void:
	"""Handle player leveling up"""
	level += 1
	total_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * XP_MULTIPLIER)
	
	level_up.emit(level)
	print("🎉 Level Up! Now Level %d (Next: %d XP)" % [level, xp_to_next_level])
	
	_grant_level_rewards()
	
	# Auto-save on level up
	save_profile()


func _grant_level_rewards() -> void:
	"""Grant rewards for leveling up"""
	# Bonus powerup every 5 levels
	if level % 5 == 0:
		print("🎁 Milestone Level! Bonus rewards unlocked")
		add_score(level * 100)


# ===== COMBAT & SCORING =====

func register_kill(enemy_value: int = 100) -> void:
	"""✅ Register PLAYER kill with combo multiplier - only called for player kills"""
	enemies_killed += 1
	hits_landed += 1  # Count as successful hit
	
	# Calculate score with combo
	var final_score = enemy_value
	if has_node("/root/ComboManagr"):
		var combo_mgr = get_node("/root/ComboManagr")
		if combo_mgr.has_method("register_kill"):
			combo_mgr.register_kill()
		if combo_mgr.has_method("calculate_score"):
			final_score = combo_mgr.calculate_score(enemy_value)
	
	add_score(final_score)
	add_xp(10)  # Base XP per kill
	
	# Update accuracy
	_update_accuracy()
	
	enemy_killed.emit(enemies_killed)
	stats_updated.emit()
	
	print("🎯 Player Kill #%d | Score: %d (+%d)" % [enemies_killed, score, final_score])


func register_stomp() -> void:
	"""✅ Register stomp kill - always a player kill"""
	enemies_stomped += 1
	perfect_stomp_streak += 1
	
	# Register with ComboManager
	if has_node("/root/ComboManagr"):
		var combo_mgr = get_node("/root/ComboManagr")
		if combo_mgr.has_method("register_stomp"):
			combo_mgr.register_stomp()
	
	# Bonus XP for streaks
	if perfect_stomp_streak > 1:
		var bonus_xp = perfect_stomp_streak * 5
		add_xp(bonus_xp)
		print("🦶 Stomp Streak: %d (+%d XP)" % [perfect_stomp_streak, bonus_xp])
	
	if perfect_stomp_streak >= 5:
		perfect_stomp_achieved.emit(perfect_stomp_streak)
		print("⭐ PERFECT STOMP STREAK: %d!" % perfect_stomp_streak)
	
	stats_updated.emit()


func reset_perfect_stomps() -> void:
	"""Reset stomp streak"""
	if perfect_stomp_streak > 0:
		print("💔 Stomp streak ended: %d" % perfect_stomp_streak)
	perfect_stomp_streak = 0


func register_shot() -> void:
	"""✅ Track shot fired (for accuracy calculation)"""
	shots_fired += 1
	_update_accuracy()


func register_hit() -> void:
	"""✅ Track successful hit (bullet connected with enemy)"""
	hits_landed += 1
	_update_accuracy()


func _update_accuracy() -> void:
	"""✅ Calculate accuracy percentage based on hits vs shots"""
	if shots_fired > 0:
		accuracy = (float(hits_landed) / float(shots_fired)) * 100.0
	else:
		accuracy = 0.0


func add_score(points: int) -> void:
	"""Add score and update high score"""
	if points <= 0:
		return
	
	score += points
	
	if score > high_score:
		high_score = score
		print("🏆 New High Score: %d!" % high_score)
		save_profile()  # Save new high score
	
	score_updated.emit(score, high_score)


# ===== GEM COLLECTION =====

func collect_gem(value: int = 1) -> void:
	"""Collect gems"""
	gems_collected += value
	add_score(value * 10)
	
	# Notify ComboManager
	if has_node("/root/ComboManagr"):
		var combo_mgr = get_node("/root/ComboManagr")
		if combo_mgr.has_method("collect_gem"):
			combo_mgr.collect_gem(value)
	
	stats_updated.emit()


# ===== DEPTH PROGRESSION =====

func update_depth(current_depth: int) -> void:
	"""Update depth and check powerup triggers"""
	if current_depth <= depth:
		return
	
	depth = current_depth
	
	if depth > max_depth_reached:
		max_depth_reached = depth
	
	depth_reached.emit(depth)
	stats_updated.emit()
	
	# Check for powerup unlock
	if depth >= next_powerup_depth:
		_trigger_powerup_unlock()


func _trigger_powerup_unlock() -> void:
	"""Trigger powerup at depth milestone"""
	print("⚡ Powerup milestone reached at depth: %d" % depth)
	next_powerup_depth += powerup_interval
	powerup_available.emit()


# ===== POWERUP SYSTEM =====

func trigger_powerup_selection() -> void:
	"""Show powerup selection UI"""
	if not powerup_selection_ui:
		push_warning("⚠️ PowerupSelection UI not available!")
		return
	
	if not powerup_selection_ui.has_method("show_powerup_selection"):
		push_warning("⚠️ PowerupSelection missing show_powerup_selection() method!")
		return
	
	print("🎁 Opening powerup selection...")
	powerup_selection_ui.show_powerup_selection()
	
	# Connect to selection (one-shot)
	if powerup_selection_ui.has_signal("powerup_chosen"):
		if not powerup_selection_ui.is_connected("powerup_chosen", _on_powerup_chosen):
			powerup_selection_ui.powerup_chosen.connect(_on_powerup_chosen, CONNECT_ONE_SHOT)


func _on_portal_entered(chunk: Node2D) -> void:
	"""Handle portal entry"""
	print("🌀 Portal entered at:", chunk.global_position)
	trigger_powerup_selection()


func _on_powerup_chosen(powerup_instance) -> void:
	"""Apply chosen powerup"""
	if not powerup_instance:
		push_warning("⚠️ No powerup instance received!")
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("⚠️ Player not found!")
		return
	
	if powerup_instance.has_method("apply"):
		powerup_instance.apply(player)
		var powerup_name = powerup_instance.get("powerup_name", "Unknown")
		print("✨ Powerup applied: %s" % powerup_name)
	else:
		push_warning("⚠️ Powerup has no apply() method!")


# ===== COMBO EVENT HANDLERS =====

func _on_combo_gained(combo_count: int) -> void:
	var bonus_xp = int(combo_count * 0.5)
	if bonus_xp > 0:
		add_xp(bonus_xp)


func _on_combo_broken() -> void:
	print("💔 Combo broken!")


func _on_combo_tier_reached(tier: int) -> void:
	print("⭐ Combo Tier: %d" % tier)
	add_score(tier * 100)


func _on_combo_milestone(milestone: int) -> void:
	print("🎉 Combo Milestone: %d" % milestone)
	add_xp(milestone * 5)
	add_score(milestone * 50)


# ===== DATA MANAGEMENT =====

func get_profile_data() -> Dictionary:
	"""Get complete profile data"""
	var combo_info = {}
	if has_node("/root/ComboManagr"):
		var combo_mgr = get_node("/root/ComboManagr")
		if combo_mgr.has_method("get_stats_summary"):
			combo_info = combo_mgr.get_stats_summary()
	
	var play_time = Time.get_unix_time_from_system() - session_start_time + total_play_time
	
	return {
		"user_id": user_id,
		"player_name": player_name,
		"email": email,
		"login_type": login_type,
		"level": level,
		"xp": total_xp,
		"xp_to_next": xp_to_next_level,
		"score": score,
		"high_score": high_score,
		"depth": depth,
		"max_depth": max_depth_reached,
		"kills": enemies_killed,
		"stomps": enemies_stomped,
		"gems": gems_collected,
		"shots": shots_fired,
		"hits": hits_landed,
		"accuracy": accuracy,
		"play_time": play_time,
		"runs_completed": runs_completed,
		"last_login": last_login,
		"combo_stats": combo_info,
		"timestamp": Time.get_unix_time_from_system()
	}


func get_stats_summary() -> String:
	"""Get formatted stats string"""
	var combo_str = ""
	if has_node("/root/ComboManagr"):
		var combo_mgr = get_node("/root/ComboManagr")
		if combo_mgr.has_method("get_combo_info"):
			var info = combo_mgr.get_combo_info()
			combo_str = "Combo: %d (Max: %d) | Tier: %d (%.1fx)" % [
				info.get("combo", 0),
				info.get("max_combo", 0),
				info.get("tier", 0),
				info.get("multiplier", 1.0)
			]
	
	var user_display = player_name
	if email != "" and login_type == "username":
		user_display = "%s (%s)" % [player_name, email]
	
	return """
=== PLAYER STATS ===
User: %s
Type: %s
Level: %d | XP: %d/%d
Score: %d (High: %d)
Depth: %dm (Max: %dm)
Kills: %d | Stomps: %d
Gems: %d | Shots: %d | Hits: %d
Accuracy: %.1f%%
%s
==================
""" % [
		user_display,
		login_type.capitalize(),
		level, total_xp, xp_to_next_level,
		score, high_score,
		depth, max_depth_reached,
		enemies_killed, enemies_stomped,
		gems_collected, shots_fired, hits_landed,
		accuracy,
		combo_str
	]


func get_user_info() -> Dictionary:
	"""Get user identity information"""
	return {
		"user_id": user_id,
		"player_name": player_name,
		"email": email,
		"login_type": login_type,
		"is_guest": login_type == "guest"
	}


# ===== SAVE/LOAD SYSTEM =====

func save_profile() -> void:
	"""Save profile to disk"""
	# Don't save guest profiles
	if login_type == "guest":
		print("⚠️ Guest profiles are not saved")
		return
	
	var save_file = "user://profiles/%s.save" % user_id.md5_text()
	var dir = DirAccess.open("user://")
	
	if not dir.dir_exists("profiles"):
		dir.make_dir("profiles")
	
	var file = FileAccess.open(save_file, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save profile: " + str(FileAccess.get_open_error()))
		return
	
	# Update last login time
	last_login = Time.get_unix_time_from_system()
	
	var save_data = get_profile_data()
	file.store_var(save_data)
	file.close()
	
	profile_saved.emit()
	print("💾 Profile saved for: %s" % player_name)


func _load_profile() -> void:
	"""Load profile from disk"""
	# Guests don't have saved profiles
	if login_type == "guest":
		print("🎮 Guest session - no profile to load")
		user_loaded.emit(get_profile_data())
		return
	
	var save_file = "user://profiles/%s.save" % user_id.md5_text()
	
	if not FileAccess.file_exists(save_file):
		print("📁 No saved profile found. Starting fresh.")
		user_loaded.emit(get_profile_data())
		return
	
	var file = FileAccess.open(save_file, FileAccess.READ)
	if file == null:
		push_error("Failed to load profile: " + str(FileAccess.get_open_error()))
		user_loaded.emit(get_profile_data())
		return
	
	var save_data = file.get_var()
	file.close()
	
	if typeof(save_data) != TYPE_DICTIONARY:
		push_warning("Invalid profile data. Starting fresh.")
		user_loaded.emit(get_profile_data())
		return
	
	# Load stats
	level = save_data.get("level", 1)
	total_xp = save_data.get("xp", 0)
	xp_to_next_level = save_data.get("xp_to_next", 100)
	high_score = save_data.get("high_score", 0)
	max_depth_reached = save_data.get("max_depth", 0)
	total_play_time = save_data.get("play_time", 0)
	runs_completed = save_data.get("runs_completed", 0)
	last_login = save_data.get("last_login", 0)
	hits_landed = save_data.get("hits", 0)
	
	# Check for returning player
	var time_since_last_login = Time.get_unix_time_from_system() - last_login
	if last_login > 0:
		var days_away = int(time_since_last_login / 86400)
		if days_away > 0:
			print("👋 Welcome back! You were away for %d day(s)" % days_away)
	
	profile_loaded.emit()
	user_loaded.emit(save_data)
	print("✅ Profile loaded: Level %d, High Score: %d" % [level, high_score])


# ===== ACCOUNT CONVERSION =====

func can_convert_guest_to_account() -> bool:
	"""Check if current user can convert from guest to registered account"""
	return login_type == "guest"


func request_account_conversion() -> void:
	"""Prompt guest to create a full account to save progress"""
	if not can_convert_guest_to_account():
		push_warning("User is not a guest - cannot convert")
		return
	
	print("💡 Guest account conversion requested")
	# This would trigger UI to show signup form
	# You could emit a signal here that the UI listens to


# ===== RESET FUNCTIONS =====

func reset_run_stats() -> void:
	"""Reset run-specific stats"""
	score = 0
	enemies_killed = 0
	depth = 0
	gems_collected = 0
	shots_fired = 0
	hits_landed = 0
	enemies_stomped = 0
	perfect_stomp_streak = 0
	accuracy = 0.0
	next_powerup_depth = powerup_interval
	
	if has_node("/root/ComboManagr"):
		var combo_mgr = get_node("/root/ComboManagr")
		if combo_mgr.has_method("reset_combo"):
			combo_mgr.reset_combo()
	
	runs_completed += 1
	session_start_time = Time.get_unix_time_from_system()
	
	print("🔄 Run stats reset (progression preserved)")
	stats_updated.emit()


func reset_profile() -> void:
	"""Complete profile reset"""
	level = 1
	total_xp = 0
	xp_to_next_level = 100
	high_score = 0
	max_depth_reached = 0
	total_play_time = 0
	runs_completed = 0
	last_login = 0
	hits_landed = 0
	
	reset_run_stats()
	
	if has_node("/root/ComboManagr"):
		var combo_mgr = get_node("/root/ComboManagr")
		if combo_mgr.has_method("reset_stats"):
			combo_mgr.reset_stats()
	
	print("🔄 Profile completely reset")
	stats_updated.emit()
	
	# Save the reset profile
	save_profile()


# ===== LEADERBOARD DATA =====

func get_leaderboard_entry() -> Dictionary:
	"""Get data for leaderboard submission"""
	return {
		"player_name": player_name,
		"email": email if login_type == "username" else "",
		"user_id": user_id if login_type != "guest" else "",
		"score": high_score,
		"level": level,
		"max_depth": max_depth_reached,
		"runs": runs_completed,
		"timestamp": Time.get_unix_time_from_system()
	}


# ===== DEBUG =====

func print_stats() -> void:
	print(get_stats_summary())
	if has_node("/root/ComboManagr"):
		var combo_mgr = get_node("/root/ComboManagr")
		if combo_mgr.has_method("print_debug_info"):
			combo_mgr.print_debug_info()


func print_user_info() -> void:
	"""Debug print user information"""
	var info = get_user_info()
	print("""
=== USER INFO ===
User ID: %s
Player Name: %s
Email: %s
Login Type: %s
Is Guest: %s
================
""" % [
		info.user_id,
		info.player_name,
		info.email if info.email != "" else "N/A",
		info.login_type,
		"Yes" if info.is_guest else "No"
	])
