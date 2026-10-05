class_name DriveTrain
extends RefCounted

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

var gearbox := Gearbox.new()

@export var parameters: DriveTrainParameters:
	set(value):
		parameters = value
		gearbox.setup(value, gearbox.powertrain)

var _diff_clutch := Clutch.new()
var _diff_split := 0.5

var wheel_fl: RaycastSuspension
var wheel_fr: RaycastSuspension
var wheel_bl: RaycastSuspension
var wheel_br: RaycastSuspension

func setup(parameters_arg: DriveTrainParameters, powertrain: PowertrainController):
	parameters = parameters_arg
	self.wheel_fl = powertrain.wheel_fl
	self.wheel_fr = powertrain.wheel_fr
	self.wheel_bl = powertrain.wheel_bl
	self.wheel_br = powertrain.wheel_br
	gearbox.setup(parameters_arg, powertrain)

func automatic_shifting(
	cur_torque,
	lower_gear_torque,
	higher_gear_torque,
	rpm,
	max_rpm,
	brake_input,
	speed
):
	gearbox.automatic_shifting(
		cur_torque,
		lower_gear_torque,
		higher_gear_torque,
		rpm,
		max_rpm,
		brake_input,
		speed
	)

func set_gear(gear):
	gearbox.set_gear(gear)

func get_gearing() -> float:
	return gearbox.get_gearing()

func set_input_inertia(value):
	gearbox.set_input_inertia(value)

func get_reaction_torque() -> float:
	assert(parameters != null)

	var gearing := gearbox.get_gearing()

	if gearing == 0.0:
		return 0.0

	if parameters.drivetype == DRIVE_TYPE.RWD:
		return (
			wheel_bl.get_reaction_torque() +
			wheel_br.get_reaction_torque()
		) / gearing

	if parameters.drivetype == DRIVE_TYPE.FWD:
		return (
			wheel_fl.get_reaction_torque() +
			wheel_fr.get_reaction_torque()
		) / gearing

	if parameters.drivetype == DRIVE_TYPE.AWD:
		return (
			wheel_bl.get_reaction_torque() +
			wheel_br.get_reaction_torque() +
			wheel_fl.get_reaction_torque() +
			wheel_fr.get_reaction_torque()
		) / gearing

	return 0.0

func _get_locked_spin(
	wheels: Array,
	drive_torque: float,
	delta: float
) -> float:
	assert(wheels.size() > 0)
	assert(delta >= 0.0)

	var net_torque := drive_torque
	var total_inertia := gearbox.drive_inertia

	for wheel in wheels:
		net_torque += wheel.get_reaction_torque()
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

func differential(
	torque: float,
	wheels,
	diff: DiffParameters,
	delta: float
) -> float:
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

			t2 *= _diff_split
			t1 *= (1.0 - _diff_split)

			var applied_torque_1 : float = wheels[0].apply_torque(
				t1,
				gearbox.drive_inertia,
				delta
			)

			var applied_torque_2 : float = wheels[1].apply_torque(
				t2,
				gearbox.drive_inertia,
				delta
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

			return -(
				tr1 +
				tr2
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
				gearbox.drive_inertia,
				delta
			)

			wheels[1].apply_torque(
				t2,
				gearbox.drive_inertia,
				delta
			)

			return -(
				tr1 +
				tr2
			)

		DIFF_STATE.LOCKED:
			_diff_clutch.locked = true

			var spin := _get_locked_spin(
				wheels,
				torque,
				delta
			)

			wheels[0].set_spin(spin)
			wheels[1].set_spin(spin)

			return -(
				tr1 +
				tr2
			)

	return 0.0

# return the net torque applied
func apply_torque(
	torque: float,
	clutch_input: float,
	delta: float
) -> float:
	assert(parameters != null)
	assert(clutch_input >= 0.0)
	assert(clutch_input <= 1.0)
	assert(delta >= 0.0)

	var rear_wheels = [
		wheel_bl,
		wheel_br
	]

	var front_wheels = [
		wheel_fl,
		wheel_fr
	]

	gearbox.drive_inertia = gearbox.get_drive_inertia(
		clutch_input
	)

	var gearing := gearbox.get_gearing()
	var drive_torque := torque * gearing
	var reaction_torque := 0.0

	if parameters.drivetype == DRIVE_TYPE.RWD:

		reaction_torque = differential(
			drive_torque,
			rear_wheels,
			parameters.rear_diff,
			delta
		)

		wheel_fl.apply_torque(
			0.0,
			0.0,
			delta
		)

		wheel_fr.apply_torque(
			0.0,
			0.0,
			delta
		)

	elif parameters.drivetype == DRIVE_TYPE.FWD:

		reaction_torque = differential(
			drive_torque,
			front_wheels,
			parameters.front_diff,
			delta
		)

		wheel_bl.apply_torque(
			0.0,
			0.0,
			delta
		)

		wheel_br.apply_torque(
			0.0,
			0.0,
			delta
		)

	elif parameters.drivetype == DRIVE_TYPE.AWD:
		match parameters.center_diff.diff_type:
			DIFF_TYPE.LOCKED:
				var wheels = [wheel_bl, wheel_br, wheel_fl, wheel_fr]
				var spin := _get_locked_spin(
					wheels,
					drive_torque,
					delta
				)

				for wheel in wheels:
					wheel.set_spin(spin)

				var total_reaction_torque := 0.0

				for wheel in wheels:
					total_reaction_torque += wheel.get_reaction_torque()

				reaction_torque = -total_reaction_torque

			DIFF_TYPE.LIMITED_SLIP:
				var rear_drive = (
					drive_torque *
					(
						1.0 -
						parameters.center_split_fr
					)
				)

				var front_drive = (
					drive_torque *
					parameters.center_split_fr
				)

				reaction_torque += differential(
					rear_drive,
					rear_wheels,
					parameters.rear_diff,
					delta
				)

				reaction_torque += differential(
					front_drive,
					front_wheels,
					parameters.front_diff,
					delta
				)

			DIFF_TYPE.OPEN_DIFF:
				var rear_drive = drive_torque * 0.5
				var front_drive = drive_torque * 0.5

				reaction_torque += differential(
					rear_drive,
					rear_wheels,
					parameters.rear_diff,
					delta
				)

				reaction_torque += differential(
					front_drive,
					front_wheels,
					parameters.front_diff,
					delta
				)

	return drive_torque - reaction_torque
