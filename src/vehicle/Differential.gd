class_name Differential
extends RefCounted

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

func get_reaction_torque(torque: float, wheels: Array, drive_intertia: float, delta: float) -> float:
	assert(wheels.size() == 2)

	return (
		wheels[0].apply_torque(torque, drive_intertia, delta, true) +
		wheels[1].apply_torque(torque, drive_intertia, delta, true)
	)


func _get_locked_spin(
	wheels: Array,
	drive_torque: float,
	drive_inertia: float,
	delta: float
) -> float:
	assert(wheels.size() > 0)
	assert(delta >= 0.0)

	var net_torque := 0.0
	var total_inertia := drive_inertia

	for wheel in wheels:
		net_torque += wheel.apply_torque(drive_torque, drive_inertia, delta, true)
		total_inertia += wheel.wheel.inertia

	if total_inertia <= 0.0:
		return 0.0

	var average_spin := 0.0

	for wheel in wheels:
		average_spin += wheel.get_spin()

	average_spin /= wheels.size()

	return (
		average_spin +
		delta *
		net_torque /
		total_inertia
	)
func apply_torque(
	torque: float,
	wheels: Array,
	drive_inertia: float,
	gearing: float,
	delta: float,
	dryRun: bool = false
) -> float:
	assert(wheels.size() == 2)
	assert(delta >= 0.0)

	var diff_state = DIFF_STATE.LOCKED

	# Query the wheel's external torque with no drive torque.
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
	print("tr1=", tr1)

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

	var t1 := torque * 0.5
	var t2 := torque * 0.5

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
			if not dryRun:
				_diff_clutch.locked = true

			t2 *= _diff_split
			t1 *= (1.0 - _diff_split)

			var applied_torque_1: float = wheels[0].apply_torque(
				t1,
				drive_inertia,
				delta,
				dryRun
			)

			var applied_torque_2: float = wheels[1].apply_torque(
				t2,
				drive_inertia,
				delta,
				dryRun
			)

			var diff_sum := (
				applied_torque_1 -
				applied_torque_2
			)

			_diff_split = (
				0.5 *
				(
					clamp(diff_sum, -1.0, 1.0) +
					1.0
				)
			)

			return applied_torque_1 + applied_torque_2

		DIFF_STATE.SLIPPING:
			_diff_clutch.friction = parameters.diff_preload

			var diff_torques: Vector2 = (
				_diff_clutch.get_reaction_torques(
					wheels[0].get_spin(),
					wheels[1].get_spin(),
					tr1,
					tr2,
					parameters.diff_preload * ratio,
					0.0
				)
			)

			t1 += diff_torques.x
			t2 += diff_torques.y

			var applied_torque_1: float = wheels[0].apply_torque(
				t1,
				drive_inertia,
				delta,
				dryRun
			)

			var applied_torque_2: float = wheels[1].apply_torque(
				t2,
				drive_inertia,
				delta,
				dryRun
			)

			return applied_torque_1 + applied_torque_2

		DIFF_STATE.LOCKED:
			_diff_clutch.locked = true

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
				torque +
				tr1 +
				tr2
			) / total_inertia

			# Drive torque required at each wheel so that:
			# wheel net torque = wheel inertia * angular acceleration.
			t1 = (
				wheel_inertia_1 *
				angular_acceleration -
				tr1
			)

			t2 = (
				wheel_inertia_2 *
				angular_acceleration -
				tr2
			)

			var applied_torque_1: float = wheels[0].apply_torque(
				t1,
				0.0,
				delta,
				dryRun
			)

			var applied_torque_2: float = wheels[1].apply_torque(
				t2,
				0.0,
				delta,
				dryRun
			)

			return applied_torque_1 + applied_torque_2

	return 0.0
