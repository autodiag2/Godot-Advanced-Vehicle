class_name WheelController

var tire_model: TireModel

var wheel_mass := 15.0
var wheel_inertia := 0.0
var ackermann := 0.15

var spin := 0.0

var slip := Vector2.ZERO
var force := Vector3.ZERO

var wheel_speed_threshold := 0.1


func setup(
	tire: TireModel,
	mass: float,
	ackermann_value: float
) -> void:
	tire_model = tire
	wheel_mass = mass
	ackermann = ackermann_value
	wheel_inertia = 0.5 * wheel_mass * pow(tire_model.radius, 2)


func update_slip(
	z_vel: float,
	lateral_slip: float
) -> void:
	slip.x = lateral_slip

	if abs(z_vel) >= wheel_speed_threshold:
		slip.y = (
			z_vel -
			spin * tire_model.radius
		) / abs(z_vel)
	else:
		slip.y = 0.0


func update_force(
	normal_load: float,
	surface_mu: float
) -> Vector3:
	force = tire_model.update_forces(
		slip,
		normal_load,
		surface_mu
	)

	return force


func apply_torque(
	drive_torque: float,
	brake_torque: float,
	drive_inertia: float,
	z_vel: float,
	delta: float
) -> float:
	var previous_spin := spin
	var net_torque := force.y * tire_model.radius
	net_torque += drive_torque

	if abs(spin) < 5 and brake_torque > abs(net_torque):
		spin = 0.0
	else:
		if drive_torque == 0.0:
			var target_spin := 0.0

			if abs(z_vel) >= wheel_speed_threshold:
				target_spin = z_vel / tire_model.radius

			var spin_error := target_spin - spin
			net_torque += spin_error * wheel_inertia / delta

		net_torque -= brake_torque * sign(spin)

		spin += (
			delta *
			net_torque /
			(wheel_inertia + drive_inertia)
		)

	if drive_torque * delta == 0:
		return 0.5

	return (
		(spin - previous_spin) *
		(wheel_inertia + drive_inertia) /
		(drive_torque * delta)
	)


func get_reaction_torque() -> float:
	return force.y * tire_model.radius


func set_spin(value: float) -> void:
	spin = value


func get_spin() -> float:
	return spin


func steer(input: float, max_steer: float) -> float:
	return max_steer * (
		input +
		(1.0 - cos(input * 0.5 * PI)) * ackermann
	)
