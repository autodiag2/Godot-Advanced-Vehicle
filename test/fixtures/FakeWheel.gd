class_name FakeWheel

var spin := 0.0
var reaction_torque := 0.0

var wheel := FakeWheelData.new()


class FakeWheelData:
	var inertia := 1.0


func get_spin() -> float:
	return spin


func set_spin(value: float) -> void:
	spin = value


func apply_torque(
	torque: float,
	drive_inertia: float,
	delta: float,
	dryRun: bool = false
) -> float:
	var total_inertia := wheel.inertia + drive_inertia

	var net_torque := torque - reaction_torque

	var next_spin := (
		spin +
		delta * net_torque / total_inertia
	)

	if not dryRun:
		spin = next_spin

	return net_torque
