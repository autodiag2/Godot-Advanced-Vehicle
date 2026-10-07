#
# Wheel Assembly or Wheel Corner
#
class_name RaycastSuspension
extends RayCast3D

var wheel := WheelController.new()
var brake_disc := WheelDisc.new()
var suspension := SuspensionController.new()
var dynamics := WheelDynamicsController.new()
var parameters: WheelSuspensionParameters

var surface_mu := 1.0
var rol_res_surface_mul := 0.02

var local_vel := Vector3.ZERO
var z_vel := 0.0

var force_vec := Vector3.ZERO

var prev_pos := Vector3.ZERO

var spring_curr_length := 0.2

@onready var car = $'..'
@onready var wheelmesh = $MeshInstance3D


func _ready() -> void:
	prev_pos = global_transform.origin
	dynamics.setup(
		wheel,
		suspension
	)
	assert(dynamics != null)
	assert(wheel != null)
	assert(suspension != null)

func set_params(params: WheelSuspensionParameters) -> void:
	self.parameters = params
	wheel.setup(
		params.tire_model,
		params.wheel_mass,
		params.ackermann
	)
	brake_disc.effective_radius = params.brake_effective_radius
	suspension.setup(
		params.spring_length,
		params.spring_stiffness,
		params.bump,
		params.rebound,
		params.anti_roll
	)

	spring_curr_length = params.spring_length

	set_target_position(
		Vector3.DOWN * (
			params.spring_length +
			params.tire_model.radius
		)
	)


func _process(delta: float) -> void:
	wheelmesh.rotate_x(
		wrapf(
			-wheel.spin * delta,
			0,
			TAU
		)
	)

	wheelmesh.position.y = -spring_curr_length


func _physics_process(delta: float) -> void:
	if is_colliding():
		var tire_load := maxf(
			suspension.load_newton,
			0.0
		)

		if (
			abs(wheel.spin) > 10.0 or
			abs(z_vel) > 1.0
		):
			wheel.tire.update_wear(
				delta,
				wheel.slip,
				tire_load,
				surface_mu
			)

	var ambient_temp := 20.0
	var tire_load := maxf(
		suspension.load_newton,
		0.0
	)

	wheel.tire.update_temperature(
		wheel.slip,
		tire_load,
		local_vel.length(),
		surface_mu,
		ambient_temp,
		delta
	)


func apply_forces(opposite_comp, delta):
	force_vec = Vector3.ZERO

	local_vel = (
		global_transform.origin -
		prev_pos
	) / delta * global_transform.basis

	z_vel = -local_vel.z

	prev_pos = global_transform.origin

	if is_colliding():
		update_surface()

		spring_curr_length = (
			get_collision_point().distance_to(
				global_transform.origin
			) -
			wheel.tire.radius
		)

		var suspension_load := suspension.update(
			spring_curr_length,
			opposite_comp,
			delta
		)

		force_vec = dynamics.update(
			local_vel,
			suspension_load,
			surface_mu,
			delta
		)

		var contact : Vector3 = (
			get_collision_point() -
			car.global_transform.origin
		)

		var normal := get_collision_normal()

		car.apply_force(
			normal * suspension_load,
			contact
		)

		car.apply_force(
			global_transform.basis.x *
			force_vec.x,
			contact
		)

		car.apply_force(
			global_transform.basis.z *
			force_vec.y,
			contact
		)

		return suspension.load_mm

	spring_curr_length = suspension.spring_length

	wheel.spin -= (
		sign(wheel.spin) *
		delta *
		2.0 /
		wheel.inertia
	)

	return 0.0

func brake(clamping_factor: float) -> void:
	assert(0.0 <= clamping_factor)
	assert(clamping_factor <= 1.0)
	brake_disc.brake(clamping_factor)

func calculate_braked_torque_amount(torque: float) -> float:
	var brake_torque := (
		brake_disc.get_braking_factor() *
		parameters.brake_force *
		parameters.brake_effective_radius
	)
	var reduced_torque := absf(torque) - brake_torque
	return maxf(reduced_torque, 0.0)

# Apply torque to wheels and change it's spin
func apply_torque(
	torque,
	drive_inertia,
	delta,
	dryRun: bool = false
):
	var reduced_torque_abs := calculate_braked_torque_amount(torque)
	var torque_sign := signf(torque)
	var net_torque := wheel.apply_torque(
		reduced_torque_abs * torque_sign,
		drive_inertia,
		z_vel,
		delta,
		dryRun
	)

	if not dryRun:
		brake_disc.update_usage(
			reduced_torque_abs,
			wheel.spin,
			delta
		)

	return net_torque

func set_spin(value) -> void:
	wheel.set_spin(value)


func get_spin():
	return wheel.get_spin()

func steer(input, max_steer):
	rotation.y = wheel.steer(
		input,
		max_steer
	)


func update_surface() -> void:
	surface_mu = 1.0
	rol_res_surface_mul = 0.02

	var collider: Node = get_collider()
	var groups := collider.get_groups()

	if groups.size() == 0:
		return

	var surface = groups[0]

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
