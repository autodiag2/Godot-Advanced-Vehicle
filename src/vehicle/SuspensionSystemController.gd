class_name SuspensionSystemController
extends RefCounted

var compression: Array = [
	0.5,
	0.5,
	0.5,
	0.5
]

func apply_forces(
	front_left_wheel: WheelCorner,
	front_right_wheel: WheelCorner,
	rear_left_wheel: WheelCorner,
	rear_right_wheel: WheelCorner,
	delta: float
) -> void:
	var previous_compression := compression.duplicate()

	compression[2] = (
		rear_left_wheel.apply_forces(
			previous_compression[3],
			delta
		)
	)

	compression[3] = (
		rear_right_wheel.apply_forces(
			previous_compression[2],
			delta
		)
	)

	compression[0] = (
		front_right_wheel.apply_forces(
			previous_compression[1],
			delta
		)
	)

	compression[1] = (
		front_left_wheel.apply_forces(
			previous_compression[0],
			delta
		)
	)
