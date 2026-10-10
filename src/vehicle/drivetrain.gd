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
		gearbox.setup(value, gearbox.differential)

var wheel_fl: RaycastSuspension
var wheel_fr: RaycastSuspension
var wheel_bl: RaycastSuspension
var wheel_br: RaycastSuspension


func brake(clamping_factor: float):
	wheel_bl.brake(clamping_factor)
	wheel_br.brake(clamping_factor)
	wheel_fl.brake(clamping_factor)
	wheel_fr.brake(clamping_factor)

func handbrake(clamping_factor: float):
	wheel_bl.brake(clamping_factor)
	wheel_br.brake(clamping_factor)

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
		differential
	)
	gearbox.add_listener(powertrain)
	differential.initialise(parameters.rear_diff, wheel_bl, wheel_br, wheel_fl, wheel_fr, parameters)


func set_gear(gear):
	gearbox.set_gear(gear)


func get_gearing() -> float:
	return gearbox.get_gearing()

func calculate_inertia(depth: int = 3) -> float:
	assert(0 <= depth)
	var total_inertia := 0.0
	
	var drivetrain_inertia_partial := 0.0
	total_inertia += drivetrain_inertia_partial
	total_inertia += gearbox.calculate_inertia()
	return total_inertia
	
func calculate_torque(delta: float) -> float:
	return gearbox.calculate_torque(delta)

func get_av() -> float:
	return gearbox.input_av

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

	return gearbox.apply_torque(torque, delta)
