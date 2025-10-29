extends CanvasLayer

# Node references - Downwell Style
@onready var pause_panel: Panel = $Panel
@onready var resume_button: Button = $Panel/VBoxContainer/Resume
@onready var retry_button: Button = $Panel/VBoxContainer/Retry
@onready var stats_button: Button = $Panel/VBoxContainer/Stats
@onready var options_button: Button = $Panel/VBoxContainer/Option

# Stats Panel
@onready var stats_panel: Panel = $StatsPanel
@onready var stats_back_button: Button = $StatsPanel/StatsBackButton
@onready var stats: Label = $StatsPanel/VBoxContainer/STATS
@onready var score_label: Label = $StatsPanel/VBoxContainer/ScoreLabel
@onready var enemies_label: Label = $StatsPanel/VBoxContainer/EnemiesLabel
@onready var gems_label: Label = $StatsPanel/VBoxContainer/GemsLabel
@onready var depth_label: Label = $StatsPanel/VBoxContainer/DepthLabel



# Options Panel
@onready var options_panel: Panel = $OptionsPanel
@onready var options_back_button: Button = $OptionsPanel/OptionsBackButton
@onready var music_toggle: CheckButton = $OptionsPanel/VBoxContainer/MusicToggle
@onready var timer_toggle: CheckButton = $OptionsPanel/VBoxContainer/TimerToggle

# States for toggles
var music_enabled: bool = true
var timer_enabled: bool = true

# State
var is_paused = false
var can_pause = true
var current_panel = "main"  # "main", "stats", "options"

# Audio bus indices
var master_bus_idx: int
var music_bus_idx: int
var sfx_bus_idx: int

# Stats tracking
var game_start_time: int = 0
var session_start_time: int = 0


func _ready() -> void:
	# Hide everything initially
	hide()
	pause_panel.hide()
	stats_panel.hide()
	options_panel.hide()
	
	# Get audio bus indices
	master_bus_idx = AudioServer.get_bus_index("Master")
	music_bus_idx = AudioServer.get_bus_index("Music")
	sfx_bus_idx = AudioServer.get_bus_index("SFX")
	
	# Connect button signals
	_connect_signals()
	
	# Load saved audio settings
	#_load_audio_settings()
	
	# Setup initial focus
	resume_button.grab_focus()
	
	# Ensure process mode allows pausing
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Track game start time
	session_start_time = Time.get_ticks_msec()
	game_start_time = session_start_time


