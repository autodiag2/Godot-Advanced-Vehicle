class_name WheelDisc
extends RefCounted

var effective_radius: float = 0.0

var inner_pad := WheelPad.new()
var outer_pad := WheelPad.new()


func calculate_brake_torque(
	clamping_force: float
) -> float:
	var braking_force := (
		inner_pad.calculate_braking_force(clamping_force) +
		outer_pad.calculate_braking_force(clamping_force)
	)

	return braking_force * effective_radius


func update_usage(
	brake_torque: float,
	spin: float,
	delta: float
) -> void:
	inner_pad.update_usage(
		brake_torque * 0.5,
		spin,
		delta
	)

	outer_pad.update_usage(
		brake_torque * 0.5,
		spin,
		delta
	)
