class_name VehicleMotionController
extends RefCounted

var local_velocity := Vector3.ZERO
var longitudinal_velocity: float = 0.0
var lateral_velocity: float = 0.0
var zero_threshold := 0.001
var previous_position := Vector3.ZERO

func initialize(car: Node3D) -> void:
	previous_position = car.global_transform.origin

func update(
	car: Node3D,
	delta: float
) -> void:
	var local_velocity : Vector3 = (
		car.global_transform.basis.inverse() *
		car.linear_velocity
	)
	previous_position = (
		car.global_transform.origin
	)

	longitudinal_velocity = (
		-local_velocity.z
	)

	lateral_velocity = (
		local_velocity.x
	)

	print("local_velocity=", local_velocity, " longitudinal_velocity=", longitudinal_velocity, " lateral_velocity=", lateral_velocity)

func apply_aerodynamic_drag(
	car: RigidBody3D,
	parameters: CarParameters
) -> void:
	var speed: float = (
		sqrt(
			lateral_velocity *
			lateral_velocity +
			longitudinal_velocity *
			longitudinal_velocity
		)
	)

	var aerodynamic_drag_coefficient: float = (
		0.5 *
		parameters.cd *
		parameters.frontal_area *
		parameters.air_density
	)

	var drag_force := Vector2.ZERO

	drag_force.y = (
		clamp(
			aerodynamic_drag_coefficient *
			longitudinal_velocity *
			speed,
			-100000.0,
			100000.0
		)
	)

	drag_force.x = (
		clamp(
			-aerodynamic_drag_coefficient *
			lateral_velocity *
			speed,
			-100000.0,
			100000.0
		)
	)

	car.apply_central_force(
		car.global_transform.basis.z.normalized() *
		drag_force.y
	)

	car.apply_central_force(
		car.global_transform.basis.x.normalized() *
		drag_force.x
	)
