class_name BrakeController
extends RefCounted

var powertrain: PowertrainController


@warning_ignore("shadowed_variable")
func setup(
	powertrain: PowertrainController
) -> void:
	assert(powertrain != null)
	self.powertrain = powertrain


func update(
	brake_input: float,
	handbrake_pressed: bool,
	parameters: CarParameters,
	delta: float
) -> void:
	assert(brake_input >= 0.0)
	assert(brake_input <= 1.0)

	powertrain.brake(brake_input)
	powertrain.handbrake(1.0 if handbrake_pressed else 0.0)
