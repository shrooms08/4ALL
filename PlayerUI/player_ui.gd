extends CanvasLayer

@export var player_path: NodePath

@onready var heart_icon: TextureRect = $HBoxContainer/HeartIcon
@onready var life_label: Label = $HBoxContainer/NoOfLives
@onready var gem_icon: TextureRect = $HBoxContainer2/GemIcon
@onready var gem_label: Label = $HBoxContainer2/Label
@onready var bullet_icon: TextureRect = $HBoxContainer3/BulletIcon
@onready var bullet_count: Label = $HBoxContainer3/BulletCount
@onready var timer_label: Label = $TimerLabel
@onready var username_label: Label = $SessionInfo/UsernameLabel
@onready var coins_label: Label = $SessionInfo/CoinsLabel
@onready var score_label: Label = $SessionInfo/ScoreLabel
@onready var kills_label: Label = $SessionInfo/KillsLabel
@onready var depth_label: Label = $SessionInfo/DepthLabel
@onready var arena_status_label: Label = $SessionInfo/ArenaStatusLabel
@onready var server_status_label: Label = $SessionInfo/ServerStatusLabel

# Viewer interaction notification
var notification_label: Label = null
var notification_queue: Array = []
var notification_showing: bool = false
var server_status_tween: Tween = null

var player: Node = null
var elapsed_time: float = 0.0
var viewer_manager: Node = null

func _ready():
	if player_path:
		player = get_node(player_path)
		if player:
			# connect signals
			player.health_changed.connect(_on_health_changed)
			player.player_died.connect(_on_player_died)
			
			
			if player.has_signal("ammo_changed"):
				player.ammo_changed.connect(_on_ammo_changed)
			
			# initialize displays
			_update_life_display(player.current_health)
			_on_gems_changed(0)
			
			# Initialize with actual ammo values from player
			if "current_ammo" in player and "max_ammo" in player:
				print("PlayerUI: Initializing ammo - current: %d, max: %d" % [player.current_ammo, player.max_ammo])
				_on_ammo_changed(player.current_ammo, player.max_ammo)
			else:
				print("PlayerUI: Warning - player missing ammo properties!")
				_on_ammo_changed(0, 0)
		else:
			print("PlayerUI: ERROR - Could not find player at path: ", player_path)
	else:
		print("PlayerUI: ERROR - No player_path set!")
	
	# Connect to ComboManager for gem tracking
	if ComboManagr:
		ComboManagr.gems_collected_chnaged.connect(_on_gems_changed)
		_on_gems_changed(ComboManagr.get_total_gems())
	else:
		print("PlayerUI: Error - ComboMananger not found!")
		_on_gems_changed(0)
	
	timer_label.text = "0:00:00"
	
	# Create notification label
	_setup_notification_label()
	add_to_group("player_ui")
	_update_session_info()
	_connect_game_manager()
	call_deferred("_connect_viewer_manager")

func _setup_notification_label() -> void:
	"""Create a label for viewer interaction notifications"""
	notification_label = Label.new()
	notification_label.name = "ViewerNotification"
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification_label.position = Vector2(0, 200)
	notification_label.size = Vector2(1152, 100)
	notification_label.add_theme_font_size_override("font_size", 32)
	notification_label.modulate = Color(1, 1, 1, 0)
	notification_label.z_index = 100
	add_child(notification_label)
	if server_status_label:
		server_status_label.visible = false
		server_status_label.modulate = Color.WHITE

func _process(delta: float) -> void:
	if player and player.is_inside_tree() and not get_tree().paused:
		elapsed_time += delta
		timer_label.text = _format_time(elapsed_time)

func _format_time(seconds: float) -> String:
	var m = int(seconds) / 60
	var s = int(seconds) % 60
	return "%d:%02d" % [m, s]

# -- Health --
func _on_health_changed(new_health: int) -> void:
	_update_life_display(new_health)

func _on_player_died() -> void:
	life_label.text = "0"
	heart_icon.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.3).timeout
	heart_icon.modulate = Color(1, 1, 1)

func _update_life_display(health: int) -> void:
	life_label.text = str(health)

# -- Gems --
func _on_gems_changed(new_count: int) -> void:
	gem_label.text = str(new_count)

# -- Bullets --
func _on_ammo_changed(current: int, max: int) -> void:
	# show only current bullets if you prefer the Downwell minimal look
	bullet_count.text = "%d" % [current]


func set_timer_visible(visible: bool) -> void:
	if timer_label:
		timer_label.visible = visible

# Viewer Interaction Notifications

