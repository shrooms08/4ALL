extends Node
class_name ComboManager

# Downwell-style combo system
# Combos increase from kills and stomps, decay over time
# Higher combos = more score multiplier and special effects

# Combo settings
@export var combo_decay_time: float = 2.0  # Seconds before combo starts decaying
@export var combo_decay_rate: float = 1.0  # Combos lost per second when decaying
@export var max_combo_storage: int = 999  # Maximum combo count

# Current combo state
var current_combo: int = 0
var combo_decay_timer: float = 0.0
var is_decaying: bool = false

# Combo milestones (for visual/audio feedback)
const COMBO_TIERS: Array[int] = [0, 5, 10, 20, 30, 50, 100]
var current_tier: int = 0
var max_combo_reached: int = 0

# Score multipliers per combo tier
const TIER_MULTIPLIERS: Dictionary = {
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
signal combo_broken
signal combo_milestone_reached(milestone: int)  # For special milestones
signal gems_collected_chnaged(total_gems: int)
# Gem collection tracking
var gem_chain: int = 0  # Gems collected in quick succession
var gem_chain_timer: float = 0.0
const GEM_CHAIN_TIME: float = 0.5
const GEM_CHAIN_COMBO_THRESHOLD: int = 5  # Gems needed for bonus combo

# Action tracking for analytics
var total_kills: int = 0
var total_stomps: int = 0
var total_shot_kills: int = 0
var total_gems_collcted: int = 0

func _ready() -> void:
	add_to_group("combo_manager")
	print("ComboManager initialized!")


func _process(delta: float) -> void:
	# Handle combo decay
	if current_combo > 0:
		combo_decay_timer -= delta
		
		# Start decaying when timer expires
		if combo_decay_timer <= 0 and not is_decaying:
			_start_decay()
		
		# Apply decay
		if is_decaying:
			var decay_amount = combo_decay_rate * delta
			_remove_combo(decay_amount)
	
	# Handle gem chain timer
	if gem_chain > 0:
		gem_chain_timer -= delta
		if gem_chain_timer <= 0:
			_reset_gem_chain()


# === Combo Management ===



func add_combo(amount: int = 1) -> void:
	"""Add to combo (from kills, stomps, etc)"""
	var old_combo = current_combo
	current_combo += amount
	current_combo = min(current_combo, max_combo_storage)
	
	# Reset decay timer
	combo_decay_timer = combo_decay_time
	
	# Stop decay if it was active
	if is_decaying:
		_stop_decay()
	
	# Track max combo
	if current_combo > max_combo_reached:
		max_combo_reached = current_combo
	
	# Check for tier change
	_check_tier_change()
	
	# Check for milestones
	_check_milestones(old_combo, current_combo)
	
	# Emit signal
	emit_signal("combo_gained", current_combo)
	
	print("Combo: ", current_combo, " (Tier ", current_tier, " | ", get_multiplier(), "x)")


func _remove_combo(amount: float) -> void:
	"""Internal function to remove combo"""
	var old_combo = current_combo
	var old_tier = current_tier
	
	current_combo -= int(amount)
	
	# Combo completely broken
	if current_combo <= 0:
		_break_combo()
		return
	
	# Emit loss signal if changed
	if old_combo != current_combo:
		emit_signal("combo_lost", current_combo)
		_check_tier_change()


func reset_combo() -> void:
	"""Completely reset combo (for death, etc)"""
	if current_combo > 0:
		print("Combo reset at:", current_combo)
		emit_signal("combo_broken")
	
	current_combo = 0
	combo_decay_timer = 0.0
	is_decaying = false
	current_tier = 0
	
	_reset_gem_chain()
	
	emit_signal("combo_lost", 0)
	emit_signal("combo_decaying", false)


func refresh_combo() -> void:
	"""Reset decay timer without adding combo (for gem collection)"""
	if current_combo > 0:
		combo_decay_timer = combo_decay_time
		if is_decaying:
			_stop_decay()


func _start_decay() -> void:
	"""Begin combo decay"""
	is_decaying = true
	emit_signal("combo_decaying", true)
	print("Combo decaying...")


func _stop_decay() -> void:
	"""Stop combo decay"""
	is_decaying = false
	emit_signal("combo_decaying", false)


func _break_combo() -> void:
	"""Handle combo breaking completely"""
	print("Combo broken at:", current_combo)
	
	current_combo = 0
	combo_decay_timer = 0.0
	is_decaying = false
	
	var old_tier = current_tier
	current_tier = 0
	
	emit_signal("combo_broken")
	emit_signal("combo_lost", 0)
	emit_signal("combo_decaying", false)
	
	if old_tier != 0:
		emit_signal("combo_tier_reached", 0)


# === Tier System ===

func _check_tier_change() -> void:
	"""Check if we've entered a new combo tier"""
	var new_tier = _get_tier_from_combo(current_combo)
	
	if new_tier != current_tier:
		var old_tier = current_tier
		current_tier = new_tier
		emit_signal("combo_tier_reached", current_tier)
		
		if new_tier > old_tier:
			print("Combo Tier UP:", current_tier, " (", get_multiplier(), "x multiplier)")
		else:
			print("Combo Tier DOWN:", current_tier)


func _get_tier_from_combo(combo: int) -> int:
	"""Get tier index from combo count"""
	for i in range(COMBO_TIERS.size() - 1, -1, -1):
		if combo >= COMBO_TIERS[i]:
			return i
	return 0


func _check_milestones(old_combo: int, new_combo: int) -> void:
	"""Check if special milestones were reached"""
	const MILESTONES = [10, 25, 50, 100, 200, 500]
	
	for milestone in MILESTONES:
		if old_combo < milestone and new_combo >= milestone:
			emit_signal("combo_milestone_reached", milestone)
			print("Combo milestone:", milestone, "!")


# === Combat Actions ===

func register_kill() -> void:
	"""Called when player kills an enemy (any method)"""
	total_kills += 1
	add_combo(1)


func register_stomp() -> void:
	"""Called when player stomps an enemy"""
	total_stomps += 1
	total_kills += 1
	add_combo(1)  # Stomps give combo
	print("Stomp registered! Combo:", current_combo)


func register_shot_kill() -> void:
	"""Called when player kills with gun"""
	total_shot_kills += 1
	total_kills += 1
	add_combo(1)


# === Gem Collection ===

func collect_gem(value: int = 1) -> void:
	"""Called when player collects a gem"""
	
	# Track total gems
	total_gems_collcted += value
	gems_collected_chnaged.emit(total_gems_collcted)
	
	# Gem collection refreshes combo timer (prevents decay)
	refresh_combo()
	
	# Track gem chains (collecting multiple gems quickly)
	gem_chain_timer = GEM_CHAIN_TIME
	gem_chain += value
	
	# Bonus combo for gem chains
	if gem_chain >= GEM_CHAIN_COMBO_THRESHOLD:
		var bonus_combos = gem_chain / GEM_CHAIN_COMBO_THRESHOLD
		add_combo(bonus_combos)
		gem_chain = gem_chain % GEM_CHAIN_COMBO_THRESHOLD  # Keep remainder
		print("💎 Gem chain bonus! +" + str(bonus_combos) + " combo")


func get_total_gems() -> int:
	return total_gems_collcted


func _reset_gem_chain() -> void:
	"""Reset gem chain when time expires"""
	if gem_chain > 0:
		print("Gem chain ended:", gem_chain)
	gem_chain = 0


# === Score Multiplier System ===

func get_multiplier() -> float:
	"""Get current score multiplier based on combo tier"""
	return TIER_MULTIPLIERS.get(current_tier, 1.0)


func calculate_score(base_score: int) -> int:
	"""Calculate final score with multiplier"""
	var final_score = int(base_score * get_multiplier())
	return final_score


# === Getters ===

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


func get_gem_chain() -> int:
	return gem_chain


func get_total_kills() -> int:
	return total_kills


func get_total_stomps() -> int:
	return total_stomps


# === UI Info ===

func get_combo_info() -> Dictionary:
	"""Get all combo info for UI display"""
	return {
		"combo": current_combo,
		"tier": current_tier,
		"multiplier": get_multiplier(),
		"max_combo": max_combo_reached,
		"is_decaying": is_decaying,
		"time_remaining": get_time_until_decay(),
		"gem_chain": gem_chain,
		"total_kills": total_kills,
		"total_stomps": total_stomps
	}


func get_tier_name() -> String:
	"""Get display name for current tier"""
	match current_tier:
		0: return "Normal"
		1: return "Hot"
		2: return "Blazing"
		3: return "Inferno"
		4: return "Godlike"
		5: return "Legendary"
		6: return "INSANE"
		_: return "Unknown"


func get_tier_color() -> Color:
	"""Get color for current tier (for UI)"""
	match current_tier:
		0: return Color.WHITE
		1: return Color(0.5, 1.0, 0.5)    # Light green
		2: return Color(0.3, 0.8, 1.0)    # Cyan
		3: return Color(1.0, 0.8, 0.3)    # Gold
		4: return Color(1.0, 0.5, 0.2)    # Orange
		5: return Color(1.0, 0.2, 0.5)    # Pink
		6: return Color(1.0, 0.2, 1.0)    # Magenta
		_: return Color.WHITE


func get_decay_percentage() -> float:
	"""Get how far through decay we are (0.0 to 1.0)"""
	if not is_decaying or combo_decay_time <= 0:
		return 0.0
	return clamp(1.0 - (combo_decay_timer / combo_decay_time), 0.0, 1.0)


# === Stats & Reset ===

func reset_stats() -> void:
	"""Reset all stats for new game"""
	reset_combo()
	max_combo_reached = 0
	total_kills = 0
	total_stomps = 0
	total_shot_kills = 0
	total_gems_collcted = 0
	gems_collected_chnaged.emit(0)
	print("ComboManager stats reset")


func get_stats_summary() -> Dictionary:
	"""Get complete stats for end-of-run display"""
	return {
		"max_combo": max_combo_reached,
		"total_kills": total_kills,
		"total_stomps": total_stomps,
		"shot_kills": total_shot_kills,
		"stomp_percentage": (float(total_stomps) / max(total_kills, 1)) * 100.0
	}


# === Debug ===

func print_debug_info() -> void:
	"""Print current combo state for debugging"""
	print("""
	=== COMBO DEBUG ===
	Combo: %d (Tier %d - %s)
	Multiplier: %.1fx
	Max Combo: %d
	Decaying: %s (%.1fs remaining)
	Gem Chain: %d
	Total Kills: %d (%d stomps)
	==================
	""" % [
		current_combo,
		current_tier,
		get_tier_name(),
		get_multiplier(),
		max_combo_reached,
		"YES" if is_decaying else "NO",
		combo_decay_timer,
		gem_chain,
		total_kills,
		total_stomps
	])
