class_name WheelController extends Controller

var tire: TireModel

const MASS_DEFAULT := 15.0
var mass := MASS_DEFAULT
var inertia := 0.0
const ACKERMANN_DEFAULT := 0.15
var ackermann := ACKERMANN_DEFAULT

var spin := 0.0
var previous_spin := 0.0

var slip := Vector2.ZERO
var force := Vector3.ZERO

var speed_threshold := 0.1

var view: Node3D

func _init() -> void:
	TAG_NAME = "WHEEL"

func set_view(view_arg: Node3D):
	assert(view_arg != null)
	self.view = view_arg

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

func update_slip(longitudinal_vel: float, lateral_slip: float) -> Vector2:
	assert(speed_threshold > 0.0)

	var wheel_velocity := spin * tire.radius

	debug_print(
		"SLIP INPUT: longitudinal_vel=", longitudinal_vel,
		" spin=", spin,
		" radius=", tire.radius,
		" wheel_velocity=", wheel_velocity,
		" speed_threshold=", speed_threshold
	)

	slip.x = lateral_slip
	if absf(longitudinal_vel) < speed_threshold and absf(wheel_velocity) < speed_threshold:
		slip.y = 0.0
	else:
		var slip_speed := maxf(absf(longitudinal_vel), speed_threshold)
		slip.y = (longitudinal_vel - wheel_velocity) / slip_speed

	debug_print(
		"SLIP OUTPUT: longitudinal_vel=", longitudinal_vel,
		" wheel_velocity=", wheel_velocity,
		" slip_speed=", maxf(absf(longitudinal_vel), speed_threshold),
		" raw_slip=", (longitudinal_vel - wheel_velocity) / maxf(absf(longitudinal_vel), speed_threshold),
		" final_slip=", slip.y
	)

	debug_print("update_slip: slip=", slip)
	return slip

func view_update(delta: float):
	assert(view != null)
	view.rotate_x(-spin * delta)

func update_force(
	normal_load: float,
	surface_mu: float
) -> Vector3:
	assert(tire != null)
	
	force = tire.update_forces(
		slip,
		normal_load,
		surface_mu
	)
	debug_print("update_force: force=", force)

	return force

func get_road_reaction_torque() -> float:
	var torque := 0.0 #force.y * tire.radius
	debug_print("get_road_reaction_torque=", torque)
	return torque

func apply_torque(
	net_torque: float,
	drive_inertia: float,
	delta: float
) -> float:
	assert(tire != null)
	assert(drive_inertia >= 0.0)
	assert(0.0 <= delta)

	var total_inertia := inertia + drive_inertia
	assert(total_inertia > 0.0)

	if delta == 0.0:
		return net_torque

	var spin_acceleration := net_torque / total_inertia
	var next_spin := spin + delta * spin_acceleration

	if signf(spin) != 0.0 and signf(next_spin) != signf(spin):
		if signf(net_torque) != signf(spin):
			next_spin = 0.0

	debug_print("apply_torque: next_spin=", next_spin, " torque=", net_torque)
	set_spin(next_spin)

	return net_torque

func set_spin(value: float) -> void:
	previous_spin = spin
	spin = value

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
