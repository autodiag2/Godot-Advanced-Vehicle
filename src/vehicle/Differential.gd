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

var _diff_clutch := Clutch.new()
var _diff_split := 0.5
var parameters := DiffParameters.new()
var wheel_fl: RaycastSuspension
var wheel_fr: RaycastSuspension
var wheel_bl: RaycastSuspension
var wheel_br: RaycastSuspension
var type : DIFF_TYPE = DIFF_TYPE.LOCKED

func initialise(parameters_arg: DiffParameters, wheel_fl: RaycastSuspension, wheel_fr: RaycastSuspension, wheel_bl: RaycastSuspension, wheel_br: RaycastSuspension):
	assert(parameters_arg != null)
	parameters = parameters_arg
	self.wheel_bl = wheel_bl
	self.wheel_br = wheel_br
	self.wheel_fl = wheel_fl
	self.wheel_fr = wheel_fr

func set_type(type: DIFF_TYPE):
	self.type = type

func debug_print(...args) -> void:
	args.push_front("DIFFERENTIAL")
	super.debug_print(args)

func calculate_inertia() -> float:
	var wheels_inertia := 0.0

	for wheel in [wheel_bl, wheel_br, wheel_fl, wheel_fr]:
		wheels_inertia += wheel.wheel.inertia

	return wheels_inertia

func calculate_torque(delta: float) -> float:
	var torque := 0.0
	for wheel in [wheel_bl,wheel_br,wheel_fl,wheel_fr]:
		torque += wheel.calculate_torque(delta)
	return torque

func apply_torque(
	torque: float,
	delta: float
) -> float:
	assert(delta >= 0.0)

	wheel_bl.apply_torque(torque/4.0, delta)
	wheel_br.apply_torque(torque/4.0, delta)
	wheel_fl.apply_torque(torque/4.0, delta)
	wheel_fr.apply_torque(torque/4.0, delta)
	return 0.0
