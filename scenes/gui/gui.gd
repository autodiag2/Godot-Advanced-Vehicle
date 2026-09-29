extends Control


@onready var car = get_parent()
@onready var speedlabel = $Essentials/VBoxContainer/Speedlabel
@onready var gearlabel = $Essentials/VBoxContainer/GearLabel
@onready var rpmlabel = $Essentials/VBoxContainer/RpmLabel
@onready var fuellabel = $Essentials/VBoxContainer/FuelLabel


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	speedlabel.text = "Speed = %d" % int(car.powertrain_controller.average_front_wheel_speed * car.wheel_fl.tire_radius * 3.6)
	gearlabel.text = "gear = %d" % car.powertrain_controller.drivetrain.selected_gear
	rpmlabel.text = "RPM = %d" % int(car.engine_controller.rpm)
	fuellabel.text = "Fuel = %3.2f" % car.engine_controller.fuel_litres
