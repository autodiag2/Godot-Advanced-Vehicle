class_name FakeWheel
var spin: float = 0.0
var brake_torque: float = 0.0

var wheel := FakeWheelData.new()


class FakeWheelData:
	var inertia: float = 1.0


func get_spin() -> float:
	return spin


func set_spin(value: float) -> void:
	spin = value

func get_brake_torque() -> float:
	return brake_torque


func apply_torque(
	torque: float,
	inertia: float,
	delta: float,
	dryRun: bool = false
) -> float:
	return torque - brake_torque
