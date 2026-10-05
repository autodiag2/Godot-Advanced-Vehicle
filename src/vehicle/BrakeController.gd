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

	front_left.brake(brake_input)
	front_right.brake(brake_input)

	rear_left.brake(brake_input)
	rear_right.brake(brake_input)

	if handbrake_pressed:
		rear_left.brake(1.0)
		rear_right.brake(1.0)
