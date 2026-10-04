class_name DriveTrainParameters
extends Resource


enum DRIVE_TYPE{
	FWD,
	RWD,
	AWD,
}

@export var drivetype := DRIVE_TYPE.RWD
@export var final_drive := 3.7

@export var gearbox: GearboxParameters = GearboxParameters.new()

@export var rear_diff: DiffParameters = DiffParameters.new()
@export var front_diff: DiffParameters = DiffParameters.new()
@export var center_diff: DiffParameters = DiffParameters.new()


@export var center_split_fr := 0.4 # AWD torque split front / rear, unused if central diff is not limited slip
