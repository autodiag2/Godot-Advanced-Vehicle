extends GutTest

const WORLDSIM_SCENE = preload("res://assets/WorldSim.tscn")
const VEHICLE_SCENE = preload("res://assets/vehicle/sport_car/vehicle.tscn")

class FakeCarInputController extends CarInputController:

	func update(input_joystick: Control) -> void:
		pass

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


func _create_world_sim() -> WorldSim:
	var world_sim := WORLDSIM_SCENE.instantiate() as WorldSim
	add_child(world_sim)
	await get_tree().process_frame
	world_sim.load_vehicle(VEHICLE_SCENE)
	await get_tree().physics_frame

	var car := world_sim.current_vehicle as BaseCar
	assert_not_null(car)
	var inputController = FakeCarInputController.new()
	car.input_controller = inputController
	car.global_position = Vector3(0.0, 1.0, 0.0)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO

	await _wait_for_vehicle_to_fall(car)

	_wait_physics_seconds(0.5)
	car.start()
	_wait_physics_seconds(0.2)
	return world_sim

func _wait_physics_seconds(seconds: float) -> void:
	assert(seconds >= 0.0)

	var physics_ticks_per_second := Engine.physics_ticks_per_second
	var frame_count := ceili(
		seconds *
		physics_ticks_per_second
	)

	for i in range(frame_count):
		await get_tree().physics_frame

func test_car_accelerates_with_throttle() -> void:

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

	var initial_velocity := car.linear_velocity
	car.shift_up()
	await _wait_physics_seconds(2)
	car.input_controller.throttle = 1.0
	await _wait_physics_seconds(4)

	assert_gt(
		-car.linear_velocity.z,
		0.0,
		"Throttle input must accelerate the car forward"
	)

	assert_gt(
		-car.linear_velocity.z,
		-initial_velocity.z,
		"Throttle input must increase forward velocity"
	)

	world_sim.queue_free()
	gut.p("test_car_accelerates_with_throttle DONE")

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
