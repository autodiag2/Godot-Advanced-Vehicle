extends Control
@export var joystick: Control

# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var joy := Vector2.ZERO
	if joystick:
		joy = joystick.scene.output

	var steering_input: float = -joy.x
	var throttle_input: float = 0.0
	var brake_input: float = 0.0

	if joy.y < 0.0:
		throttle_input = -joy.y
		brake_input = 0.0
	else:
		throttle_input = 0.0
		brake_input = joy.y
	$Panel/VBoxContainer/ThrottleInput.value = throttle_input * 100
	$Panel/VBoxContainer/BrakeInput.value = brake_input * 100
	$Panel/VBoxContainer/ClutchInput.value = Input.get_action_strength("Clutch") * 100
	$Panel/VBoxContainer/SteeringInput.value = steering_input * 100
	
	#print((Input.get_action_strength("SteerRight") - Input.get_action_strength("SteerLeft")) * 100)
