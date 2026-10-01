class_name RaycastSuspension
extends RayCast3D

############# Choose what tire formula to use #############
var tire_model: TireModel

############# Suspension stuff #############
var spring_length = 0.2
var spring_stiffness = 45.0
var bump = 3.5
var rebound = 4.0
var anti_roll = 0.0

var spring_load_mm: float = 0
var prev_spring_load_mm: float = 0
var spring_speed_mm_per_seconds: float = 0
var spring_load_newton: float = 0

############# Wheel stuff #############
var wheel_mass = 15.0
var ackermann = 0.15

var surface_mu = 1.0
var y_force: float = 0.0

var wheel_inertia: float = 0.0
var spin: float = 0.0
var z_vel: float = 0.0
var local_vel := Vector3.ZERO

var rol_res_surface_mul: float = 0.02

var force_vec = Vector3.ZERO
var slip_vec: Vector2 = Vector2.ZERO
var prev_pos: Vector3 = Vector3.ZERO

var spring_curr_length: float = spring_length

var wheel_speed_threshold: float = 0.1

@onready var car = $'..'
@onready var wheelmesh = $MeshInstance3D


func _ready() -> void:
	prev_pos = global_transform.origin


func set_params(params: WheelSuspensionParameters):
	tire_model = params.tire_model
	spring_length = params.spring_length
	spring_stiffness = params.spring_stiffness
	bump = params.bump
	rebound = params.rebound
	wheel_mass = params.wheel_mass
	ackermann = params.ackermann
	anti_roll = params.anti_roll

	wheel_inertia = 0.5 * wheel_mass * pow(tire_model.radius, 2)
	set_target_position(
		Vector3.DOWN * (spring_length + tire_model.radius)
	)

# Move back to physics process when physics interpolation comes to godot4
func _process(delta: float) -> void:
	wheelmesh.rotate_x(wrapf(-spin * delta, 0, TAU))
	wheelmesh.position.y = -spring_curr_length


func _physics_process(delta: float) -> void:
	var spin_treshold := 10.0

	if is_colliding():
		var tire_load := maxf(y_force, 0.0)

		if abs(spin) > spin_treshold or abs(z_vel) > 1.0:
			tire_model.update_wear(
				delta,
				slip_vec,
				tire_load,
				surface_mu
			)

	var ambient_temp := 20.0
	var tire_load := maxf(y_force, 0.0)

	tire_model.update_temperature(
		slip_vec,
		tire_load,
		local_vel.length(),
		surface_mu,
		ambient_temp,
		delta
	)


func apply_forces(opposite_comp, delta):
	############# Local forward velocity #############
	force_vec = Vector3.ZERO

	local_vel = (global_transform.origin - prev_pos) / delta * global_transform.basis
	z_vel = -local_vel.z
	var planar_vect = Vector2(local_vel.x, local_vel.z).normalized()
	prev_pos = global_transform.origin

	var surface

	############# Suspension #################
	if is_colliding():
		if get_collider().get_groups().size() > 0:
			surface = get_collider().get_groups()[0]

		if surface:
			surface_mu = 1.0

			if surface == "Tarmac":
				surface_mu = 0.85
				rol_res_surface_mul = 0.01
			elif surface == "Gravel":
				surface_mu = 0.6
				rol_res_surface_mul = 0.03
			elif surface == "Grass":
				surface_mu = 0.55
				rol_res_surface_mul = 0.025
			elif surface == "Snow":
				surface_mu = 0.4
				rol_res_surface_mul = 0.035

		spring_curr_length = (
			get_collision_point().distance_to(global_transform.origin) -
			tire_model.radius
		)
	else:
		spring_curr_length = spring_length

	# Calculate the spring load in mm (absolut)
	spring_load_mm = (spring_length - spring_curr_length) * 1000

	# Calculate spring movement in mm per seconds
	spring_speed_mm_per_seconds = (
		spring_load_mm - prev_spring_load_mm
	) / delta
	prev_spring_load_mm = spring_load_mm

	# Calculate the force of the spring in N
	spring_load_newton = spring_load_mm * spring_stiffness

	# Calculate the damping force in N and add it to spring_load_newton
	if spring_speed_mm_per_seconds >= 0:
		spring_load_newton += spring_speed_mm_per_seconds * bump
	else:
		spring_load_newton += spring_speed_mm_per_seconds * rebound

	y_force = spring_load_newton

	############### Slip #######################
	slip_vec.x = asin(clamp(-planar_vect.x, -1, 1))
	slip_vec.y = 0.0

	if is_colliding():
		var slip_speed: float = max(
			abs(z_vel),
			wheel_speed_threshold
		)

		slip_vec.y = (
			z_vel -
			spin * tire_model.radius
		) / slip_speed

		if spring_load_mm != 0:
			y_force += anti_roll * (spring_load_mm - opposite_comp)

		y_force = maxf(y_force, 0.0)

		force_vec = tire_model.update_tire_forces(
			slip_vec,
			y_force,
			surface_mu
		)

		force_vec.y += tire_model.get_rolling_resistance(
			y_force,
			z_vel
		)

		var contact = get_collision_point() - car.global_transform.origin
		var normal = get_collision_normal()

		car.apply_force(normal * y_force, contact)
		car.apply_force(global_transform.basis.x * force_vec.x, contact)
		car.apply_force(global_transform.basis.z * force_vec.y, contact)

		return spring_load_mm
	else:
		spin -= sign(spin) * delta * 2 / wheel_inertia
		return 0.0


func apply_torque(drive_torque, brake_torque, drive_inertia, delta):
	var prev_spin = spin
	var net_torque = force_vec.y * tire_model.radius
	net_torque += drive_torque

	if abs(spin) < 5 and brake_torque > abs(net_torque):
		spin = 0
	else:
		if drive_torque == 0.0:
			var target_spin: float = 0.0

			if abs(z_vel) >= wheel_speed_threshold:
				target_spin = z_vel / tire_model.radius

			var spin_error := target_spin - spin
			net_torque += spin_error * wheel_inertia / delta

		net_torque -= brake_torque * sign(spin)
		spin += delta * net_torque / (wheel_inertia + drive_inertia)

	if drive_torque * delta == 0:
		return 0.5
	else:
		return (
			(spin - prev_spin) *
			(wheel_inertia + drive_inertia) /
			(drive_torque * delta)
		)


func set_spin(value):
	spin = value


func get_spin():
	return spin


func get_reaction_torque():
	return force_vec.y * tire_model.radius


func steer(input, max_steer):
	rotation.y = max_steer * (
		input +
		(1 - cos(input * 0.5 * PI)) * ackermann
	)
