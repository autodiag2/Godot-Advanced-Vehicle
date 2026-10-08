class_name DriveTrain
extends Controller

const AV_2_RPM: float = 60.0 / TAU

enum DRIVE_TYPE {
	FWD,
	RWD,
	AWD,
}

var gearbox := Gearbox.new()
var differential := Differential.new()

@export var parameters: DriveTrainParameters:
	set(value):
		parameters = value
		gearbox.setup(value, gearbox.powertrain)

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
	differential.initialise(parameters.rear_diff, wheel_fl, wheel_fr, wheel_bl, wheel_br)

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
	total_inertia += differential.calculate_inertia() / gearing

	return total_inertia
	
func calculate_torque(delta: float) -> float:
	var torque := differential.calculate_torque(delta)
	
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

	var gearing := gearbox.get_gearing()

	if gearing == 0.0:
		return 0.0

	var geared_torque := torque * gearing

	var drive_inertia := 0.0
	var reaction_torque := differential.apply_torque(
		geared_torque,
		delta
	)

	return reaction_torque / gearing
