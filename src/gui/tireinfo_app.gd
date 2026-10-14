extends Control

var wheel_fl
var wheel_fr
var wheel_bl
var wheel_br

var wheels : Array[RaycastSuspension]:
	get():
		return [wheel_fl, wheel_fr, wheel_bl, wheel_br]

func onSetVehicle(vehicle: BaseCar):
	wheel_bl = vehicle.wheel_bl
	wheel_br = vehicle.wheel_br
	wheel_fl = vehicle.wheel_fl
	wheel_fr = vehicle.wheel_fr
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	$Panel/VBoxContainer/HBoxContainer/WheelFL/TireWearLabel.text = "%3.1f %% " % float(wheel_fl.tire_wear * 100)
	$Panel/VBoxContainer/HBoxContainer/WheelFR/TireWearLabel.text = "%3.1f %% " % float(wheel_fr.tire_wear * 100)
	$Panel/VBoxContainer/HBoxContainer2/WheelBL/TireWearLabel.text ="%3.1f %% " % float(wheel_bl.tire_wear * 100)
	$Panel/VBoxContainer/HBoxContainer2/WheelBR/TireWearLabel.text ="%3.1f %% " % float(wheel_br.tire_wear * 100)
	
	var colors := []
	for wheel in wheels:
		if wheel.tire_model.tire_temp < wheel.tire_model.opt_tire_temp:
			colors.append(lerp(Color.AQUA, Color.GREEN, wheel.tire_model.tire_temp / wheel.tire_model.opt_tire_temp))
		else:
			var amount: float = (wheel.tire_model.tire_temp - wheel.tire_model.opt_tire_temp) / (wheel.tire_model.max_tire_temp - wheel.tire_model.opt_tire_temp)
			colors.append(lerp(Color.GREEN, Color.FIREBRICK, amount))
			
		
	$Panel/VBoxContainer/HBoxContainer/WheelFL/TireTemp.color = colors[0]
	$Panel/VBoxContainer/HBoxContainer/WheelFR/TireTemp.color = colors[1]
	$Panel/VBoxContainer/HBoxContainer2/WheelBL/TireTemp.color = colors[2]
	$Panel/VBoxContainer/HBoxContainer2/WheelBR/TireTemp.color = colors[3]
	
	$Panel/VBoxContainer/HBoxContainer/WheelFL/TireTemp/Label.text = "%2.1f c" % wheel_fl.tire_model.tire_temp
	$Panel/VBoxContainer/HBoxContainer/WheelFR/TireTemp/Label.text = "%2.1f c" % wheel_fr.tire_model.tire_temp
	$Panel/VBoxContainer/HBoxContainer2/WheelBL/TireTemp/Label.text = "%2.1f c" % wheel_bl.tire_model.tire_temp
	$Panel/VBoxContainer/HBoxContainer2/WheelBR/TireTemp/Label.text = "%2.1f c" % wheel_br.tire_model.tire_temp
	
