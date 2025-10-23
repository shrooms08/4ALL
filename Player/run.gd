extends PlayerState



func enter_state() -> void:
	Name = "Run"


func exit_state() -> void:
	pass


func draw() -> void:
	pass


func update(delta: float) -> void:
	if Player.key_jump_pressed and (Player.is_on_floor() or Player.coyote_timer.time_left > 0):
		Player.play_jump_sound()
		Player.change_state(States.jump)
		return
	
	# handle movements
	Player.horizontal_movement()
	Player.handle_gravity(delta)
	#Player.handle_jump()
	#Player.handle_fall()
	# Handle fall
	if !Player.is_on_floor():
		Player.change_state(States.fall)
		return
	
	# Handle Idle
	if Player.move_direction_x == 0:
		Player.change_state(States.idle)
		return
	
	handle_animation()
	#handle_idle()


#func handle_idle():
	#if Player.move_direction_x == 0:
		#Player.change_state(States.idle)


func handle_animation():
	Player.player_animation.play("run")
	Player.handle_flip_h()
