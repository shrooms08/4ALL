extends Node2D

@onready var portal_area: Area2D = $PortalArea

@export var powerup_room_scene: PackedScene  # Assign PowerupRoom.tscn here

var player_in_range: bool = false
var is_used: bool = false

func _ready() -> void:
	add_to_group("powerup_chunk")
	
	if portal_area:
		portal_area.body_entered.connect(_on_body_entered)
		portal_area.body_exited.connect(_on_body_exited)
	else:
		push_warning("PortalArea not found in powerup_chunk!")

func _process(_delta: float) -> void:
	if player_in_range and not is_used and Input.is_action_just_pressed("interact"):
		_enter_powerup_room()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		print("🌟 Press [E] to enter Power-Up Room!")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func _enter_powerup_room() -> void:
	if is_used or not powerup_room_scene:
		return
	
	is_used = true
	print("✨ Entering powerup room...")
	
	# Instantiate the powerup room as overlay
	var powerup_room = powerup_room_scene.instantiate()
	get_tree().current_scene.add_child(powerup_room)
	
	# Optional: Connect to powerup selected signal
	if powerup_room.has_signal("powerup_selected"):
		powerup_room.powerup_selected.connect(_on_powerup_chosen)

func _on_powerup_chosen(powerup_type, powerup_data) -> void:
	print("Player chose:", powerup_data.name)
	# You could add visual effects here
