extends Node2D

signal portal_entered(chunk: Node2D)

@onready var portal_area: Area2D = $PortalArea
@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_label: Label = $PromptLabel

@export var portal_color: Color = Color(1.0, 0.8, 0.0, 1.0)
@export var pulse_enabled: bool = true
@export var pulse_speed: float = 2.0
@export var pulse_intensity: float = 0.1  # How much the portal scales during pulse

var player_in_range: bool = false
var is_used: bool = false
var pulse_time: float = 0.0


func _ready() -> void:
	add_to_group("powerup_chunk")
	
	# Debug: Check node structure
	print("🔍 Portal Debug Info:")
	print("  - Portal name: ", name)
	print("  - Portal position: ", global_position)
	print("  - PortalArea exists: ", portal_area != null)
	if portal_area:
		print("  - PortalArea has collision shape: ", portal_area.get_child_count() > 0)
		print("  - PortalArea monitoring: ", portal_area.monitoring)
		print("  - PortalArea layer: ", portal_area.collision_layer)
		print("  - PortalArea mask: ", portal_area.collision_mask)
	
	# Connect signals
	if portal_area:
		portal_area.body_entered.connect(_on_body_entered)
		portal_area.body_exited.connect(_on_body_exited)
		print("  ✅ Signals connected")
	else:
		push_error("  ❌ PortalArea not found!")
	
	# Setup visuals
	_setup_visual_effects()
	
	# Hide prompt initially
	if prompt_label:
		prompt_label.visible = false


func _process(delta: float) -> void:
	# Handle interaction
	if player_in_range and not is_used and Input.is_action_just_pressed("interact"):
		_enter_powerup_room()
	
	# Animate pulse effect
	if pulse_enabled and not is_used and sprite:
		pulse_time += delta * pulse_speed
		var pulse: float = (sin(pulse_time) + 1.0) / 2.0
		var scale_factor: float = 1.0 + (pulse * pulse_intensity)
		sprite.scale = Vector2(scale_factor, scale_factor)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_used:
		player_in_range = true
		_show_prompt()
		print("💫 Portal available - Press [E] to enter")


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		_hide_prompt()


func _enter_powerup_room() -> void:
	if is_used:
		return
	
	is_used = true
	print("🚪 Entering powerup room...")
	
	# Hide prompt
	_hide_prompt()
	
	# Visual feedback - parallel animations
	if sprite:
		var tween := create_tween()
		tween.set_parallel(true)  # Run animations simultaneously
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.3)
	
	# Find and trigger powerup selection UI
	var powerup_ui: Node = get_tree().get_first_node_in_group("powerup_selection")
	if powerup_ui and powerup_ui.has_method("show_powerup_selection"):
		powerup_ui.show_powerup_selection()
	else:
		push_warning("⚠️ PowerupSelection UI not found! Make sure it's in the 'powerup_selection' group")
	
	# Emit signal with reference to this portal
	portal_entered.emit(self)
	
	# Disable collision after use
	if portal_area:
		portal_area.monitoring = false


func _setup_visual_effects() -> void:
	if sprite:
		sprite.modulate = portal_color


func _show_prompt() -> void:
	if prompt_label:
		prompt_label.visible = true
		prompt_label.text = "[E] Enter Portal"


func _hide_prompt() -> void:
	if prompt_label:
		prompt_label.visible = false


# Public method for external control
func reset() -> void:
	# Reset portal to unused state
	is_used = false
	player_in_range = false
	pulse_time = 0.0
	
	if sprite:
		sprite.modulate = portal_color
		sprite.modulate.a = 1.0
		sprite.scale = Vector2.ONE
	
	if portal_area:
		portal_area.monitoring = true
	
	_hide_prompt()


# Optional: Add this if you want to disable/enable the portal dynamically
func set_active(active: bool) -> void:
	if portal_area:
		portal_area.monitoring = active
	
	if sprite:
		sprite.visible = active
	
	if not active:
		_hide_prompt()
		player_in_range = false
