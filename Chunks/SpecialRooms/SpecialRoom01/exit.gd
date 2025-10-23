extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if not body.is_in_group("player"):
		return
	
	# Find the active special door
	var door = get_tree().get_first_node_in_group("special_doors")
	if not door:
		print("Warning: No active special door found!")
		return
	
	# Find the Return marker in the special chunk that contains this exit
	var return_marker = _find_return_marker_in_special_chunks()
	
	if return_marker:
		print("Found return marker at: ", return_marker.global_position)
		door.exit_special_room(return_marker.global_position)
	else:
		print("Warning: Could not find Return marker in normal chunks - using door position as fallback")
		door.exit_special_room()

func _find_return_marker_in_special_chunks() -> Node2D:
	# Search for Return marker in normal chunks (main scene)
	for chunk in get_tree().get_nodes_in_group("special_chunk"):
		var marker = chunk.get_node_or_null("Return")
		if marker:
			return marker
	
	# If not found in normal chunks, search entire tree as fallback
	return get_tree().get_root().find_child("Return", true, false)
