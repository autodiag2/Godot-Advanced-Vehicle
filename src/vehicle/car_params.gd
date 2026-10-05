class_name CarParameters
extends Resource


enum DIFF_TYPE{
	LIMITED_SLIP,
	OPEN_DIFF,
	LOCKED,
}

enum DRIVE_TYPE{
	FWD,
	RWD,
	AWD,
}

@export var max_steer := 0.3
@export var ackermann := 0.15
@export var front_brake_bias := 0.6
@export var steer_speed := 5.0
@export var max_brake_force := 20000.0
@export var max_handbrake_torque := 1800.0
@export var max_handbrake_force := 2500.0
@export var brake_effective_radius := 0.25

@export var fuel_tank_size := 40.0 #Liters
@export var fuel_percentage := 100.0 # % of full tank

######### Engine variables #########
@export var engine: EngineParameters = EngineParameters.new()
@export var clutch_friction := 500.0

@export var drivetrain: DriveTrainParameters = DriveTrainParameters.new()

######### Aero #########
@export var cd = 0.3
@export var air_density = 1.225
@export var frontal_area = 2.0

@export var wheel_params_fl: WheelSuspensionParameters = WheelSuspensionParameters.new()
@export var wheel_params_fr: WheelSuspensionParameters = WheelSuspensionParameters.new()
@export var wheel_params_bl: WheelSuspensionParameters = WheelSuspensionParameters.new()
@export var wheel_params_br: WheelSuspensionParameters = WheelSuspensionParameters.new()
