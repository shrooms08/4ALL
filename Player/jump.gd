extends PlayerState
class_name Jump

var jump_released := false
var jump_time := 0.0

const MIN_JUMP_TIME = 0.05  # Minimum time before jump can be cancelled

func enter_state() -> void:
	Name = "Jump"
	Player.velocity.y = Player.jump_speed
	jump_released = false
	jump_time = 0.0

func exit_state() -> void:
	pass

func draw() -> void:
	pass

func update(delta: float) -> void:
	
	jump_time += delta
	Player.horizontal_movement()
	Player.handle_gravity(delta)
	handle_jump_to_fall()
	handle_animation()


func handle_jump_to_fall() -> void:
	if Player.velocity.y > 0:
		Player.change_state(States.fall)
	# Only allow variable jump height after minimum jump time
	elif !Player.key_jump and jump_time > MIN_JUMP_TIME and !jump_released:
		Player.velocity.y *= Player.VARIABLE_JUMP_MULTIPLIER
		jump_released = true
		Player.change_state(States.fall)


func handle_animation():
	Player.player_animation.play("jump")
	Player.handle_flip_h()
