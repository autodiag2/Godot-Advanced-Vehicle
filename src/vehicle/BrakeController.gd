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

	var front_clamping_factor := (
		brake_input *
		parameters.front_brake_bias
	)

	var rear_clamping_factor := (
		brake_input *
		(
			1.0 -
			parameters.front_brake_bias
		)
	)

	front_left.brake(front_clamping_factor)
	front_right.brake(front_clamping_factor)

	rear_left.brake(rear_clamping_factor)
	rear_right.brake(rear_clamping_factor)

	if handbrake_pressed:
		rear_left.brake(1.0)
		rear_right.brake(1.0)
