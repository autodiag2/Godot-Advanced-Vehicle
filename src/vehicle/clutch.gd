class_name Clutch
extends RefCounted

@export var friction := 250.0

# result x if for Te,c y for Tc,p (powertrain)
# Te,c : power applied to powertrain
# Tc,p : power applied by powertrain on engine
# t1 is Te
# t2 is Tp
# engine_av is we
# powertrain_av is wp
func get_reaction_torques(
	engine_av: float,
	powertrain_av: float,
	t1: float,
	t2: float,
	inertia_engine: float,
	inertia_powertrain: float,
	clutch_input: float
) -> Vector2:
	var delta_torque := t1 - t2
	var delta_av := engine_av - powertrain_av
	var clutch_torque_max := friction * (1.0 - clutch_input)
	var result := Vector2.ZERO
	
		# locked state
	if absf(delta_av) < 0.5:
		var total_inertia := inertia_engine + inertia_powertrain
		assert(total_inertia > 0.0)

		var angular_acceleration := delta_torque / total_inertia
		var clutch_torque := (
			t2 +
			inertia_powertrain * angular_acceleration
		)

		result.x = clutch_torque
		result.y = -clutch_torque

		assert(absf(clutch_torque) <= clutch_torque_max)
	else:
		# Slipping state
		var torque = minf(absf(delta_torque), clutch_torque_max)
		if 0.5 < delta_av:
			result.x = -torque
			result.y = torque
		elif delta_av < -0.5:
			result.x = torque
			result.y = -torque

	assert(result.x == -result.y)
	return result
