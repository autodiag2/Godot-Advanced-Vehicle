class_name WheelPad
extends RefCounted

var friction: float = 1.0
var min_friction: float = 0.2
var usage: float = 0.0
var max_usage_energy: float = 1000000.0


func calculate_braking_factor(
	clamping_force: float
) -> float:
	assert(0.0 <= clamping_force)
	assert(clamping_force <= 1.0)
	return get_friction() * clamping_force


func get_friction() -> float:
	return lerpf(
		friction,
		min_friction,
		usage
	)


func update_usage(
	brake_torque: float,
	spin: float,
	delta: float
) -> void:
	assert(0.0 <= brake_torque)
	if delta <= 0.0:
		return

	var energy: float = abs(brake_torque * spin) * delta

	if max_usage_energy > 0.0:
		usage = minf(
			1.0,
			usage + energy / max_usage_energy
		)
