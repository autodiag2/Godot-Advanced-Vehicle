class_name CarInputController
extends Controller

var throttle: float = 0.0
var steering: float = 0.0
var brake: float = 0.0
var handbrake: bool = false
var clutch: float = 0.0

func _init() -> void:
	TAG_NAME = "INPUT"

func update(input_joystick: Control) -> void:
	if not input_joystick:
		push_warning("no input joystick")
		return
	var joystick_output := Vector2.ZERO

	joystick_output = input_joystick.scene.output

	steering = -joystick_output.x

	if joystick_output.y < 0.0:
		throttle = -joystick_output.y
		brake = 0.0
	else:
		throttle = 0.0
		brake = joystick_output.y

		handbrake = Input.is_action_pressed("Handbrake")
		clutch = Input.get_action_strength("Clutch")
		
	if 0.0 < throttle:
		debug_print("ACCELERATING ", throttle)
	if 0.0 < brake:
		debug_print("BRAKING ", brake)
