extends PlayerState



func enter_state() -> void:
	Name = "JumpPeak"


func exit_state() -> void:
	pass


func draw() -> void:
	Player.change_state(States.fall)


func update(delta: float) -> void:
	pass
