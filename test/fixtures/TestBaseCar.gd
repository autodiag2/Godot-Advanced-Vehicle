class_name TestBaseCar extends GutTest

const WORLDSIM_SCENE = preload("res://assets/WorldSim.tscn")
const VEHICLE_SCENE = preload("res://assets/vehicle/sport_car/vehicle.tscn")

class FakeCarInputController extends CarInputController:

	func update(input_joystick: Control) -> void:
		pass

var world_sim : WorldSim
var car : BaseCar

func before_each() -> void:
	world_sim = await _create_world_sim()
	car = world_sim.current_vehicle as BaseCar
	assert_not_null(car)

func after_each() -> void:
	world_sim.queue_free()

func _wait_for_vehicle_to_fall(car: BaseCar) -> void:
	for i in range(1000):
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
