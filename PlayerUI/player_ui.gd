extends CanvasLayer

@export var player_path: NodePath

@onready var heart_icon: TextureRect = $HBoxContainer/HeartIcon
@onready var life_label: Label = $HBoxContainer/NoOfLives
@onready var gem_icon: TextureRect = $HBoxContainer2/GemIcon
@onready var gem_label: Label = $HBoxContainer2/Label
@onready var bullet_icon: TextureRect = $HBoxContainer3/BulletIcon
@onready var bullet_count: Label = $HBoxContainer3/BulletCount
@onready var timer_label: Label = $TimerLabel

# Viewer interaction notification
var notification_label: Label = null
var notification_queue: Array = []
var notification_showing: bool = false

var player: Node = null
var elapsed_time: float = 0.0

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
