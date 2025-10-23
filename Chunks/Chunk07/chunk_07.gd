extends Node2D

@onready var special_door: Area2D = $SpecialDoor
@onready var room_camera: Camera2D = $RoomCamera
@onready var freeze_trigger: Area2D = $FreezeTrigger

func _ready():
	add_to_group("special_chunk")
	special_door.body_entered.connect(_on_body_entered)
	special_door.body_exited.connect(_on_body_exited)
	freeze_trigger.body_entered.connect(_on_freeze_trigger_entered)
	freeze_trigger.body_exited.connect(_on_freeze_trigger_exited)

func _on_freeze_trigger_entered(body):
	if body.is_in_group("enemy") and body.has_method("kill"):
		body.kill()
		return
	
	if not body.is_in_group("player"):
		return
	
	# Freeze everything in "freezable" group
	var nodes_to_freeze = []
	for n in get_tree().get_nodes_in_group("freezable"):
		if n != body and n.has_method("set_frozen"):
			n.set_frozen(true)
			nodes_to_freeze.append(n)

func _on_freeze_trigger_exited(body):
	if not body.is_in_group("player"):
		return
	
	# Unfreeze everything
	for n in get_tree().get_nodes_in_group("freezable"):
		if n.has_method("set_frozen"):
			n.set_frozen(false)

func _on_body_entered(body):
	if body.is_in_group("player"):
		var player_camera = body.get_node_or_null("Camera2D")
		if player_camera and room_camera:
			#player_camera.make_current()
			room_camera.make_current()
			print("Switched to special room camera")

func _on_body_exited(body):
	if body.is_in_group("player"):
		var player_camera = body.get_node_or_null("Camera2D")
		if player_camera and room_camera:
			#room_camera.make_current()
			player_camera.make_current()
			print("Returned to player camera")