func _connect_signals() -> void:
	# Main menu buttons
	resume_button.pressed.connect(_on_resume_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	stats_button.pressed.connect(_on_stats_pressed)
	options_button.pressed.connect(_on_options_pressed)
	
	# Panel back buttons
	stats_back_button.pressed.connect(_on_back_to_main)
	options_back_button.pressed.connect(_on_back_to_main)
	
	## Audio sliders
	#master_slider.value_changed.connect(_on_master_volume_changed)
	#music_slider.value_changed.connect(_on_music_volume_changed)
	#sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	## Button hover effects
	#for button in _get_all_buttons():
		#button.mouse_entered.connect(_on_button_hover)
		#button.focus_entered.connect(_on_button_hover)
		#button.pressed.connect(_play_select_sound)


func _get_all_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	buttons.append_array([
		resume_button, retry_button, stats_button, options_button,
		stats_back_button, options_back_button
	])
	return buttons


func _unhandled_input(event: InputEvent) -> void:
	# Toggle pause with ESC or START button
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if can_pause:
			if is_paused and current_panel != "main":
				# If in sub-panel, go back to main
				_on_back_to_main()
			else:
				# Toggle pause
				toggle_pause()
			get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if is_paused:
		unpause()
	else:
		pause()


func pause() -> void:
	if is_paused:
		return
	
	is_paused = true
	get_tree().paused = true
	
	## Play pause sound
	#if pause_sound:
		#pause_sound.play()
	
	# Show main panel
	_show_panel("main")
	show()
	
	# Focus first button
	resume_button.grab_focus()


func unpause() -> void:
	if not is_paused:
		return
	
	is_paused = false
	current_panel = "main"
	
	## Play unpause sound
	#if unpause_sound:
		#unpause_sound.play()
	
	get_tree().paused = false
	hide()
	pause_panel.hide()
	stats_panel.hide()
	options_panel.hide()


func _show_panel(panel_name: String) -> void:
	current_panel = panel_name
	
	# Hide all panels
	pause_panel.hide()
	stats_panel.hide()
	options_panel.hide()
	
	# Show requested panel
	match panel_name:
		"main":
			pause_panel.show()
			resume_button.grab_focus()
		"stats":
			_update_stats()
			stats_panel.show()
			stats_back_button.grab_focus()
		"options":
			options_panel.show()
			options_back_button.grab_focus()


# Button callbacks
func _on_resume_pressed() -> void:
	unpause()


func _on_retry_pressed() -> void:
	unpause()
	# Reset game start time
	game_start_time = Time.get_ticks_msec()
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().reload_current_scene()


func _on_stats_pressed() -> void:
	_show_panel("stats")


func _on_options_pressed() -> void:
	_show_panel("options")


func _on_back_to_main() -> void:
	_show_panel("main")


# Sound effects
#func _on_button_hover() -> void:
	#if hover_sound:
		#hover_sound.play()


#func _play_select_sound() -> void:
	#if select_sound:
		#select_sound.play()


# Stats System (Downwell-style)
func _update_stats() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	var player = get_tree().get_first_node_in_group("player")

	if timer_enabled:
		var elapsed_ms = Time.get_ticks_msec() - game_start_time
		var elapsed_sec = elapsed_ms / 1000.0
		var minutes = int(elapsed_sec / 60)
		var seconds = int(elapsed_sec) % 60
		stats.text = "TIME: %02d:%02d" % [minutes, seconds]
	else:
		stats.text = "TIME: --:--"

	if game_manager:
		score_label.text = "SCORE: %d" % game_manager.score
		enemies_label.text = "KILLS: %d" % game_manager.enemies_killed
		gems_label.text = "GEMS: %d" % game_manager.gems_collected
		depth_label.text = "DEPTH: %dm" % game_manager.depth

	if player:
		score_label.text += " | HEALTH: %d" % player.current_health




func _add_stat(stat_name: String, stat_value: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	
	var name_label = Label.new()
	name_label.text = stat_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	var value_label = Label.new()
	value_label.text = stat_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", Color(1, 1, 0.5))  # Yellow tint
	
	hbox.add_child(name_label)
	hbox.add_child(value_label)



# Audio Settings
#func _on_master_volume_changed(value: float) -> void:
	#_set_bus_volume(master_bus_idx, value)
	#master_label.text = "MASTER %d%%" % int(value)
	#_save_audio_settings()

#
#func _on_music_volume_changed(value: float) -> void:
	#_set_bus_volume(music_bus_idx, value)
	#music_label.text = "MUSIC %d%%" % int(value)
	#_save_audio_settings()


#func _on_sfx_volume_changed(value: float) -> void:
	#_set_bus_volume(sfx_bus_idx, value)
	#sfx_label.text = "SFX %d%%" % int(value)
	#_save_audio_settings()


func _set_bus_volume(bus_idx: int, value: float) -> void:
	if value <= 0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		var db = linear_to_db(value / 100.0)
		AudioServer.set_bus_volume_db(bus_idx, db)

func _on_music_toggled(pressed: bool) -> void:
	music_enabled = pressed
	music_toggle.text = "Music: " + ("On" if pressed else "Off")

	# Find background music (you probably added it in PlayScene)
	var music_player = get_tree().get_first_node_in_group("background_music")
	if music_player:
		music_player.playing = pressed  # Turn on/off

	print("Music toggled:", pressed)


func _on_timer_toggled(pressed: bool) -> void:
	timer_enabled = pressed
	timer_toggle.text = "Timer: " + ("On" if pressed else "Off")

	var player_ui = get_tree().get_first_node_in_group("player_ui")
	if player_ui:
		player_ui.set_timer_visible(pressed)




#func _save_audio_settings() -> void:
	#var config = ConfigFile.new()
	#config.set_value("audio", "master_volume", master_slider.value)
	#config.set_value("audio", "music_volume", music_slider.value)
	#config.set_value("audio", "sfx_volume", sfx_slider.value)
	#config.save("user://settings.cfg")


#func _load_audio_settings() -> void:
	#var config = ConfigFile.new()
	#var err = config.load("user://settings.cfg")
	#
	#if err != OK:
		#master_slider.value = 100
		#music_slider.value = 80
		#sfx_slider.value = 100
		#return
	#
	#master_slider.value = config.get_value("audio", "master_volume", 100)
	#music_slider.value = config.get_value("audio", "music_volume", 80)
	#sfx_slider.value = config.get_value("audio", "sfx_volume", 100)
	#
	#_on_master_volume_changed(master_slider.value)
	#_on_music_volume_changed(music_slider.value)
	#_on_sfx_volume_changed(sfx_slider.value)


# Public methods
func disable_pause() -> void:
	can_pause = false


func enable_pause() -> void:
	can_pause = true


func reset_game_timer() -> void:
	game_start_time = Time.get_ticks_msec()
