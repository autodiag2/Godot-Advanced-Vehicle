class_name Gearbox
extends RefCounted

var drivetrain_params: DriveTrainParameters

var selected_gear := 0
var _engine_inertia := 0.0
var drive_inertia := 10.0
var last_shift_time := 0

func setup(parameters: DriveTrainParameters) -> void:
	assert(parameters != null)
	drivetrain_params = parameters


func automatic_shifting(
	cur_torque,
	lower_gear_torque,
	higher_gear_torque,
	rpm,
	max_rpm,
	brake_input,
	speed
):
	if not drivetrain_params.automatic:
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


func get_drive_inertia(clutch_input: float) -> float:
	assert(clutch_input >= 0.0)
	assert(clutch_input <= 1.0)
	assert(drivetrain_params != null)

	var gearing: int = abs(get_gearing())

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
