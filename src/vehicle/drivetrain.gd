class_name DriveTrain
extends Node

const AV_2_RPM: float = 60.0 / TAU

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

enum DRIVE_TYPE {
	FWD,
	RWD,
	AWD,
}

@export var drivetrain_params: DriveTrainParameters

var selected_gear := 0
var _diff_clutch := Clutch.new()
var _engine_inertia := 0.0
var _diff_split := 0.5
var last_shift_time := 0

var avg_rear_spin := 0.0
var avg_front_spin := 0.0

var drive_inertia := 10.0
var reaction_torque := 0.0


func automatic_shifting(
	cur_torque,
	lower_gear_torque,
	higher_gear_torque,
	rpm,
	max_rpm,
	brake_input,
	speed
):
	if !drivetrain_params.automatic:
		return

	var reversing = false
	var shift_time = 700

	if selected_gear == -1:
		reversing = true

	if (
		selected_gear > 0 &&
		higher_gear_torque > cur_torque
	):
		if rpm > 0.85 * max_rpm:
			if Time.get_ticks_msec() - last_shift_time > shift_time:
				shift_up()

	if (
		selected_gear > 1 &&
		rpm < 0.5 * max_rpm &&
		lower_gear_torque > cur_torque
	):
		if Time.get_ticks_msec() - last_shift_time > shift_time:
			shift_down()

	if abs(selected_gear) <= 1 and abs(speed) < 3.0 and brake_input > 0.2:
		if !reversing:
			if Time.get_ticks_msec() - last_shift_time > shift_time:
				shift_down()
		else:
			if Time.get_ticks_msec() - last_shift_time > shift_time:
				shift_up()


func set_selected_gear(gear):
	assert(drivetrain_params != null)

	gear = clamp(
		gear,
		-1,
		drivetrain_params.gear_ratios.size()
	)

	selected_gear = gear


func shift_up():
	if selected_gear < drivetrain_params.gear_ratios.size():
		selected_gear += 1
		last_shift_time = Time.get_ticks_msec()
		set_selected_gear(selected_gear)


func shift_down():
	if selected_gear > -1:
		selected_gear -= 1
		last_shift_time = Time.get_ticks_msec()
		set_selected_gear(selected_gear)


func get_gearing() -> float:
	assert(drivetrain_params != null)
	assert(
		selected_gear >= -1 &&
		selected_gear <= drivetrain_params.gear_ratios.size()
	)

	if selected_gear > 0:
		return (
			drivetrain_params.gear_ratios[selected_gear - 1] *
			drivetrain_params.final_drive
		)

	if selected_gear == -1:
		return (
			-drivetrain_params.reverse_ratio *
			drivetrain_params.final_drive
		)

	return 0.0


func set_input_inertia(value):
	assert(value > 0.0)
	_engine_inertia = value


func _get_drive_inertia(clutch_input: float) -> float:
	assert(clutch_input >= 0.0)
	assert(clutch_input <= 1.0)
	assert(drivetrain_params != null)

	var gearing : int = abs(get_gearing())

	var gearbox_inertia := (
		pow(gearing, 2) *
		drivetrain_params.gear_inertia
	)

	var reflected_engine_inertia := (
		_engine_inertia *
		(1.0 - clutch_input)
	)

	return (
		gearbox_inertia +
		reflected_engine_inertia
	)


func _get_locked_spin(
	wheels: Array,
	drive_torque: float,
	brake_torque: float,
	delta: float
) -> float:
	assert(wheels.size() > 0)
	assert(delta >= 0.0)

	var net_torque := drive_torque
	var total_inertia := drive_inertia

	for wheel in wheels:
		net_torque += wheel.get_reaction_torque()
		total_inertia += wheel.wheel.inertia

	if total_inertia <= 0.0:
		return 0.0

	var average_spin := 0.0

	for wheel in wheels:
		average_spin += wheel.get_spin()

	average_spin /= wheels.size()

	var brake_direction : float = sign(average_spin)

	if brake_direction == 0.0:
		brake_direction = sign(net_torque)

	net_torque -= (
		brake_torque *
		brake_direction
	)

	return (
		average_spin +
		delta *
		net_torque /
		total_inertia
	)


