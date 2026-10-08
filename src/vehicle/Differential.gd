class_name Differential
extends Controller

enum DIFF_TYPE {
	LIMITED_SLIP,
	OPEN_DIFF,
	LOCKED,
}

enum DIFF_STATE {
	LOCKED,
	SLIPPING,
	OPEN,
}

var _diff_clutch := Clutch.new()
var _diff_split := 0.5
var parameters := DiffParameters.new()


func initialise(parameters_arg: DiffParameters):
	assert(parameters_arg != null)
	parameters = parameters_arg

func debug_print(...args) -> void:
	args.push_front("DIFFERENTIAL")
	super.debug_print(args)

func get_reaction_torque(
	torque: float,
	wheels: Array,
	drive_inertia: float,
	delta: float
) -> float:
	assert(wheels.size() == 2)

	return (
		wheels[0].apply_torque(
			torque,
			drive_inertia,
			delta,
			true
		) +
		wheels[1].apply_torque(
			torque,
			drive_inertia,
			delta,
			true
		)
	)


func apply_torque(
	torque: float,
	wheels: Array,
	drive_inertia: float,
	gearing: float,
	delta: float
) -> float:
	assert(wheels.size() == 2)
	assert(delta >= 0.0)

	var diff_state = DIFF_STATE.LOCKED

	# Query the external/reaction torque of each wheel.
	var tr1: float = wheels[0].apply_torque(
		0.0,
		0.0,
		delta,
		true
	)

	var tr2: float = wheels[1].apply_torque(
		0.0,
		0.0,
		delta,
		true
	)

	var abs_tr1 := absf(tr1)
	var abs_tr2 := absf(tr2)

	var bias := 1.0

	if abs_tr1 < 0.001 and abs_tr2 < 0.001:
		bias = 1.0
	elif abs_tr1 >= abs_tr2:
		bias = abs_tr1 / maxf(abs_tr2, 0.001)
	else:
		bias = abs_tr2 / maxf(abs_tr1, 0.001)

	var delta_torque := tr1 - tr2

	var ratio = parameters.power_ratio

	if torque * sign(gearing) < 0:
		ratio = parameters.coast_ratio

	if parameters.diff_type == DIFF_TYPE.OPEN_DIFF:
		diff_state = DIFF_STATE.OPEN

	elif parameters.diff_type == DIFF_TYPE.LOCKED:
		diff_state = DIFF_STATE.LOCKED

	else:
		if (
			absf(delta_torque) > parameters.diff_preload &&
			bias >= ratio
		):
			diff_state = DIFF_STATE.SLIPPING

	match diff_state:
		DIFF_STATE.OPEN:

			var t1 := torque * _diff_split
			var t2 := torque * (1.0 - _diff_split)

			var reaction_torque_1: float = wheels[0].apply_torque(
				t1,
				drive_inertia,
				delta
			)

			var reaction_torque_2: float = wheels[1].apply_torque(
				t2,
				drive_inertia,
				delta
			)

			var diff_sum := (
				reaction_torque_1 -
				reaction_torque_2
			)

			_diff_split = (
				0.5 *
				(
					clamp(diff_sum, -1.0, 1.0) +
					1.0
				)
			)

			return reaction_torque_1 + reaction_torque_2

		DIFF_STATE.SLIPPING:
			_diff_clutch.friction = parameters.diff_preload
			
			var diff_torques: Vector2 = Vector2.ZERO
			# TODO
			#var diff_torques: Vector2 = (
			#	_diff_clutch.get_reaction_torques(
			#		wheels[0].get_spin(),
			#		wheels[1].get_spin(),
			#		tr1,
			#		tr2,
			#		parameters.diff_preload * ratio,
			#		0.0
			#	)
			#)

			var t1 := torque * 0.5 + diff_torques.x
			var t2 := torque * 0.5 + diff_torques.y

			var reaction_torque_1: float = wheels[0].apply_torque(
				t1,
				drive_inertia,
				delta
			)

			var reaction_torque_2: float = wheels[1].apply_torque(
				t2,
				drive_inertia,
				delta
			)

			return reaction_torque_1 + reaction_torque_2

		DIFF_STATE.LOCKED:
			#_diff_clutch.locked = true
	
			var wheel_inertia_1: float = wheels[0].wheel.inertia
			var wheel_inertia_2: float = wheels[1].wheel.inertia

			var total_inertia := (
				drive_inertia +
				wheel_inertia_1 +
				wheel_inertia_2
			)

			if total_inertia <= 0.0:
				return 0.0

			# Common angular acceleration of the locked system.
			var angular_acceleration := (
				torque -
				tr1 -
				tr2
			) / total_inertia

			# Drive torque required at each wheel so that:
			# wheel net torque = wheel inertia * angular acceleration.
			var t1 := (
				wheel_inertia_1 *
				angular_acceleration +
				tr1
			)

			var t2 := (
				wheel_inertia_2 *
				angular_acceleration +
				tr2
			)

			var reaction_torque_1: float = wheels[0].apply_torque(
				t1,
				0.0,
				delta
			)

			var reaction_torque_2: float = wheels[1].apply_torque(
				t2,
				0.0,
				delta
			)
			debug_print("LOCKED apply t1=", t1, "/", reaction_torque_1, " t2=", t2, "/", reaction_torque_2)

			return reaction_torque_1 + reaction_torque_2

	return 0.0
