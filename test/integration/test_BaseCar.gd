extends GutTest

const WORLDSIM_SCENE = preload("res://assets/WorldSim.tscn")
const VEHICLE_SCENE = preload("res://assets/vehicle/sport_car/vehicle.tscn")


func _wait_for_vehicle_to_fall(car: BaseCar) -> void:
	for i in range(120):
		await get_tree().physics_frame

		if (
			car.wheel_fl.is_colliding() &&
			car.wheel_fr.is_colliding() &&
			car.wheel_bl.is_colliding() &&
			car.wheel_br.is_colliding()
		):
			return


func _create_ground() -> StaticBody3D:
	var ground := StaticBody3D.new()

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100.0, 0.1, 100.0)
	collision.shape = shape

	ground.add_child(collision)
	add_child(ground)

	return ground


func _create_world_sim() -> WorldSim:
	var world_sim := WORLDSIM_SCENE.instantiate() as WorldSim
	add_child(world_sim)
	await get_tree().process_frame
	world_sim.load_vehicle(VEHICLE_SCENE)
	await get_tree().physics_frame

	var car := world_sim.current_vehicle as BaseCar
	assert_not_null(car)

	car.global_position = Vector3(0.0, 1.0, 0.0)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO

	await _wait_for_vehicle_to_fall(car)

	for i in range(30):
		await get_tree().physics_frame

	return world_sim


func test_near_zero_planar_velocity_does_not_create_lateral_tire_force() -> void:
	var world_sim := await _create_world_sim()
	var car := world_sim.current_vehicle as BaseCar
	assert_not_null(car)

	var wheel: RaycastSuspension = car.wheel_fl
	var dynamics := wheel.dynamics

	var local_velocity := Vector3(
		0.034027,
		-3.598442,
		0.007327
	)

	var normal_load := 5000.0
	var surface_mu := 1.0

	var force := dynamics.update(
		local_velocity,
		normal_load,
		surface_mu,
		0.016
	)

	var tire_force_y := force.y - dynamics.rolling_resistance

	assert_lt(
		absf(tire_force_y),
		1.0,
		"Near-zero planar velocity must not generate a significant tire force"
	)

	world_sim.queue_free()


func test_car_at_rest_does_not_start_wheels_spinning() -> void:
	_create_ground()

	var world_sim := await _create_world_sim()
	var car := world_sim.current_vehicle as BaseCar
	assert_not_null(car)

	assert_true(
		car.wheel_fl.is_colliding(),
		"Front-left wheel must be in contact with the ground"
	)
	assert_true(
		car.wheel_fr.is_colliding(),
		"Front-right wheel must be in contact with the ground"
	)
	assert_true(
		car.wheel_bl.is_colliding(),
		"Rear-left wheel must be in contact with the ground"
	)
	assert_true(
		car.wheel_br.is_colliding(),
		"Rear-right wheel must be in contact with the ground"
	)

	assert_false(
		car.engine_controller.combustion_running,
		"Engine must not be running"
	)

	assert_almost_eq(
		car.wheel_fl.get_spin(),
		0.0,
		0.001,
		"Front-left wheel must not start spinning at rest"
	)
	assert_almost_eq(
		car.wheel_fr.get_spin(),
		0.0,
		0.001,
		"Front-right wheel must not start spinning at rest"
	)
	assert_almost_eq(
		car.wheel_bl.get_spin(),
		0.0,
		0.001,
		"Rear-left wheel must not start spinning at rest"
	)
	assert_almost_eq(
		car.wheel_br.get_spin(),
		0.0,
		0.001,
		"Rear-right wheel must not start spinning at rest"
	)

	world_sim.queue_free()
