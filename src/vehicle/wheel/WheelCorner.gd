#
# Wheel Assembly or Wheel Corner
#
class_name WheelCorner
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

@onready var car: Vehicle = $'..'
@onready var wheel_view : Node3D = $MeshInstance3D

var parent:= Controller.new()

func _init() -> void:
	parent.TAG_NAME = "RAYCAST"
	
func _ready() -> void:
	assert(dynamics != null)
	dynamics.setup(
		wheel,
		suspension
	)
	assert(wheel != null)
	assert(suspension != null)

	wheel.set_view(wheel_view)

func set_params(params: WheelSuspensionParameters) -> void:
	assert(params != null)
	assert(params.tire_model != null)
	assert(0.0 < params.tire_model.radius)
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
	wheel.view_update(delta)
	wheel.view.position.y = -spring_curr_length

func _physics_process(delta: float) -> void:
	if is_colliding():
		@warning_ignore("confusable_local_declaration")
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

func spawn():
	prev_pos = global_transform.origin
	wheel.set_spin(0.0)

var previous_sign : float = 0.0
var current_suspension_load : float = 0.0
func apply_forces(opposite_comp, delta):
	force_vec = Vector3.ZERO
		
	local_vel = (
		global_transform.origin -
		prev_pos
	) / delta * global_transform.basis

	z_vel = -local_vel.z

	var world_velocity : Vector3 = (global_transform.origin - prev_pos) / delta

	parent.debug_print("XX car linear velocity=", car.linear_velocity)
	parent.debug_print("XX car angular velocity=", car.angular_velocity)
	parent.debug_print("XX raycast world velocity=", world_velocity)
	parent.debug_print("XX raycast forward=", -global_transform.basis.z)
	parent.debug_print("XX car forward=", -car.global_transform.basis.z)
	parent.debug_print("XX raycast local velocity=", global_transform.basis * world_velocity)

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
		current_suspension_load = suspension_load
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
		parent.debug_print("apply force(", normal * suspension_load, contact, ")")
		
		if false:
			car.apply_force(
				global_transform.basis.x *
				force_vec.x,
				contact
			)
			parent.debug_print("apply force(", global_transform.basis.x * force_vec.x, contact, ")")
		
			if previous_sign != null:
				if ( signf(previous_sign) != signf(force_vec.y)):
					parent.debug_print("OSCILLATION DETECTED prev=", previous_sign, " next=", force_vec.y)

			previous_sign = force_vec.y
			car.apply_force(
				global_transform.basis.z *
				-absf(force_vec.y),
				contact
			)
			parent.debug_print("apply force(", global_transform.basis.z * force_vec.y, contact, ")")

		return suspension.load_mm

	spring_curr_length = suspension.spring_length

	wheel.set_spin(wheel.spin - (
		sign(wheel.spin) *
		delta *
		2.0 /
		wheel.inertia
	))

	return 0.0

func brake(clamping_factor: float) -> void:
	assert(0.0 <= clamping_factor)
	assert(clamping_factor <= 1.0)
	brake_disc.brake(clamping_factor)

# Always positive
func get_brake_torque() -> float:
	return (
		brake_disc.get_braking_factor() *
		parameters.brake_force *
		parameters.brake_effective_radius
	)

func calculate_braked_torque_amount(torque: float) -> float:
	var brake_torque := get_brake_torque()
	var reduced_torque := absf(torque) - brake_torque
	return maxf(reduced_torque, 0.0)

func get_reaction_torque() -> float:
	var brake_torque := get_brake_torque()
	var rolling_resistance := wheel.tire.get_rolling_resistance(current_suspension_load, z_vel)
	var spin_sign := signf(wheel.spin)

	if spin_sign == 0.0:
		return rolling_resistance

	return rolling_resistance + spin_sign * brake_torque

func calculate_torque(delta: float) -> float:
	assert(0.0 <= delta)
	return -get_reaction_torque()

# Apply torque to wheels and change it's spin
func apply_torque(
	net_torque: float,
	delta: float
):
	var wheel_net_torqure := wheel.apply_torque(
		net_torque,
		get_brake_torque(),
		0.0,
		delta
	)
	
	if is_colliding():
		var contact : Vector3 = (
			get_collision_point() -
			car.global_transform.origin
		)
		if false:
			car.apply_force(
				global_transform.basis.x *
				force_vec.x,
				contact
			)
			parent.debug_print("apply force(", global_transform.basis.x * force_vec.x, contact, ")")

		var force : float = wheel_net_torqure / wheel.tire.radius
		car.apply_force(
			-global_transform.basis.z *
			force,
			contact
		)

	brake_disc.update_usage(
		get_brake_torque(),
		wheel.spin,
		delta
	)

	return wheel_net_torqure

func set_spin(value) -> void:
	wheel.set_spin(value)

func get_spin() -> float:
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
