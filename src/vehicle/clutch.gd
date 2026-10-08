class_name Clutch
extends RefCounted

@export var friction := 250.0

# result x if for Te,c y for Tc,d (drivetrain)
# Te,c : power applied to drivetrain
# Tc,d : power applied by drivetrain on engine
# engine_torque is Te
# drivetrain_torque is Tp
# engine_av is we
# drivertrain_torque is wd
func get_reaction_torques(
	engine_av: float,
	drivertrain_torque: float,
	engine_torque: float,
	drivetrain_torque: float,
	inertia_engine: float,
	inertia_drivetrain: float,
	clutch_input: float
) -> Vector2:
	assert(not is_nan(engine_torque))
	assert(not is_nan(drivetrain_torque))
	assert(not is_nan(engine_av))
	assert(not is_nan(drivertrain_torque))
	assert(not is_nan(inertia_engine))
	assert(not is_nan(inertia_drivetrain))
	assert(0.0 <= clutch_input)
	assert(clutch_input <= 1.0)
	var delta_torque := engine_torque - drivetrain_torque
	var delta_av := engine_av - drivertrain_torque
	var clutch_torque_max := friction * (1.0 - clutch_input)
	var result := Vector2.ZERO
	
		# locked state
	if absf(delta_av) < 0.5:
		var total_inertia := inertia_engine + inertia_drivetrain
		assert(0.0 < total_inertia)

		var angular_acceleration := delta_torque / total_inertia
		var clutch_torque := (
			drivetrain_torque +
			inertia_drivetrain * angular_acceleration
		)

		result.x = clutch_torque
		result.y = -clutch_torque
		assert(absf(clutch_torque) <= clutch_torque_max)
	else:
		# Slipping state
		var torque = minf(absf(delta_torque), clutch_torque_max)
		if 0.5 < delta_av:
			result.x = torque
			result.y = -torque
		elif delta_av < -0.5:
			result.x = -torque
			result.y = torque

	assert(result.x == -result.y)
	return result
