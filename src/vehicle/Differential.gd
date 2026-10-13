class_name Differential
extends Controller

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

var parameters := DiffParameters.new()
var wheel_fl: WheelCorner
var wheel_fr: WheelCorner
var wheel_bl: WheelCorner
var wheel_br: WheelCorner
var wheels: Array[WheelCorner]:
	get():
		return [wheel_bl, wheel_br, wheel_fl, wheel_fr]
	set(value):
		push_error("not implemented")
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
var type : DIFF_TYPE = DIFF_TYPE.LOCKED
var drive_type := DriveTrainParameters.DRIVE_TYPE.RWD
var locked_synchronization_rate := 10.0 # Hz

func _init() -> void:
	TAG_NAME = "DIFF"

@warning_ignore("shadowed_variable")
func initialise(parameters_arg: DiffParameters, wheel_bl: WheelCorner, wheel_br: WheelCorner, wheel_fl: WheelCorner, wheel_fr: WheelCorner, drivetrain_parameters: DriveTrainParameters):
	assert(parameters_arg != null)
	parameters = parameters_arg
	self.wheel_bl = wheel_bl
	self.wheel_br = wheel_br
	self.wheel_fl = wheel_fl
	self.wheel_fr = wheel_fr

@warning_ignore("shadowed_variable")
func set_type(type: DIFF_TYPE):
	self.type = type

func calculate_inertia() -> float:
	var wheels_inertia := 0.0

	for wheel in wheels:
		wheels_inertia += wheel.wheel.inertia

	return wheels_inertia

func calculate_torque() -> float:
	var torque := 0.0
	for wheel in wheels:
		torque += wheel.calculate_torque()
	return torque

func get_braking_torque() -> float:
	var torque := 0.0
	for wheel in wheels:
		torque += wheel.get_brake_torque()
	return torque

func apply_torque(
	torque: float,
	delta: float
) -> float:
	assert(0.0 <= delta)

	if drive_type != DriveTrainParameters.DRIVE_TYPE.RWD:
		assert(false, "not implemented")
		return NAN

	var wheel_bl_reaction := wheel_bl.get_reaction_torque()
	var wheel_br_reaction := wheel_br.get_reaction_torque()

	var wheel_inertia_bl: float = wheel_bl.wheel.inertia
	var wheel_inertia_br: float = wheel_br.wheel.inertia
	var total_inertia := wheel_inertia_bl + wheel_inertia_br

	if total_inertia <= 0.0:
		return 0.0

	if delta > 0.0 and type == DIFF_TYPE.LOCKED:
		var spin_difference := wheel_bl.get_spin() - wheel_br.get_spin()
		var correction_fraction := 1.0 - exp(-locked_synchronization_rate * delta)
		var spin_correction := spin_difference * correction_fraction

		var corrected_bl := (
			wheel_bl.get_spin() -
			spin_correction * wheel_inertia_br / total_inertia
		)
		var corrected_br := (
			wheel_br.get_spin() +
			spin_correction * wheel_inertia_bl / total_inertia
		)

		wheel_bl.set_spin(corrected_bl)
		wheel_br.set_spin(corrected_br)

	var angular_acceleration := (
		torque - wheel_bl_reaction - wheel_br_reaction
	) / total_inertia
	
	debug_print(
		"input_torque=", torque,
		" reaction_bl=", wheel_bl_reaction,
		" reaction_br=", wheel_br_reaction,
		"inertia_bl=", wheel_inertia_bl,
		"inertia_br=", wheel_inertia_br,
		"total_inertia=", total_inertia
	)
	var drive_torque_bl := wheel_inertia_bl * angular_acceleration
	var drive_torque_br := wheel_inertia_br * angular_acceleration

	var net_torque := 0.0
	debug_print("drive_torque_bl=", drive_torque_bl, " drive_torque_br=", drive_torque_br)
	net_torque += wheel_bl.apply_torque(
		drive_torque_bl,
		delta
	)
	net_torque += wheel_br.apply_torque(
		drive_torque_br,
		delta
	)

	return net_torque
