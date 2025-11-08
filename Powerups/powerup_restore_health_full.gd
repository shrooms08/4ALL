extends Node
class_name Powerup_RestoreHealthFull

## Metadata (for UI and debugging)
var powerup_name: String = "Restore Health Full"
var description: String = "Fully restore your health to maximum."
var icon_path: String = "" 

func apply(player: Node) -> void:
	"""
	This is called when the player selects this powerup.
	We ensure we have access to the player's heal or health system.
	"""
	if not player:
		push_error("No player found to apply powerup.")
		return

	if not player.has_method("heal"):
		push_error("Player doesn't have heal() method.")
		return

# Heal full safely
	if player.has_variable("current_health") and player.has_variable("MAX_HEALTH"):
		player.current_health = player.MAX_HEALTH
		if player.has_signal("health_changed"):
			player.emit_signal("health_changed", player.current_health)
		elif player.has_method("update_health_ui"):
			player.update_health_ui()
		print("Powerup Applied: Restored player to full health!")
	else:
		push_warning("Player doesn't have health variables (current_health / MAX_HEALTH).")


	# Optional feedback
	if player.has_node("Audio/Heal"):
		var heal_sound = player.get_node("Audio/Heal")
		if heal_sound and not heal_sound.playing:
			heal_sound.play()

	print("Powerup Applied: Restored player to full health!")
