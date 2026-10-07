class_name WheelController extends Controller

var tire: TireModel

const MASS_DEFAULT := 15.0
var mass := MASS_DEFAULT
var inertia := 0.0
const ACKERMANN_DEFAULT := 0.15
var ackermann := ACKERMANN_DEFAULT

var spin := 0.0

var slip := Vector2.ZERO
var force := Vector3.ZERO

var speed_threshold := 0.1

var view: WheelView

func set_view(view_arg: WheelView):
	self.view = view_arg

func debug_print(...args) -> void:
	args.push_front("WHEEL")
	super.debug_print(args)

func setup(
	tire_arg: TireModel,
	mass_arg: float = MASS_DEFAULT,
	ackermann_arg: float = ACKERMANN_DEFAULT
) -> void:
	assert(tire_arg != null)
	assert(mass_arg > 0.0)
	assert(tire_arg.radius > 0.0)

	tire = tire_arg
	mass = mass_arg
	ackermann = ackermann_arg
	inertia = 0.5 * mass * pow(tire.radius, 2)

	spin = 0.0
	slip = Vector2.ZERO
	force = Vector3.ZERO


func update_slip(
	longitudinal_vel: float,
	lateral_slip: float
) -> Vector2:
	assert(speed_threshold > 0.0)

	var wheel_velocity := spin * tire.radius

	slip.x = lateral_slip

	if (
		absf(longitudinal_vel) < speed_threshold and
		absf(wheel_velocity) < speed_threshold
	):
		slip.y = 0.0
	else:
		var slip_speed := maxf(
			absf(longitudinal_vel),
			speed_threshold
		)

		slip.y = (
			longitudinal_vel -
			wheel_velocity
		) / slip_speed

	debug_print("longitudinal_vel=", longitudinal_vel, " lateral_slip=", lateral_slip)
	debug_print("slip.y=", slip.y)

	return slip

func update_force(
	normal_load: float,
	surface_mu: float
) -> Vector3:
	assert(tire != null)
	
	debug_print("slip=", slip)

	force = tire.update_forces(
		slip,
		normal_load,
		surface_mu
	)
	debug_print("force=", force)

	return force

func apply_torque(
	drive_torque: float,
	drive_inertia: float,
	z_vel: float,
	delta: float,
	dryRun: bool = false
) -> float:
	assert(tire != null)
	assert(0.0 <= drive_inertia)

	if delta <= 0.0:
		return 0.0

	var total_inertia := inertia + drive_inertia

	assert(total_inertia > 0.0)

	var reaction_torque := force.y * tire.radius
	debug_print("reaction_torque=", reaction_torque)
	
	var net_torque := drive_torque - reaction_torque

	var stopping_torque := (
		-spin *
		total_inertia /
		delta
	)

	if (
		spin != 0.0 and
		sign(net_torque) == sign(stopping_torque) and
		absf(net_torque) > absf(stopping_torque)
	):
		net_torque = stopping_torque

	var spin_delta := (
		delta *
		net_torque /
		total_inertia
	)

	var next_spin := spin + spin_delta

	if not dryRun:
		set_spin(next_spin)

	return reaction_torque


func set_spin(value: float) -> void:
	spin = value
	#assert(spin == 0.0)

func get_spin() -> float:
	return spin


func steer(input: float, max_steer: float) -> float:
	var correction := (
		1.0 -
		cos(abs(input) * 0.5 * PI)
	) * ackermann

	return max_steer * (
		input +
		sign(input) * correction
	)
