extends Button

var vehicle: BaseCar

func _ready() -> void:
	pressed.connect(_on_pressed)

func onSetVehicle(new_vehicle: BaseCar) -> void:
	vehicle = new_vehicle
	set_pressed_no_signal(vehicle.car_params.drivetrain_params.automatic)

func _on_pressed() -> void:
	if vehicle == null:
		return
	vehicle.car_params.drivetrain_params.automatic = button_pressed
