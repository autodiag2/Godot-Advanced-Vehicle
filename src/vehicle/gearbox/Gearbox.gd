class_name Gearbox
extends RefCounted

var parameters_drivetrain: DriveTrainParameters
@export var params: GearboxParameters

var listeners: Array[Variant] = []
var _selected_gear: int = 0
var selected_gear: int:
	get:
		return _selected_gear
	set(value):
		if value == _selected_gear:
			return

		_selected_gear = value
		for listener in listeners:
			listener.onGearboxGearChange(_selected_gear)

var differential: Differential
var input_av := 0.0
var output_av := 0.0

func setup(parameters: DriveTrainParameters, differential_arg: Differential) -> void:
	assert(parameters != null)
	parameters_drivetrain = parameters
	params = parameters_drivetrain.gearbox
	self.differential = differential_arg

func apply_torque(torque: float, delta: float) -> float:
	assert(delta >= 0.0)
	if get_gearing() == 0.0:
		print(
			"neutral input_av=", input_av,
			" torque=", torque,
			" inertia=", params.gear_inertia,
			" delta=", delta
		)
	if delta == 0.0:
		return 0.0

	var gearing := get_gearing()

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
		assert(params.gear_inertia > 0.0)
		input_av += torque / params.gear_inertia * delta
		return torque

	var previous_input_av := input_av
	input_av = output_av * gearing

	var input_angular_acceleration := (
		input_av - previous_input_av
	) / delta

	var transmitted_torque := (
		torque -
		params.gear_inertia * input_angular_acceleration
	)

	var output_torque := transmitted_torque * gearing
	var net_output_torque := differential.apply_torque(output_torque, delta)

	return net_output_torque / gearing

func set_gear(gear: int):
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
		set_gear(selected_gear)

func shift_down():
	if selected_gear > -1:
		selected_gear -= 1
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

func add_listener(listener: Variant) -> void:
	assert(listener != null)

	if !listeners.has(listener):
		listeners.append(listener)


func remove_listener(listener: Variant) -> void:
	assert(listener != null)

	listeners.erase(listener)
