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
var _engine_inertia := 0.0
var drive_inertia := 10.0
var last_shift_time := 0
var powertrain: PowertrainController

func setup(parameters: DriveTrainParameters, powertrain_arg: PowertrainController) -> void:
	assert(parameters != null)
	parameters_drivetrain = parameters
	powertrain = powertrain_arg
	params = parameters_drivetrain.gearbox

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


func set_input_inertia(value):
	assert(value > 0.0)
	_engine_inertia = value


func get_drive_inertia(clutch_input: float) -> float:
	assert(clutch_input >= 0.0)
	assert(clutch_input <= 1.0)
	assert(params != null)

	var gearing: float = get_gearing()

	var gearbox_inertia := (
		pow(gearing, 2) *
		params.gear_inertia
	)

	var reflected_engine_inertia := (
		_engine_inertia *
		(1.0 - clutch_input)
	)

	return (
		gearbox_inertia +
		reflected_engine_inertia
	)
