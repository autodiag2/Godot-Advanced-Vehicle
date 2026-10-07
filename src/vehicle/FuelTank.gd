
class_name FuelTank extends RefCounted
var fuel_litres: float = 0.0
var vehicle: RigidBody3D

func initialise(
	parameters_arg: CarParameters,
	vehicle_arg: RigidBody3D
):
	assert(vehicle_arg != null)
	assert(parameters_arg != null)
	assert(parameters_arg.fuel_tank_size >= 0.0)
	assert(parameters_arg.fuel_percentage >= 0.0)
	assert(parameters_arg.fuel_percentage <= 100.0)
	vehicle = vehicle_arg
	fuel_litres = (
		parameters_arg.fuel_tank_size *
		parameters_arg.fuel_percentage *
		0.01
	)
	vehicle.mass += (
		fuel_litres *
		EngineController.PETROL_KG_PER_LITRE
	)

func consume(fuel_consumed: float):
	fuel_consumed = min(
		fuel_consumed,
		fuel_litres
	)

	fuel_consumed = max(
		fuel_consumed,
		0.0
	)

	fuel_litres -= fuel_consumed
	vehicle.mass -= (
		fuel_consumed *
		EngineController.PETROL_KG_PER_LITRE
	)
