extends Node2D

@onready var special_door: Area2D = $SpecialDoor
@onready var room_camera: Camera2D = $RoomCamera
@onready var freeze_trigger: Area2D = $FreezeTrigger

@export var bullet_pickup_scene: Array[PackedScene] = []

func _ready():
	add_to_group("special_chunk")
	special_door.body_entered.connect(_on_body_entered)
	special_door.body_exited.connect(_on_body_exited)
	freeze_trigger.body_entered.connect(_on_freeze_trigger_entered)
	freeze_trigger.body_exited.connect(_on_freeze_trigger_exited)
	
	spawn_random_bullet_pickup()

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


func spawn_random_bullet_pickup():
	if bullet_pickup_scene.is_empty():
		print("No bullet pickup scenes assigned!")
		return

	# Don’t spawn another one if it already exists
	if get_node_or_null("BulletPickup") != null:
		return

	var bullet_spawn = get_node_or_null("BulletPickupSpawn")
	if not bullet_spawn:
		print("No SpecialRoom found in chunk")
		return

	var spawn_point = bullet_spawn.get_node_or_null("SpawnPoint")
	if not spawn_point:
		print("No SpawnPoint node inside SpecialRoom")
		return

	# Since there’s only one marker, just get it directly
	var marker = spawn_point.get_child(0)
	if marker == null:
		print("No Marker2D found inside SpawnPoints")
		return

	# Pick one random bullet pickup type
	var random_pickup_scene = bullet_pickup_scene[randi() % bullet_pickup_scene.size()]

	var bullet_pickup = random_pickup_scene.instantiate()
	bullet_pickup.name = "BulletPickup"
	bullet_pickup.global_position = marker.global_position
	add_child(bullet_pickup)

	
