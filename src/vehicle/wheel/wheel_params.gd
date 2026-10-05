class_name WheelSuspensionParameters
extends Resource

@export var tire_model: TireModel = CurveTireModel.new()
@export var spring_length := 0.15
@export var spring_stiffness := 45.0
@export var bump := 6.0
@export var rebound := 7.0
@export var wheel_mass := 20.0
@export var anti_roll := 1.0
@export var brake_effective_radius := 0.13
@export var brake_force := 6000.0 # N
var ackermann := 0.15
