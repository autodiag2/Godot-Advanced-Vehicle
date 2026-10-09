class_name Gearbox
extends RefCounted

var parameters_drivetrain: DriveTrainParameters
@export var params: GearboxParameters

var _selected_gear: int = 0
var selected_gear: int:
	get:
		return _selected_gear
	set(value):
		if value == _selected_gear:
			return

		_selected_gear = value
		if ( powertrain != null ):
			powertrain.onGearboxGearChange(_selected_gear)

var drive_inertia := 10.0
var last_shift_time := 0
var powertrain: PowertrainController
var differential: Differential
var input_av := 0.0
var output_av := 0.0

func apply_torque(torque: float, delta: float) -> void:
	assert(delta >= 0.0)

	if delta == 0.0:
		return

	var gearing := get_gearing()

	# The output shaft remains connected to the differential in neutral.
	if parameters_drivetrain.drivetype == DriveTrainParameters.DRIVE_TYPE.RWD:
		output_av = differential.average_rear_wheel_speed
	elif parameters_drivetrain.drivetype == DriveTrainParameters.DRIVE_TYPE.FWD:
		output_av = differential.average_front_wheel_speed
	elif parameters_drivetrain.drivetype == DriveTrainParameters.DRIVE_TYPE.AWD:
		output_av = (
			differential.average_rear_wheel_speed +
			differential.average_front_wheel_speed
		) * 0.5

	if gearing == 0.0:
		# The input shaft rotates independently of the output shaft.
		assert(0.0 < params.gear_inertia)
		input_av += torque / params.gear_inertia * delta
		return

	# An engaged gear constrains input and output shaft speeds.
	input_av = output_av * gearing

	var output_torque := torque * gearing
	differential.apply_torque(output_torque, delta)

func setup(parameters: DriveTrainParameters, powertrain_arg: PowertrainController, differential_arg: Differential) -> void:
	assert(parameters != null)
	parameters_drivetrain = parameters
	powertrain = powertrain_arg
	params = parameters_drivetrain.gearbox
	self.differential = differential_arg
	
func automatic_shifting(
	cur_torque,
	lower_gear_torque,
	higher_gear_torque,
	rpm,
	max_rpm,
	brake_input,
	speed
):
	if not params.automatic:
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
		if not reversing:
			if Time.get_ticks_msec() - last_shift_time > shift_time:
				shift_down()
		else:
			if Time.get_ticks_msec() - last_shift_time > shift_time:
				shift_up()


func set_gear(gear):
	assert(params != null)

	gear = clamp(
		gear,
		-1,
		params.gear_ratios.size()
	)

	selected_gear = gear

func calculate_inertia() -> float:
	var gearing := get_gearing()

	if gearing == 0.0:
		return params.gear_inertia

	return (
		params.gear_inertia +
		differential.calculate_inertia() / pow(gearing, 2)
	)

func calculate_torque(delta: float) -> float:
	var gearing := get_gearing()
	if gearing == 0.0:
		return 0.0

	var torque := differential.calculate_torque(delta)

	return torque / gearing

func shift_up():
	if selected_gear < params.gear_ratios.size():
		selected_gear += 1
		last_shift_time = Time.get_ticks_msec()
		set_gear(selected_gear)


func shift_down():
	if selected_gear > -1:
		selected_gear -= 1
		last_shift_time = Time.get_ticks_msec()
		set_gear(selected_gear)


func get_gearing() -> float:
	assert(params != null)
	assert(
		selected_gear >= -1 &&
		selected_gear <= params.gear_ratios.size()
	)

	if selected_gear > 0:
		return params.gear_ratios[selected_gear - 1]

	if selected_gear == -1:
		return -params.reverse_ratio

	return 0.0
