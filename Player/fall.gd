extends PlayerState

@onready var jump: AudioStreamPlayer2D = $"../../Audio/Jump"

func enter_state() -> void:
	Name = "Fall"


func exit_state() -> void:
	pass


func draw() -> void:
	pass


func update(delta: float) -> void:
	#handle_jump
	if Player.key_jump_pressed and Player.coyote_timer.time_left > 0:
		Player.coyote_timer.stop()
		Player.jumps += 1
		Player.play_jump_sound()
		Player.change_state(States.jump)
		return
	# Handle State Physics
	Player.handle_gravity(delta, Player.GRAVITY_FALL)
	Player.horizontal_movement(Player.AIR_ACCELERATION, Player.AIR_DECELERATION)
	#Player.handle_landing()
	if Player.is_on_floor():
		Player.jumps = 0
		Player.current_ammo = Player.MAX_AMMO
		Player.change_state(States.idle)
		return
	
	handle_animation()
	#Player.handle_jump()
	#Player.handle_jump_buffer()


func handle_animation():
	Player.player_animation.play("fall")
	Player.handle_flip_h()
