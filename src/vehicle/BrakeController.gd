class_name BrakeController
extends RefCounted

var powertrain: PowertrainController

@warning_ignore("shadowed_variable")
func setup(
	powertrain: PowertrainController
) -> void:
	assert(powertrain != null)
	self.powertrain = powertrain

var _handbrake_was_pressed := false
var _brake_was_pressed := false

func update(
	brake_input: float,
	handbrake_pressed: bool,
	parameters: CarParameters,
	delta: float
) -> void:
	assert(brake_input >= 0.0)
	assert(brake_input <= 1.0)
	assert(powertrain != null)

	if brake_input > 0.0 or _brake_was_pressed:
		powertrain.brake(brake_input)
	_brake_was_pressed = brake_input > 0.0

	if handbrake_pressed or _handbrake_was_pressed:
		powertrain.handbrake(1.0 if handbrake_pressed else 0.0)
	_handbrake_was_pressed = handbrake_pressed
