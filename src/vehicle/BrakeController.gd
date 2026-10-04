class_name BrakeController
extends RefCounted

var front_left: RaycastSuspension
var front_right: RaycastSuspension
var rear_left: RaycastSuspension
var rear_right: RaycastSuspension


func setup(
	front_left_corner: RaycastSuspension,
	front_right_corner: RaycastSuspension,
	rear_left_corner: RaycastSuspension,
	rear_right_corner: RaycastSuspension
) -> void:
	front_left = front_left_corner
	front_right = front_right_corner
	rear_left = rear_left_corner
	rear_right = rear_right_corner

	assert(front_left != null)
	assert(front_right != null)
	assert(rear_left != null)
	assert(rear_right != null)


func update(
	brake_input: float,
	handbrake_pressed: bool,
	parameters: CarParameters,
	delta: float
) -> void:
	assert(brake_input >= 0.0)
	assert(brake_input <= 1.0)

	var braking_force := (
		brake_input *
		parameters.max_brake_force
	)

	var front_clamping_force := (
		braking_force *
		parameters.front_brake_bias /
		2.0
	)

	var rear_clamping_force := (
		braking_force *
		(
			1.0 -
			parameters.front_brake_bias
		) /
		2.0
	)

	front_left.brake(front_clamping_force)
	front_right.brake(front_clamping_force)

	rear_left.brake(rear_clamping_force)
	rear_right.brake(rear_clamping_force)

	if handbrake_pressed:
		var handbrake_clamping_force := (
			parameters.max_handbrake_force *
			0.5
		)

		rear_left.brake(
			rear_clamping_force +
			handbrake_clamping_force
		)

		rear_right.brake(
			rear_clamping_force +
			handbrake_clamping_force
		)
