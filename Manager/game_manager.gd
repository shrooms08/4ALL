extends Node

# GameManager for tracking stats displayed in pause menu
# Add this as an AutoLoad singleton or as a node in your game scene

# Stats
var score: int = 0
var combo: int = 0
var max_combo: int = 0
var enemies_killed: int = 0
var depth: int = 0  # In meters/floors
var gems_collected: int = 0
var shots_fired: int = 0
var accuracy: float = 0.0
var stomps: int = 0
var perfect_stomps: int = 0  # Consecutive stomps without landing

# Signals for UI updates
signal score_changed(new_score)
signal combo_changed(new_combo)
signal depth_changed(new_depth)
signal enemy_killed()

# Combo system
const COMBO_TIMEOUT = 2.0  # Seconds before combo resets
var combo_timer: float = 0.0


func _ready() -> void:
	add_to_group("game_manager")


func _process(delta: float) -> void:
	# Handle combo timeout
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			reset_combo()


# Score management
func add_score(amount: int) -> void:
	score += amount
	emit_signal("score_changed", score)


func set_score(amount: int) -> void:
	score = amount
	emit_signal("score_changed", score)


# Combo system
func increment_combo() -> void:
	combo += 1
	combo_timer = COMBO_TIMEOUT
	
	# Track max combo
	if combo > max_combo:
		max_combo = combo
	
	emit_signal("combo_changed", combo)


func reset_combo() -> void:
	combo = 0
	combo_timer = 0.0
	emit_signal("combo_changed", combo)


func refresh_combo_timer() -> void:
	"""Call this to keep combo alive without incrementing"""
	combo_timer = COMBO_TIMEOUT


# Enemy tracking
func register_kill(enemy_value: int = 100) -> void:
	enemies_killed += 1
	
	# Add combo
	increment_combo()
	
	# Calculate score with combo multiplier
	var combo_multiplier = 1.0 + (combo * 0.1)  # 10% per combo
	var points = int(enemy_value * combo_multiplier)
	add_score(points)
	
	emit_signal("enemy_killed")


func register_stomp() -> void:
	stomps += 1
	perfect_stomps += 1


func reset_perfect_stomps() -> void:
	"""Call when player lands (not on enemy)"""
	perfect_stomps = 0


# Depth tracking (for vertical scrolling)
func update_depth(new_depth: int) -> void:
	if new_depth > depth:
		depth = new_depth
		emit_signal("depth_changed", depth)


# Shooting stats
func register_shot() -> void:
	shots_fired += 1
	_calculate_accuracy()


func register_hit() -> void:
	# You'll need to call this when a bullet hits an enemy
	_calculate_accuracy()


func _calculate_accuracy() -> void:
	if shots_fired > 0:
		accuracy = float(enemies_killed) / float(shots_fired) * 100.0
		accuracy = clamp(accuracy, 0.0, 100.0)


# Collectibles
func collect_gem(value: int = 1) -> void:
	gems_collected += value


# Reset for new game
func reset_stats() -> void:
	score = 0
	combo = 0
	max_combo = 0
	enemies_killed = 0
	depth = 0
	gems_collected = 0
	shots_fired = 0
	accuracy = 0.0
	stomps = 0
	perfect_stomps = 0
	combo_timer = 0.0
	
	# Emit signals for UI updates
	emit_signal("score_changed", score)
	emit_signal("combo_changed", combo)
	emit_signal("depth_changed", depth)


# Get formatted stats for display
func get_stats_dict() -> Dictionary:
	return {
		"score": score,
		"combo": combo,
		"max_combo": max_combo,
		"enemies_killed": enemies_killed,
		"depth": depth,
		"gems_collected": gems_collected,
		"shots_fired": shots_fired,
		"accuracy": "%.1f%%" % accuracy,
		"stomps": stomps,
		"perfect_stomps": perfect_stomps
	}


# Save/Load high scores
func save_high_score() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://highscores.cfg")
	
	var current_high_score = config.get_value("scores", "high_score", 0)
	
	if score > current_high_score:
		config.set_value("scores", "high_score", score)
		config.set_value("scores", "max_combo", max_combo)
		config.set_value("scores", "kills", enemies_killed)
		config.set_value("scores", "depth", depth)
		config.save("user://highscores.cfg")


func get_high_score() -> int:
	var config = ConfigFile.new()
	var err = config.load("user://highscores.cfg")
	if err != OK:
		return 0
	return config.get_value("scores", "high_score", 0)