func show_notification(text: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	"""Show a notification about viewer interaction"""
	notification_queue.append({"text": text, "color": color, "duration": duration})
	
	if not notification_showing:
		_show_next_notification()

func _show_next_notification() -> void:
	if notification_queue.is_empty():
		notification_showing = false
		return
	
	notification_showing = true
	var notif = notification_queue.pop_front()
	
	if not notification_label:
		notification_showing = false
		return
	
	notification_label.text = notif.text
	notification_label.modulate = notif.color
	notification_label.modulate.a = 0
	
	# Fade in
	var tween = create_tween()
	tween.tween_property(notification_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(notif.duration)
	tween.tween_property(notification_label, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	_show_next_notification()

func _connect_game_manager() -> void:
	if not Engine.has_singleton("GameManager"):
		return
	var gm = GameManager
	if not gm:
		return
	if gm.has_signal("stats_updated") and not gm.stats_updated.is_connected(_on_stats_updated):
		gm.stats_updated.connect(_on_stats_updated)
	if gm.has_signal("profile_updated") and not gm.profile_updated.is_connected(_on_profile_updated):
		gm.profile_updated.connect(_on_profile_updated)
	if gm.has_signal("server_sync_failed") and not gm.server_sync_failed.is_connected(_on_server_sync_failed):
		gm.server_sync_failed.connect(_on_server_sync_failed)
	if gm.has_signal("server_sync_succeeded") and not gm.server_sync_succeeded.is_connected(_on_server_sync_succeeded):
		gm.server_sync_succeeded.connect(_on_server_sync_succeeded)

func _connect_viewer_manager() -> void:
	var managers = get_tree().get_nodes_in_group("viewer_manager")
	if managers.size() == 0:
		return
	viewer_manager = managers[0]
	if viewer_manager.has_signal("arena_countdown_started") and not viewer_manager.arena_countdown_started.is_connected(_on_arena_countdown_started):
		viewer_manager.arena_countdown_started.connect(_on_arena_countdown_started)
	if viewer_manager.has_signal("arena_live") and not viewer_manager.arena_live.is_connected(_on_arena_live):
		viewer_manager.arena_live.connect(_on_arena_live)
	if viewer_manager.has_signal("viewer_boost_received") and not viewer_manager.viewer_boost_received.is_connected(_on_viewer_boost_received):
		viewer_manager.viewer_boost_received.connect(_on_viewer_boost_received)
	if viewer_manager.has_signal("countdown_update") and not viewer_manager.countdown_update.is_connected(_on_countdown_update):
		viewer_manager.countdown_update.connect(_on_countdown_update)

func _update_session_info() -> void:
	if not Engine.has_singleton("GameManager"):
		return
	var gm = GameManager
	if not gm:
		return

	username_label.text = gm.player_name

	var coins = gm.profile.get("arenaCoins") if gm.profile else null
	if coins == null:
		coins_label.text = "Coins: --"
	else:
		coins_label.text = "Coins: %s" % str(coins)

	score_label.text = "Score: %d" % gm.score
	kills_label.text = "Kills: %d" % gm.enemies_killed
	depth_label.text = "Depth: %d" % gm.depth

func _on_stats_updated() -> void:
	_update_session_info()

func _on_profile_updated(profile: Dictionary) -> void:
	_update_session_info()

func _on_server_sync_failed(message: String) -> void:
	_show_server_status("Sync failed: %s" % message, Color(1, 0.4, 0.4), 4.0)

func _on_server_sync_succeeded(timestamp: int) -> void:
	var dt = Time.get_datetime_dict_from_unix_time(timestamp)
	var formatted := "%02d:%02d:%02d" % [int(dt.hour), int(dt.minute), int(dt.second)]
	_show_server_status("Last sync: %s" % formatted, Color(0.6, 1.0, 0.6), 2.5)

func _show_server_status(message: String, color: Color, duration: float = 3.0) -> void:
	if not server_status_label:
		return
	server_status_label.text = message
	server_status_label.modulate = color
	server_status_label.visible = true

	if server_status_tween:
		server_status_tween.kill()
	server_status_tween = create_tween()
	server_status_tween.tween_interval(duration)
	server_status_tween.tween_callback(Callable(self, "_clear_server_status"))

func _clear_server_status() -> void:
	server_status_tween = null
	if server_status_label:
		server_status_label.visible = false
		server_status_label.text = ""

func _on_arena_countdown_started(seconds: int) -> void:
	if arena_status_label:
		arena_status_label.text = "Arena: Countdown %ds" % seconds

func _on_countdown_update(seconds_remaining: int) -> void:
	if arena_status_label:
		arena_status_label.text = "Arena: %ds remain" % seconds_remaining

func _on_arena_live() -> void:
	if arena_status_label:
		arena_status_label.text = "Arena: LIVE"
		show_notification("ARENA LIVE! Viewers can interact!", Color.GREEN_YELLOW, 3.0)

func _on_viewer_boost_received(booster: String, amount: int, coins: int) -> void:
	show_notification("%s boosted you! (+%d)" % [booster, amount], Color.CYAN, 2.5)
	#_acknowledge_event("player_boost", {
		#"booster": booster,
		#"amount": amount,
		#"coins": coins
	#})
