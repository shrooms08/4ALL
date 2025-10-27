extends Node
class_name ComboManager

# Downwell-style combo system
# Combos increase from kills and stomps, decay over time
# Higher combos = more score multiplier and special effects

# Combo settings
const COMBO_DECAY_TIME: float = 2.0  # Seconds before combo starts decaying
const COMBO_DECAY_RATE: float = 1.0  # Combos lost per second when decaying
const MAX_COMBO_STORAGE: int = 999  # Maximum combo count

# Current combo state
var current_combo: int = 0
var combo_decay_timer: float = 0.0
var is_decaying: bool = false

# Combo milestones (for visual/audio feedback)
const COMBO_TIERS = [0, 5, 10, 20, 30, 50, 100]
var current_tier: int = 0
var max_combo_reached: int = 0

# Score multipliers per combo tier
const TIER_MULTIPLIERS = {
	0: 1.0,   # 0-4 combo: 1x
	1: 1.5,   # 5-9 combo: 1.5x
	2: 2.0,   # 10-19 combo: 2x
	3: 2.5,   # 20-29 combo: 2.5x
	4: 3.0,   # 30-49 combo: 3x
	5: 4.0,   # 50-99 combo: 4x
	6: 5.0    # 100+ combo: 5x
}

# Signals
signal combo_gained(combo_count: int)
signal combo_lost(combo_count: int)
signal combo_tier_reached(tier: int)
signal combo_decaying(is_decay: bool)
signal combo_broken()

# Gem collection tracking
var gems_collected: int = 0
var gem_chain: int = 0  # Gems collected in quick succession
const GEM_CHAIN_TIME: float = 0.5
var gem_chain_timer: float = 0.0


func _ready() -> void:
	add_to_group("combo_manager")


func _process(delta: float) -> void:
	# Handle combo decay
	if current_combo > 0:
		combo_decay_timer -= delta
		
		# Start decaying
		if combo_decay_timer <= 0 and not is_decaying:
			is_decaying = true
			combo_decaying.emit(true)
		
		# Apply decay
		if is_decaying:
			var decay_amount = COMBO_DECAY_RATE * delta
			_remove_combo(decay_amount)
	
	# Handle gem chain timer
	if gem_chain > 0:
		gem_chain_timer -= delta
		if gem_chain_timer <= 0:
			gem_chain = 0


func add_combo(amount: int = 1) -> void:
	"""Add to combo (from kills, stomps, etc)"""
	current_combo += amount
	current_combo = mini(current_combo, MAX_COMBO_STORAGE)
	
	# Reset decay timer
	combo_decay_timer = COMBO_DECAY_TIME
	is_decaying = false
	combo_decaying.emit(false)
	
	# Track max combo
	if current_combo > max_combo_reached:
		max_combo_reached = current_combo
	
	# Check for tier change
	_check_tier_change()
	
	# Emit signal
	combo_gained.emit(current_combo)


func _remove_combo(amount: float) -> void:
	"""Internal function to remove combo"""
	var old_combo = current_combo
	current_combo -= int(amount)
	
	if current_combo <= 0:
		current_combo = 0
		is_decaying = false
		combo_decay_timer = 0.0
		combo_broken.emit()
		_check_tier_change()
	
	if old_combo != current_combo:
		combo_lost.emit(current_combo)
		_check_tier_change()


func reset_combo() -> void:
	"""Completely reset combo (for death, etc)"""
	if current_combo > 0:
		combo_broken.emit()
	
	current_combo = 0
	combo_decay_timer = 0.0
	is_decaying = false
	current_tier = 0
	gem_chain = 0
	gem_chain_timer = 0.0
	
	combo_lost.emit(0)
	combo_decaying.emit(false)


func refresh_combo() -> void:
	"""Reset decay timer without adding combo"""
	if current_combo > 0:
		combo_decay_timer = COMBO_DECAY_TIME
		if is_decaying:
			is_decaying = false
			combo_decaying.emit(false)


func _check_tier_change() -> void:
	"""Check if we've entered a new combo tier"""
	var new_tier = _get_tier_from_combo(current_combo)
	
	if new_tier != current_tier:
		current_tier = new_tier
		combo_tier_reached.emit(current_tier)


func _get_tier_from_combo(combo: int) -> int:
	"""Get tier index from combo count"""
	for i in range(COMBO_TIERS.size() - 1, -1, -1):
		if combo >= COMBO_TIERS[i]:
			return i
	return 0


# Combat actions
func register_kill() -> void:
	"""Called when player kills an enemy"""
	add_combo(1)


func register_stomp() -> void:
	"""Called when player stomps an enemy"""
	add_combo(1)


func register_shot_kill() -> void:
	"""Called when player kills with gun"""
	add_combo(1)


# Gem collection
func collect_gem(value: int) -> void:
	"""Called when player collects a gem"""
	gems_collected += value
	
	# Gem chains refresh combo timer
	refresh_combo()
	
	# Track gem chains (collecting multiple gems quickly)
	gem_chain_timer = GEM_CHAIN_TIME
	gem_chain += 1
	emit_signal("gems_changed", Gem)
	
	# Bonus combo for gem chains
	if gem_chain >= 5:
		add_combo(1)
		gem_chain = 0  # Reset chain


# Score multiplier system
func get_multiplier() -> float:
	"""Get current score multiplier based on combo tier"""
	return TIER_MULTIPLIERS.get(current_tier, 1.0)


func calculate_score(base_score: int) -> int:
	"""Calculate final score with multiplier"""
	return int(base_score * get_multiplier())


# Getters
func get_combo() -> int:
	return current_combo


func get_combo_tier() -> int:
	return current_tier


func get_max_combo() -> int:
	return max_combo_reached


func get_time_until_decay() -> float:
	return max(0.0, combo_decay_timer)


func is_combo_decaying() -> bool:
	return is_decaying


func get_gems_collected() -> int:
	return gems_collected


func get_gem_chain() -> int:
	return gem_chain


# Combo info for UI
func get_combo_info() -> Dictionary:
	return {
		"combo": current_combo,
		"tier": current_tier,
		"multiplier": get_multiplier(),
		"max_combo": max_combo_reached,
		"is_decaying": is_decaying,
		"time_remaining": get_time_until_decay(),
		"gems_collected": gems_collected,
		"gem_chain": gem_chain
	}


# Tier color (for UI)
func get_tier_color() -> Color:
	match current_tier:
		0: return Color.WHITE
		1: return Color(0.5, 1.0, 0.5)  # Light green
		2: return Color(0.3, 0.8, 1.0)  # Cyan
		3: return Color(1.0, 0.8, 0.3)  # Gold
		4: return Color(1.0, 0.5, 0.2)  # Orange
		5: return Color(1.0, 0.2, 0.5)  # Pink
		6: return Color(1.0, 0.2, 1.0)  # Magenta
		_: return Color.WHITE


# Reset for new game
func reset_stats() -> void:
	reset_combo()
	gems_collected = 0
	max_combo_reached = 0
