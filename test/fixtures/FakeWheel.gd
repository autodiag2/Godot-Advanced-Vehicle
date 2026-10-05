class_name FakeWheel
var spin: float = 0.0
var reaction_torque: float = 0.0
var brake_torque: float = 0.0

var wheel := FakeWheelData.new()


class FakeWheelData:
	var inertia: float = 1.0


func get_spin() -> float:
	return spin


func set_spin(value: float) -> void:
	spin = value


func get_reaction_torque() -> float:
	var result := reaction_torque

	var brake_direction : float = sign(spin)

	if brake_direction == 0.0:
		brake_direction = sign(result)

	result -= brake_torque * brake_direction

	return result


func get_brake_torque() -> float:
	return brake_torque


func apply_torque(
	torque: float,
	inertia: float,
	delta: float
) -> float:
	reaction_torque = -torque
	return 0.0
