extends Control

var wheel_fl: RaycastSuspension
var wheel_fr: RaycastSuspension
var wheel_bl: RaycastSuspension
var wheel_br: RaycastSuspension

func _ready() -> void:
	pass

func onSetVehicle(vehicle: BaseCar):
	wheel_bl = vehicle.wheel_bl
	wheel_br = vehicle.wheel_br
	wheel_fl = vehicle.wheel_fl
	wheel_fr = vehicle.wheel_fr

func get_tire_wear(wheel: RaycastSuspension) -> float:
	if wheel.wheel.tire == null:
		return 0.0
	return wheel.wheel.tire.wear

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$Panel/VBoxContainer/HBoxContainer/WheelFL/TireWearLabel.text = "%3.1f %% " % (get_tire_wear(wheel_fl) * 100)
	$Panel/VBoxContainer/HBoxContainer/WheelFR/TireWearLabel.text = "%3.1f %% " % (get_tire_wear(wheel_fr) * 100)
	$Panel/VBoxContainer/HBoxContainer2/WheelBL/TireWearLabel.text ="%3.1f %% " % (get_tire_wear(wheel_bl) * 100)
	$Panel/VBoxContainer/HBoxContainer2/WheelBR/TireWearLabel.text ="%3.1f %% " % (get_tire_wear(wheel_br) * 100)
	
	var colors := []
	for wheel in [wheel_fl, wheel_fr, wheel_bl, wheel_br]:
		if wheel.wheel.tire.temperature < wheel.wheel.tire.opt_temperature:
			colors.append(lerp(Color.AQUA, Color.GREEN, wheel.wheel.tire.temperature / wheel.wheel.tire.opt_temperature))
		else:
			var amount: float = (wheel.wheel.tire.temperature - wheel.wheel.tire.opt_temperature) / (wheel.wheel.tire.max_temperature - wheel.tire.opt_temperature)
			colors.append(lerp(Color.GREEN, Color.FIREBRICK, amount))
			
		
	$Panel/VBoxContainer/HBoxContainer/WheelFL/TireTemp.color = colors[0]
	$Panel/VBoxContainer/HBoxContainer/WheelFR/TireTemp.color = colors[1]
	$Panel/VBoxContainer/HBoxContainer2/WheelBL/TireTemp.color = colors[2]
	$Panel/VBoxContainer/HBoxContainer2/WheelBR/TireTemp.color = colors[3]
	
	$Panel/VBoxContainer/HBoxContainer/WheelFL/TireTemp/Label.text = "%2.1f c" % wheel_fl.wheel.tire.temperature
	$Panel/VBoxContainer/HBoxContainer/WheelFR/TireTemp/Label.text = "%2.1f c" % wheel_fr.wheel.tire.temperature
	$Panel/VBoxContainer/HBoxContainer2/WheelBL/TireTemp/Label.text = "%2.1f c" % wheel_bl.wheel.tire.temperature
	$Panel/VBoxContainer/HBoxContainer2/WheelBR/TireTemp/Label.text = "%2.1f c" % wheel_br.wheel.tire.temperature
	
