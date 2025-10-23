extends Node2D

@export var enemy_scenes: Array[PackedScene] = []  # Assign all enemy scenes here
@export var spawn_area: Rect2 = Rect2(Vector2.ZERO, Vector2(1000, 1000))  # area to spawn in
@export var spawn_count: int = 10  # total enemies to spawn

func _ready():
	randomize()
	spawn_enemies()

func spawn_enemies():
	for i in range(spawn_count):
		# Choose a random enemy scene from the list
		var scene = enemy_scenes.pick_random()
		var enemy = scene.instantiate()
		
		# Random position inside the spawn area
		var spawn_pos = Vector2(
			randf_range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x),
			randf_range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y)
		)
		
		enemy.global_position = spawn_pos
		get_parent().add_child(enemy)  # attach to level instead of spawner
