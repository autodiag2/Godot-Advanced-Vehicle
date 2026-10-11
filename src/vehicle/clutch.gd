class_name Clutch
extends RefCounted

@export var friction := 250.0

var _locked := false

func is_locked() -> bool:
	return _locked

# result x reaction torque to apply on drivetrain
# result y reaction torque to apply on engine
func get_reaction_torques(
	engine_av: float,
	drivetrain_av: float,
	engine_torque: float,
	drivetrain_torque: float,
	inertia_engine: float,
	inertia_drivetrain: float,
	clutch_input: float,
	delta: float
) -> Vector2:
	assert(not is_nan(engine_torque))
	assert(not is_nan(drivetrain_av))
	assert(not is_nan(engine_av))
	assert(not is_nan(drivetrain_torque))
	assert(not is_nan(inertia_engine))
	assert(not is_nan(inertia_drivetrain))
	assert(inertia_engine > 0.0)
	assert(inertia_drivetrain > 0.0)
	assert(delta >= 0.0)
	assert(clutch_input >= 0.0 and clutch_input <= 1.0)

	if delta == 0.0:
		return Vector2.ZERO

	var relative_speed := engine_av - drivetrain_av
	var max_clutch_torque := friction * (1.0 - clutch_input)

	if max_clutch_torque <= 0.0 or relative_speed == 0.0:
		_locked = false
		return Vector2.ZERO

	var inverse_total_inertia := (
		1.0 / inertia_engine +
		1.0 / inertia_drivetrain
	)

	var torque_to_synchronize := (
		relative_speed / delta +
		engine_torque / inertia_engine -
		drivetrain_torque / inertia_drivetrain
	) / inverse_total_inertia

	var direction := signf(relative_speed)
	var clutch_torque := clampf(
		torque_to_synchronize,
		0.0 if direction > 0.0 else -max_clutch_torque,
		max_clutch_torque if direction > 0.0 else 0.0
	)

	_locked = (
		direction * torque_to_synchronize >= 0.0
		and absf(torque_to_synchronize) <= max_clutch_torque
	)

	return Vector2(clutch_torque, -clutch_torque)
