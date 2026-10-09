class_name EngineParameters
extends Resource

@export var max_torque := 250.0
@export var max_rpm := 8000.0
@export var rpm_idle := 900.0
@export var torque_curve := Curve.new()
@export var throttle_model := Curve.new()
@export var brake_torque := 10.0 # N.m
@export var moment := 0.25 # inertia kg.m-2
@export var bsfc_map: EngineBSFCMap = preload("res://assets/vehicle/sport_car/petrol_bsfc.tres") # g/kWh
@export var idle_fuel_rate := 0.8 # L/h
@export var sound: AudioStream
@export var starter_sound: AudioStream
