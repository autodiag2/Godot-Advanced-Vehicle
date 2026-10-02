class_name WheelPad
extends RefCounted

var friction: float = 0.4
var usage: float = 0.0
var max_usage_energy: float = 1000000.0


func calculate_braking_force(
	clamping_force: float
) -> float:
	return friction * clamping_force


func update_usage(
	brake_torque: float,
	spin: float,
	delta: float
) -> void:
	if delta <= 0.0:
		return

	var energy: float = abs(brake_torque * spin) * delta

	if max_usage_energy > 0.0:
		usage = minf(
			1.0,
			usage + energy / max_usage_energy
		)