func differential(
	torque: float,
	brake_torque,
	wheels,
	diff: DiffParameters,
	delta: float
):
	assert(wheels.size() == 2)
	assert(diff != null)
	assert(delta >= 0.0)

	var diff_state = DIFF_STATE.LOCKED

	var tr1: float = (
		wheels[0].get_reaction_torque()
	)

	var tr2: float = (
		wheels[1].get_reaction_torque()
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

	var t1 := torque * 0.5
	var t2 := torque * 0.5

	var ratio = diff.power_ratio

	if torque * sign(get_gearing()) < 0:
		ratio = diff.coast_ratio

	if diff.diff_type == DIFF_TYPE.OPEN_DIFF:
		diff_state = DIFF_STATE.OPEN

	elif diff.diff_type == DIFF_TYPE.LOCKED:
		diff_state = DIFF_STATE.LOCKED

	else:
		if (
			absf(delta_torque) > diff.diff_preload &&
			bias >= ratio
		):
			diff_state = DIFF_STATE.SLIPPING

	match diff_state:
		DIFF_STATE.OPEN:
			_diff_clutch.locked = true

			var diff_sum := 0.0

			t2 *= _diff_split
			t1 *= (1.0 - _diff_split)

			diff_sum += wheels[0].apply_torque(
				t1,
				brake_torque * 0.5,
				drive_inertia,
				delta
			)

			diff_sum -= wheels[1].apply_torque(
				t2,
				brake_torque * 0.5,
				drive_inertia,
				delta
			)

			_diff_split = (
				0.5 *
				(
					clamp(diff_sum, -1.0, 1.0) +
					1.0
				)
			)

		DIFF_STATE.SLIPPING:
			_diff_clutch.friction = diff.diff_preload

			var diff_torques: Vector2 = (
				_diff_clutch.get_reaction_torques(
					wheels[0].get_spin(),
					wheels[1].get_spin(),
					tr1,
					tr2,
					diff.diff_preload * ratio,
					0.0
				)
			)

			t1 += diff_torques.x
			t2 += diff_torques.y

			wheels[0].apply_torque(
				t1,
				brake_torque * 0.5,
				drive_inertia,
				delta
			)

			wheels[1].apply_torque(
				t2,
				brake_torque * 0.5,
				drive_inertia,
				delta
			)

		DIFF_STATE.LOCKED:
			_diff_clutch.locked = true

			var spin := _get_locked_spin(
				wheels,
				torque,
				brake_torque,
				delta
			)

			wheels[0].set_spin(spin)
			wheels[1].set_spin(spin)


func drivetrain(
	torque: float,
	rear_brake_torque: float,
	front_brake_torque: float,
	wheels: Array,
	clutch_input: float,
	delta: float
):
	assert(wheels.size() == 4)
	assert(clutch_input >= 0.0)
	assert(clutch_input <= 1.0)
	assert(delta >= 0.0)

	var rear_wheels = [
		wheels[0],
		wheels[1]
	]

	var front_wheels = [
		wheels[2],
		wheels[3]
	]

	avg_rear_spin = (
		wheels[0].get_spin() +
		wheels[1].get_spin()
	) * 0.5

	avg_front_spin = (
		wheels[2].get_spin() +
		wheels[3].get_spin()
	) * 0.5

	drive_inertia = _get_drive_inertia(
		clutch_input
	)

	var gearing := get_gearing()
	var drive_torque := torque * gearing

	reaction_torque = 0.0

	if drivetrain_params.drivetype == DRIVE_TYPE.RWD:
		differential(
			drive_torque,
			rear_brake_torque,
			rear_wheels,
			drivetrain_params.rear_diff,
			delta
		)

		front_wheels[0].apply_torque(
			0.0,
			front_brake_torque * 0.5,
			0.0,
			delta
		)

		front_wheels[1].apply_torque(
			0.0,
			front_brake_torque * 0.5,
			0.0,
			delta
		)

		if gearing != 0.0:
			reaction_torque = (
				rear_wheels[0].get_reaction_torque() +
				rear_wheels[1].get_reaction_torque()
			) * 0.5

			reaction_torque *= 1.0 / gearing

	elif drivetrain_params.drivetype == DRIVE_TYPE.FWD:
		differential(
			drive_torque,
			front_brake_torque,
			front_wheels,
			drivetrain_params.front_diff,
			delta
		)

		rear_wheels[0].apply_torque(
			0.0,
			rear_brake_torque * 0.5,
			0.0,
			delta
		)

		rear_wheels[1].apply_torque(
			0.0,
			rear_brake_torque * 0.5,
			0.0,
			delta
		)

		if gearing != 0.0:
			reaction_torque = (
				front_wheels[0].get_reaction_torque() +
				front_wheels[1].get_reaction_torque()
			) * 0.5

			reaction_torque *= 1.0 / gearing

	elif drivetrain_params.drivetype == DRIVE_TYPE.AWD:
		if gearing != 0.0:
			reaction_torque = (
				rear_wheels[0].get_reaction_torque() +
				rear_wheels[1].get_reaction_torque()
			) * 0.25

			reaction_torque += (
				front_wheels[0].get_reaction_torque() +
				front_wheels[1].get_reaction_torque()
			) * 0.25

			reaction_torque *= 1.0 / gearing

		match drivetrain_params.center_diff.diff_type:
			DIFF_TYPE.LOCKED:
				var spin := _get_locked_spin(
					wheels,
					drive_torque,
					rear_brake_torque + front_brake_torque,
					delta
				)

				for wheel in wheels:
					wheel.set_spin(spin)

			DIFF_TYPE.LIMITED_SLIP:
				var rear_drive = (
					drive_torque *
					(
						1.0 -
						drivetrain_params.center_split_fr
					)
				)

				var front_drive = (
					drive_torque *
					drivetrain_params.center_split_fr
				)

				differential(
					rear_drive,
					rear_brake_torque,
					rear_wheels,
					drivetrain_params.rear_diff,
					delta
				)

				differential(
					front_drive,
					front_brake_torque,
					front_wheels,
					drivetrain_params.front_diff,
					delta
				)

			DIFF_TYPE.OPEN_DIFF:
				var rear_drive = drive_torque * 0.5
				var front_drive = drive_torque * 0.5

				differential(
					rear_drive,
					rear_brake_torque,
					rear_wheels,
					drivetrain_params.rear_diff,
					delta
				)

				differential(
					front_drive,
					front_brake_torque,
					front_wheels,
					drivetrain_params.front_diff,
					delta
				)
