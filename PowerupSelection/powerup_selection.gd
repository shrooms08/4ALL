extends CanvasLayer

signal powerup_chosen(powerup_instance)
signal voting_started
signal voting_ended

# UI References
@onready var panel: Panel = $Panel
@onready var label_title: Label = $Panel/VBoxContainer/Label
@onready var vote_label: Label = $Panel/VBoxContainer/VoteLabel
@onready var timer_bar: ProgressBar = $Panel/VBoxContainer/TimerBar
@onready var cards: Array[Button] = [
	$Panel/VBoxContainer/HBoxContainer/PowerupCard1,
	$Panel/VBoxContainer/HBoxContainer/PowerupCard2,
	$Panel/VBoxContainer/HBoxContainer/PowerupCard3
]

# Audio
@onready var audio_open: AudioStreamPlayer = $Audio/Open
@onready var audio_vote: AudioStreamPlayer = $Audio/Vote
@onready var audio_select: AudioStreamPlayer = $Audio/Select

# Configuration
@export var voting_duration: float = 5.0
@export var announce_duration: float = 2.0
@export var powerup_count: int = 3
@export var allow_manual_override: bool = true  # Let player choose if no audience

# Powerup Database
var all_powerups: Array[Dictionary] = [
	{
		"name": "Full Heal",
		"desc": "Restores all lost health.",
		"effect": "restore_health_full",
		"icon": "res://icons/heal.png",
		"rarity": "common"
	},
	{
		"name": "Rapid Fire",
		"desc": "Triple bullets, 30s duration.",
		"effect": "rapid_fire_bullet",
		"icon": "res://icons/rapid.png",
		"rarity": "rare"
	},
	{
		"name": "Piercing Shot",
		"desc": "Bullets go through enemies.",
		"effect": "piercing_bullet",
		"icon": "res://icons/pierce.png",
		"rarity": "rare"
	},
	{
		"name": "Speed Boost",
		"desc": "Move 20% faster permanently.",
		"effect": "speed_boost",
		"icon": "res://icons/speed.png",
		"rarity": "uncommon"
	},
	{
		"name": "Gem Magnet",
		"desc": "Pull nearby gems automatically.",
		"effect": "magnet",
		"icon": "res://icons/magnet.png",
		"rarity": "common"
	},
	{
		"name": "Extra Heart",
		"desc": "Increase max HP by 1.",
		"effect": "extra_heart",
		"icon": "res://icons/heart.png",
		"rarity": "uncommon"
	}
]

# Powerup script mappings
const POWERUP_MAP = {
	"restore_health_full": preload("res://Powerups/powerup_restore_health_full.gd"),
	# Add more as you create them:
	# "rapid_fire_bullet": preload("res://Powerups/powerup_rapid_fire.gd"),
	# "piercing_bullet": preload("res://Powerups/powerup_piercing.gd"),
	# "speed_boost": preload("res://Powerups/powerup_speed_boost.gd"),
	# "magnet": preload("res://Powerups/powerup_magnet.gd"),
	# "extra_heart": preload("res://Powerups/powerup_extra_heart.gd"),
}

# State
var current_choices: Array[Dictionary] = []
var vote_counts: Array[int] = [0, 0, 0]
var is_voting: bool = false
var voting_timer: float = 0.0
var has_audience: bool = false  # Check if streaming/audience present


func _ready() -> void:
	# CRITICAL: Allow processing while game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	hide()
	
	# Connect card buttons
	for i in range(cards.size()):
		if cards[i]:
			cards[i].pressed.connect(_on_card_pressed.bind(i))
	
	# Check for audience (placeholder - integrate with your streaming API)
	_check_audience_status()
	
	# Hide timer bar initially
	if timer_bar:
		timer_bar.visible = false


func _process(delta: float) -> void:
	if is_voting and voting_timer > 0:
		voting_timer -= delta
		
		# Update timer bar
		if timer_bar:
			timer_bar.value = (voting_timer / voting_duration) * 100
		
		# Simulate audience votes (replace with real API calls)
		if has_audience:
			_simulate_audience_votes(delta)
		
		# Time's up
		if voting_timer <= 0:
			_finish_voting()


func show_powerup_selection() -> void:
	"""Main entry point - show powerup selection UI"""
	print("🎁 Opening powerup selection...")
	
	# Pause gameplay
	get_tree().paused = true
	
	# Show UI
	show()
	if panel:
		panel.show()
	
	# Play open sound
	if audio_open:
		audio_open.play()
	
	# Generate random powerups
	current_choices = _get_random_powerups(powerup_count)
	vote_counts = [0, 0, 0]
	
	# Update card UI
	_update_card_displays()
	
	# Start voting process
	if has_audience:
		_start_audience_vote()
	else:
		_start_manual_selection()


func _get_random_powerups(count: int) -> Array[Dictionary]:
	"""Select random powerups, weighted by rarity"""
	var pool = all_powerups.duplicate()
	pool.shuffle()
	
	# TODO: Add rarity weighting (common more likely than rare)
	return pool.slice(0, min(count, pool.size()))


func _update_card_displays() -> void:
	"""Update button text and visuals for each powerup"""
	for i in range(cards.size()):
		if i >= current_choices.size():
			cards[i].visible = false
			continue
		
		var data = current_choices[i]
		cards[i].visible = true
		
		# Format button text
		var rarity_emoji = _get_rarity_emoji(data.get("rarity", "common"))
		cards[i].text = "%s %s\n%s" % [rarity_emoji, data["name"], data["desc"]]
		
		# Optional: Set icon if available
		# if data.has("icon"):
		#     cards[i].icon = load(data["icon"])
		
		# Reset visual state
		cards[i].modulate = Color.WHITE
		
		# Disable if audience voting
		cards[i].disabled = has_audience and not allow_manual_override


