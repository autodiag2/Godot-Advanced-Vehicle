class_name BrakeController
extends RefCounted

var front_brake_torque: float = 0.0
var rear_brake_torque: float = 0.0
var brake_pad_friction: float = 0.4

func update(
	brake_input: float,
	handbrake_pressed: bool,
	parameters: CarParameters,
	delta: float
) -> void:
	assert(brake_input >= 0.0)
	assert(brake_input <= 1.0)
	var brake_torques := calculate_brake_torques(
		brake_input,
		parameters
	)

	front_brake_torque = brake_torques.x
	rear_brake_torque = brake_torques.y

	if handbrake_pressed:
		rear_brake_torque += parameters.max_handbrake_torque

func calculate_brake_torques(
	brake_input: float,
	parameters: CarParameters
) -> Vector2:
	var clamping_force := (
		brake_input *
		parameters.max_brake_force *
		0.5
	)

	var braking_force: float = (
		2.0 *
		brake_pad_friction *
		clamping_force
	)

	var brake_torques := Vector2.ZERO

	brake_torques.x = (
		braking_force *
		parameters.brake_effective_radius *
		parameters.front_brake_bias
	)

	brake_torques.y = (
		braking_force *
		parameters.brake_effective_radius *
		(
			1.0 -
			parameters.front_brake_bias
		)
	)

	return brake_torques
