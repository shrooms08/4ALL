extends TileMapLayer

var tile_health := {}
@export var breakable_tile_hp: int = 1
@export var debug_mode: bool = false  # Enable to see what's happening

func break_tile_at(world_pos: Vector2, damage: float = 10.0):
	# Convert world position to tile coordinates
	var local_pos = to_local(world_pos)
	var tile_pos = local_to_map(local_pos)
	
	if debug_mode:
		print("Checking tile at world_pos: ", world_pos, " -> tile_pos: ", tile_pos)
	
	# Check the exact tile AND adjacent tiles (to handle edge cases)
	var tiles_to_check = [
		tile_pos,
		tile_pos + Vector2i(1, 0),
		tile_pos + Vector2i(-1, 0),
		tile_pos + Vector2i(0, 1),
		tile_pos + Vector2i(0, -1),
	]
	
	for check_pos in tiles_to_check:
		if try_break_tile(check_pos, damage, world_pos):
			return  # Successfully broke a tile, stop checking

func try_break_tile(tile_pos: Vector2i, damage: float, world_pos: Vector2) -> bool:
	var tile_data = get_cell_tile_data(tile_pos)
	
	if not tile_data:
		return false
	
	# Check if tile is breakable
	if not tile_data.get_custom_data("breakable"):
		if debug_mode:
			print("Tile at ", tile_pos, " is not breakable")
		return false
	
	# Verify the bullet is actually close to this tile's center
	var tile_center = to_global(map_to_local(tile_pos))
	var distance = world_pos.distance_to(tile_center)
	var max_distance = tile_set.tile_size.x * 0.75  # 75% of tile size
	
	if distance > max_distance:
		return false  # Bullet too far from this tile
	
	if debug_mode:
		print("Breaking tile at ", tile_pos, " (distance: ", distance, ")")
	
	# Initialize HP if new tile
	if not tile_health.has(tile_pos):
		var base_hp = breakable_tile_hp
		if tile_data.has_custom_data("hp"):
			base_hp = tile_data.get_custom_data("hp")
		tile_health[tile_pos] = base_hp
	
	# Apply damage
	tile_health[tile_pos] -= damage
	
	if debug_mode:
		print("Tile HP: ", tile_health[tile_pos])
	
	# Destroy when HP <= 0
	if tile_health[tile_pos] <= 0:
		erase_cell(tile_pos)
		tile_health.erase(tile_pos)
		if debug_mode:
			print("Tile destroyed!")
	
	return true  # Successfully processed this tile
