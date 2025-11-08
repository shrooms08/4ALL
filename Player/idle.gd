extends PlayerState


func enter_state() -> void:
	Name = "Idle"


func exit_state() -> void:
	pass


func draw() -> void:
	pass


func update(delta: float) -> void:
	if Player.key_jump_pressed:
		Player.play_jump_sound()
		Player.change_state(States.jump)
		return
	#Player.handle_jump()
	Player.horizontal_movement()
	Player.handle_fall()
	#if Player.move_direction_x != 0:
		#Player.change_state(States.run)
	handle_animation()


func handle_animation():
	Player.player_animation.play("idle")
	Player.handle_flip_h()
