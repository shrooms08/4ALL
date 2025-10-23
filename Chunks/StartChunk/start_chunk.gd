extends Node2D

signal player_left_start()

@export var title_delay: float = 1  # Delay before title shows
@export var title_duration: float = 4.0  # How long the title stays visible

func _ready():
	var trigger = $StartExitTrigger
	if trigger:
		trigger.body_entered.connect(_on_trigger_entered)

func _on_trigger_entered(body):
	if body.is_in_group("player"):
		emit_signal("player_left_start")
