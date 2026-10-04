class_name EngineBSFCMap
extends Resource


@export var rows: Array[EngineBSFCMapRow] = []


func sample(rpm: float, load: float) -> float:
	assert(rpm >= 0.0)
	assert(load >= 0.0)
	assert(load <= 1.0)
	assert(rows.size() >= 2)

	var rpm_index := _find_rpm_interval(rpm)
	var row0 := rows[rpm_index]
	var row1 := rows[rpm_index + 1]

	var rpm_factor := inverse_lerp(
		row0.rpm,
		row1.rpm,
		rpm
	)

	var bsfc0 := _sample_row(row0, load)
	var bsfc1 := _sample_row(row1, load)

	return lerpf(
		bsfc0,
		bsfc1,
		rpm_factor
	)


func _sample_row(
	row: EngineBSFCMapRow,
	load: float
) -> float:
	if load <= 0.10:
		return row.load_10

	if load <= 0.25:
		return lerpf(
			row.load_10,
			row.load_25,
			inverse_lerp(0.10, 0.25, load)
		)

	if load <= 0.50:
		return lerpf(
			row.load_25,
			row.load_50,
			inverse_lerp(0.25, 0.50, load)
		)

	if load <= 0.75:
		return lerpf(
			row.load_50,
			row.load_75,
			inverse_lerp(0.50, 0.75, load)
		)

	return lerpf(
		row.load_75,
		row.load_100,
		inverse_lerp(0.75, 1.0, load)
	)


func _find_rpm_interval(value: float) -> int:
	if value <= rows[0].rpm:
		return 0

	for index in range(rows.size() - 1):
		if value <= rows[index + 1].rpm:
			return index

	return rows.size() - 2
