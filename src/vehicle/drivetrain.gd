class_name DriveTrain
extends RefCounted

const AV_2_RPM: float = 60.0 / TAU

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

var front_differential := Differential.new()
var rear_differential := Differential.new()
var center_differential := Differential.new()

var wheel_fl: RaycastSuspension
var wheel_fr: RaycastSuspension
var wheel_bl: RaycastSuspension
var wheel_br: RaycastSuspension


func setup(
	parameters_arg: DriveTrainParameters,
	powertrain: PowertrainController
) -> void:
	parameters = parameters_arg

	self.wheel_fl = powertrain.wheel_fl
	self.wheel_fr = powertrain.wheel_fr
	self.wheel_bl = powertrain.wheel_bl
	self.wheel_br = powertrain.wheel_br

	gearbox.setup(
		parameters_arg,
		powertrain
	)
	rear_differential.initialise(parameters.rear_diff)
	front_differential.initialise(parameters.front_diff)
	center_differential.initialise(parameters.center_diff)

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
			rear_differential.get_reaction_torque(
				[
					wheel_bl,
					wheel_br
				]
			)
		) / gearing

	if parameters.drivetype == DRIVE_TYPE.FWD:
		return (
			front_differential.get_reaction_torque(
				[
					wheel_fl,
					wheel_fr
				]
			)
		) / gearing

	if parameters.drivetype == DRIVE_TYPE.AWD:
		return (
			wheel_bl.get_reaction_torque() +
			wheel_br.get_reaction_torque() +
			wheel_fl.get_reaction_torque() +
			wheel_fr.get_reaction_torque()
		) / gearing

	return 0.0


# Return net torque
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
	print("APPLYING ", drive_torque, " N.m to differential")
	if parameters.drivetype == DRIVE_TYPE.RWD:

		var net_torque := rear_differential.apply_torque(
			drive_torque,
			rear_wheels,
			gearbox.drive_inertia,
			gearing,
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

		return net_torque

	elif parameters.drivetype == DRIVE_TYPE.FWD:

		var net_torque := front_differential.apply_torque(
			drive_torque,
			front_wheels,
			gearbox.drive_inertia,
			gearing,
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

		return net_torque

	elif parameters.drivetype == DRIVE_TYPE.AWD:
		match parameters.center_diff.diff_type:
			Differential.DIFF_TYPE.LOCKED:
				var wheels = [
					wheel_bl,
					wheel_br,
					wheel_fl,
					wheel_fr
				]

				var spin := center_differential._get_locked_spin(
					wheels,
					drive_torque,
					gearbox.drive_inertia,
					delta
				)

				for wheel in wheels:
					wheel.set_spin(spin)

				var total_reaction_torque := 0.0

				for wheel in wheels:
					total_reaction_torque += wheel.get_reaction_torque()

				return drive_torque - total_reaction_torque

			Differential.DIFF_TYPE.LIMITED_SLIP:
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

				var rear_net_torque := rear_differential.apply_torque(
					rear_drive,
					rear_wheels,
					gearbox.drive_inertia,
					gearing,
					delta
				)

				var front_net_torque := front_differential.apply_torque(
					front_drive,
					front_wheels,
					gearbox.drive_inertia,
					gearing,
					delta
				)

				return (
					rear_net_torque +
					front_net_torque
				)

			Differential.DIFF_TYPE.OPEN_DIFF:
				var rear_drive = drive_torque * 0.5
				var front_drive = drive_torque * 0.5

				var rear_net_torque := rear_differential.apply_torque(
					rear_drive,
					rear_wheels,
					gearbox.drive_inertia,
					gearing,
					delta
				)

				var front_net_torque := front_differential.apply_torque(
					front_drive,
					front_wheels,
					gearbox.drive_inertia,
					gearing,
					delta
				)

				return (
					rear_net_torque +
					front_net_torque
				)

	return 0.0