func _get_rarity_emoji(rarity: String) -> String:
	match rarity:
		"common": return "⚪"
		"uncommon": return "🟢"
		"rare": return "🔵"
		"epic": return "🟣"
		"legendary": return "🟡"
		_: return "⚪"


func _start_audience_vote() -> void:
	"""Start audience voting countdown"""
	is_voting = true
	voting_timer = voting_duration
	
	label_title.text = "Audience is Voting!"
	vote_label.text = "Cast your votes now..."
	
	if timer_bar:
		timer_bar.visible = true
		timer_bar.max_value = 100
		timer_bar.value = 100
	
	voting_started.emit()
	
	# In real implementation, send API call to start Twitch poll
	# TwitchAPI.start_poll(current_choices, voting_duration)


func _start_manual_selection() -> void:
	"""Let player choose directly (no audience)"""
	is_voting = false
	
	label_title.text = "Choose Your Powerup"
	vote_label.text = "Click a card to select"
	
	if timer_bar:
		timer_bar.visible = false
	
	# Enable all cards
	for card in cards:
		card.disabled = false


func _simulate_audience_votes(delta: float) -> void:
	"""Simulate audience votes (replace with real API)"""
	# Random votes every 0.3 seconds
	var random_vote_chance = delta * 3.0  # ~3 votes per second
	
	if randf() < random_vote_chance:
		var card_index = randi() % current_choices.size()
		vote_counts[card_index] += 1
		_update_vote_display()


func _update_vote_display() -> void:
	"""Show current vote counts on cards"""
	var total_votes = vote_counts.reduce(func(sum, val): return sum + val, 0)
	
	for i in range(cards.size()):
		if i >= vote_counts.size():
			continue
		
		var votes = vote_counts[i]
		var percentage = (float(votes) / max(total_votes, 1)) * 100.0
		
		# Highlight leading choice
		if votes > 0 and votes == vote_counts.max():
			cards[i].modulate = Color(1.2, 1.2, 0.8)  # Gold tint
		else:
			cards[i].modulate = Color.WHITE
	
	# Update label
	vote_label.text = "Votes: %d | %d | %d" % [vote_counts[0], vote_counts[1], vote_counts[2]]


func _finish_voting() -> void:
	"""Determine winner and apply powerup"""
	is_voting = false
	
	if timer_bar:
		timer_bar.visible = false
	
	# Find winning powerup
	var winner_index = _get_winning_index()
	var chosen = current_choices[winner_index]
	
	_announce_winner(chosen, winner_index)


func _get_winning_index() -> int:
	"""Get index of powerup with most votes"""
	var max_votes = vote_counts.max()
	var winners = []
	
	for i in range(vote_counts.size()):
		if vote_counts[i] == max_votes:
			winners.append(i)
	
	# Random tiebreaker
	return winners[randi() % winners.size()]


func _announce_winner(chosen: Dictionary, index: int) -> void:
	"""Show winning powerup and apply it"""
	print("🏆 Winner: ", chosen["name"])
	
	# Visual feedback
	label_title.text = "Winner!"
	vote_label.text = "✨ %s ✨" % chosen["name"]
	
	# Highlight winning card
	for i in range(cards.size()):
		cards[i].modulate = Color.DIM_GRAY if i != index else Color.GOLD
	
	# Play selection sound
	if audio_select:
		audio_select.play()
	
	# Create powerup instance
	var powerup_instance = _create_powerup_instance(chosen["effect"])
	
	voting_ended.emit()
	powerup_chosen.emit(powerup_instance)
	
	# Close UI after delay
	await get_tree().create_timer(announce_duration).timeout
	_close_selection()


func _create_powerup_instance(effect_id: String):
	"""Instantiate the powerup script"""
	if POWERUP_MAP.has(effect_id):
		return POWERUP_MAP[effect_id].new()
	else:
		push_warning("⚠️ No script found for effect: %s" % effect_id)
		return null


func _on_card_pressed(index: int) -> void:
	"""Handle manual card selection"""
	if is_voting and not allow_manual_override:
		print("Cannot manually select during audience vote")
		return
	
	if index >= current_choices.size():
		return
	
	# Play vote sound
	if audio_vote:
		audio_vote.play()
	
	var chosen = current_choices[index]
	
	if has_audience:
		# Count as a vote
		vote_counts[index] += 1
		_update_vote_display()
	else:
		# Immediate selection
		_announce_winner(chosen, index)


func _close_selection() -> void:
	"""Hide UI and resume game"""
	hide()
	get_tree().paused = false
	print("Powerup selection closed")


func _check_audience_status() -> void:
	"""Check if audience/streaming is active (placeholder)"""
	# TODO: Integrate with Twitch API or your streaming solution
	# For now, simulate based on some condition
	has_audience = false  # Set to true when streaming
	
	# Example:
	# if TwitchAPI.is_connected() and TwitchAPI.viewer_count > 0:
	#     has_audience = true


# Public API

func set_has_audience(value: bool) -> void:
	"""Externally set audience status"""
	has_audience = value
	print("Audience mode: ", "ENABLED" if has_audience else "DISABLED")


func add_custom_powerup(data: Dictionary) -> void:
	"""Add a custom powerup to the pool at runtime"""
	all_powerups.append(data)


func get_available_powerups() -> Array[Dictionary]:
	"""Get list of all powerups"""
	return all_powerups.duplicate()
