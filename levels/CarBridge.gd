extends Node

var bridge = null

func _ready():

	var wrapper = Engine.get_singleton(
        "JavaClassWrapper"
	)

	if wrapper == null:
		print("JavaClassWrapper not found")
		return

	bridge = wrapper.wrap(
        "com.github.autodiag2.elm327emu.sim.CarBridge"
	)

	if bridge == null:
		print("Failed to wrap Kotlin CarBridge")
		return


func _process(_delta):
	print("CarBridge _process")

	if bridge == null:
		print("bridge is null")
		return

	var car = get_tree().get_first_node_in_group(
        "player_car"
	)

	if car == null:
		print("player_car not found")
		return

	bridge.setRpm(car.rpm)
	bridge.setFuel(car.fuel / car.car_params.fuel_tank_size)
	bridge.setSpeed(car.speedo)
	bridge.setAcceratorRelativePosition(car.throttle_input)
	bridge.setActualEnginePercentTorque(car.torque_out / car.max_torque * 100)
