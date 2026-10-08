class_name DriveTrain
extends Controller

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

var average_front_wheel_speed: float:
	get:
		return (
			(
				wheel_fl.wheel.spin +
				wheel_fr.wheel.spin
			) * 0.5
		)

var average_rear_wheel_speed: float:
	get:
		return (
			(
				wheel_bl.wheel.spin +
				wheel_br.wheel.spin
			) * 0.5
		)

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

func calculate_inertia(depth: int = 3) -> float:
	assert(0 <= depth)
	var total_inertia := 0.0
	
	var drivetrain_inertia_partial := 30.0
	total_inertia += drivetrain_inertia_partial
	
	var gearing := gearbox.get_gearing()

	if gearing == 0.0:
		return 0.0

	total_inertia += gearbox.calculate_inertia()
	
	if 0 < depth:
		var wheel_inertia := 0.0

		for wheel in [wheel_bl, wheel_br, wheel_fl, wheel_fr]:
			wheel_inertia += wheel.wheel.inertia

		total_inertia += wheel_inertia / pow(gearing, 2)
	
	return total_inertia
	
func calculate_torque(delta: float) -> float:
	var torque := 0.0

	for wheel in [wheel_bl, wheel_br, wheel_fl, wheel_fr]:
		torque += wheel.calculate_torque(delta)
	
	var gearing := gearbox.get_gearing()
	if gearing == 0.0:
		return 0.0

	return torque / gearing

func get_av() -> float:
	var gearbox_shaft_speed := 0.0
	var gearing := get_gearing()

	if (
		parameters.drivetype ==
		parameters.DRIVE_TYPE.RWD
	):
		gearbox_shaft_speed = (
			average_rear_wheel_speed *
			gearing
		)

	elif (
		parameters.drivetype ==
		parameters.DRIVE_TYPE.FWD
	):
		gearbox_shaft_speed = (
			average_front_wheel_speed *
			gearing
		)

	elif (
		parameters.drivetype ==
		parameters.DRIVE_TYPE.AWD
	):
		gearbox_shaft_speed = (
			(
				average_front_wheel_speed +
				average_rear_wheel_speed
			) *
			0.5 *
			gearing
		)
	return gearbox_shaft_speed

func debug_print(...args) -> void:
	args.push_front("DRIVETRAIN")
	super.debug_print(args)

# Return engine-side reaction torque
func apply_torque(
	torque: float,
	delta: float
) -> float:
	assert(parameters != null)
	assert(delta >= 0.0)

	var rear_wheels = [
		wheel_bl,
		wheel_br
	]

	var front_wheels = [
		wheel_fl,
		wheel_fr
	]

	var gearing := gearbox.get_gearing()

	if gearing == 0.0:
		return 0.0

	var geared_torque := torque * gearing

	wheel_bl.apply_torque(geared_torque/4.0, delta)
	wheel_br.apply_torque(geared_torque/4.0, delta)
	wheel_fl.apply_torque(geared_torque/4.0, delta)
	wheel_fr.apply_torque(geared_torque/4.0, delta)
	return 0.0
	if parameters.drivetype == DRIVE_TYPE.RWD:
		var reaction_torque := rear_differential.apply_torque(
			geared_torque,
			rear_wheels,
			gearbox.drive_inertia,
			gearing,
			delta
		)

		debug_print(
			"RWD",
			"geared_torque=", geared_torque,
			" reaction_torque=", reaction_torque
		)

		return reaction_torque / gearing

	elif parameters.drivetype == DRIVE_TYPE.FWD:

		var reaction_torque := front_differential.apply_torque(
			geared_torque,
			front_wheels,
			gearbox.drive_inertia,
			gearing,
			delta
		)

		return reaction_torque / gearing

	elif parameters.drivetype == DRIVE_TYPE.AWD:
		match parameters.center_diff.diff_type:
			Differential.DIFF_TYPE.LOCKED:
				var wheels = [
					wheel_bl,
					wheel_br,
					wheel_fl,
					wheel_fr
				]

				var spin: float = center_differential._get_locked_spin(
					wheels,
					geared_torque,
					gearbox.drive_inertia,
					delta
				)

				for wheel in wheels:
					wheel.set_spin(spin)

				var total_reaction_torque := 0.0

				for wheel in wheels:
					total_reaction_torque += (
						wheel.apply_torque(
							geared_torque,
							gearbox.drive_inertia,
							delta
						)
					)

				return total_reaction_torque / gearing

			Differential.DIFF_TYPE.LIMITED_SLIP:
				var rear_drive = (
					geared_torque *
					(
						1.0 -
						parameters.center_split_fr
					)
				)

				var front_drive = (
					geared_torque *
					parameters.center_split_fr
				)

				var rear_reaction_torque := rear_differential.apply_torque(
					rear_drive,
					rear_wheels,
					gearbox.drive_inertia,
					gearing,
					delta
				)

				var front_reaction_torque := front_differential.apply_torque(
					front_drive,
					front_wheels,
					gearbox.drive_inertia,
					gearing,
					delta
				)

				return (
					rear_reaction_torque +
					front_reaction_torque
				) / gearing

			Differential.DIFF_TYPE.OPEN_DIFF:
				var rear_drive = geared_torque * 0.5
				var front_drive = geared_torque * 0.5

				var rear_reaction_torque := rear_differential.apply_torque(
					rear_drive,
					rear_wheels,
					gearbox.drive_inertia,
					gearing,
					delta
				)

				var front_reaction_torque := front_differential.apply_torque(
					front_drive,
					front_wheels,
					gearbox.drive_inertia,
					gearing,
					delta
				)

				return (
					rear_reaction_torque +
					front_reaction_torque
				) / gearing

	return 0.0
