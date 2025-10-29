extends CanvasLayer

@export var player_path: NodePath

@onready var heart_icon: TextureRect = $HBoxContainer/HeartIcon
@onready var life_label: Label = $HBoxContainer/NoOfLives
@onready var gem_icon: TextureRect = $HBoxContainer2/GemIcon
@onready var gem_label: Label = $HBoxContainer2/Label
@onready var bullet_icon: TextureRect = $HBoxContainer3/BulletIcon
@onready var bullet_count: Label = $HBoxContainer3/BulletCount
@onready var timer_label: Label = $TimerLabel


var player: Node = null
var elapsed_time: float = 0.0

func _ready():
	if player_path:
		player = get_node(player_path)
		if player:
			# connect signals
			player.health_changed.connect(_on_health_changed)
			player.player_died.connect(_on_player_died)
			
			if player.has_signal("gems_changed"):
				player.gems_changed.connect(_on_gems_changed)
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
	
	timer_label.text = "0:00:00"

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
