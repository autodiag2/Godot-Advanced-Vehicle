@tool
extends EditorPlugin

var inspector_plugin: EngineBSFCMapInspectorPlugin


func _enter_tree() -> void:
	inspector_plugin = EngineBSFCMapInspectorPlugin.new()
	add_inspector_plugin(inspector_plugin)


func _exit_tree() -> void:
	if inspector_plugin != null:
		remove_inspector_plugin(inspector_plugin)
		inspector_plugin = null


class EngineBSFCMapInspectorPlugin extends EditorInspectorPlugin:
	func _can_handle(object: Object) -> bool:
		return object is EngineBSFCMap

	func _parse_begin(object: Object) -> void:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0.0, 600.0)
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var editor := EngineBSFCMapEditor.new()
		editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		editor.setup(object)

		scroll.add_child(editor)
		add_custom_control(scroll)


class EngineBSFCMapEditor extends VBoxContainer:
	var map: EngineBSFCMap
	var grid: GridContainer
	var heatmap: BSFCHeatmap
	var rpm_inputs: Array[SpinBox] = []
	var value_inputs: Array[SpinBox] = []
	var undo_redo: EditorUndoRedoManager

	const LOADS := [0.10, 0.25, 0.50, 0.75, 1.00]
	const LOAD_NAMES := ["10%", "25%", "50%", "75%", "100%"]

	func setup(map_arg: EngineBSFCMap) -> void:
		map = map_arg
		undo_redo = EditorInterface.get_editor_undo_redo()
		_build()

	func _build() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var title := Label.new()
		title.text = "Engine BSFC Map"
		title.add_theme_font_size_override("font_size", 30)
		add_child(title)

		var subtitle := Label.new()
		subtitle.text = "Brake specific fuel consumption (g/kWh)"
		subtitle.modulate = Color(0.7, 0.7, 0.7)
		subtitle.add_theme_font_size_override("font_size", 20)
		add_child(subtitle)

		var toolbar := HBoxContainer.new()
		add_child(toolbar)

		var add_button := Button.new()
		add_button.text = "Add RPM row"
		add_button.pressed.connect(_add_row)
		toolbar.add_child(add_button)

		var sort_button := Button.new()
		sort_button.text = "Sort by RPM"
		sort_button.pressed.connect(_sort_rows)
		toolbar.add_child(sort_button)

		var reset_button := Button.new()
		reset_button.text = "Refresh"
		reset_button.pressed.connect(_refresh)
		toolbar.add_child(reset_button)

		grid = GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		add_child(grid)

		_build_grid()

		var heatmap_title := Label.new()
		heatmap_title.text = "BSFC heatmap"
		heatmap_title.add_theme_font_size_override("font_size", 30)
		add_child(heatmap_title)

		heatmap = BSFCHeatmap.new()
		heatmap.custom_minimum_size = Vector2(650.0, 320.0)
		heatmap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heatmap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(heatmap)
		heatmap.map = map
		heatmap._update_minimum_height()
		heatmap.queue_redraw()

	func _refresh() -> void:
		for child in get_children():
			child.queue_free()

		call_deferred("_build")

	func _build_grid() -> void:
		rpm_inputs.clear()
		value_inputs.clear()

		for child in grid.get_children():
			child.queue_free()

		_add_header("RPM")
		for name in LOAD_NAMES:
			_add_header(name)

		_add_header("")

		for row_index in map.rows.size():
			var row: EngineBSFCMapRow = map.rows[row_index]

			var rpm := _make_spinbox(
				row.rpm,
				0.0,
				20000.0,
				100.0,
				0
			)
			rpm_inputs.append(rpm)
			rpm.value_changed.connect(
				func(value: float, index := row_index) -> void:
					_set_row_value(index, "rpm", value)
			)
			grid.add_child(rpm)

			var properties := [
				"load_10",
				"load_25",
				"load_50",
				"load_75",
				"load_100"
			]

			for property_name in properties:
				var input := _make_spinbox(
					row.get(property_name),
					100.0,
					1000.0,
					1.0,
					0
				)
				value_inputs.append(input)
				input.value_changed.connect(
					func(value: float, index := row_index, property : String = property_name) -> void:
						_set_row_value(index, property, value)
				)
				grid.add_child(input)

			var remove_button := Button.new()
			remove_button.text = "×"
			remove_button.tooltip_text = "Remove row"
			remove_button.pressed.connect(
				func(index := row_index) -> void:
					_remove_row(index)
			)
			grid.add_child(remove_button)

	func _add_header(text: String) -> void:
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size.x = 78.0
		grid.add_child(label)

	func _make_spinbox(
		value: float,
		minimum: float,
		maximum: float,
		step: float,
		decimals: int
	) -> SpinBox:
		var spin := SpinBox.new()
		spin.min_value = minimum
		spin.max_value = maximum
		spin.step = step
		spin.allow_greater = false
		spin.allow_lesser = false
		spin.custom_minimum_size.x = 78.0
		spin.get_line_edit().add_theme_font_size_override("font_size", 30)
		spin.value = value
		return spin

	func _set_row_value(
		row_index: int,
		property_name: String,
		value: float
	) -> void:
		if row_index < 0 || row_index >= map.rows.size():
			return

		var row: EngineBSFCMapRow = map.rows[row_index]
		var old_value: float = row.get(property_name)

		if is_equal_approx(old_value, value):
			return

		undo_redo.create_action(
			"Change BSFC map %s" % property_name
		)
		undo_redo.add_do_property(row, property_name, value)
		undo_redo.add_undo_property(row, property_name, old_value)
		undo_redo.add_do_method(row, "emit_changed")
		undo_redo.add_undo_method(row, "emit_changed")
		undo_redo.add_do_method(map, "emit_changed")
		undo_redo.add_undo_method(map, "emit_changed")
		undo_redo.commit_action()

		heatmap.queue_redraw()

	func _add_row() -> void:
		var row := EngineBSFCMapRow.new()

		if map.rows.size() > 0:
			row.rpm = map.rows[-1].rpm + 1000.0

		var new_rows := map.rows.duplicate()
		new_rows.append(row)

		undo_redo.create_action("Add BSFC map row")
		undo_redo.add_do_property(map, "rows", new_rows)
		undo_redo.add_undo_property(map, "rows", map.rows)
		undo_redo.add_do_method(map, "emit_changed")
		undo_redo.add_undo_method(map, "emit_changed")
		undo_redo.commit_action()

		call_deferred("_rebuild_after_change")

	func _remove_row(index: int) -> void:
		if index < 0 || index >= map.rows.size():
			return

		if map.rows.size() <= 2:
			return

		var new_rows := map.rows.duplicate()
		new_rows.remove_at(index)

		undo_redo.create_action("Remove BSFC map row")
		undo_redo.add_do_property(map, "rows", new_rows)
		undo_redo.add_undo_property(map, "rows", map.rows)
		undo_redo.add_do_method(map, "emit_changed")
		undo_redo.add_undo_method(map, "emit_changed")
		undo_redo.commit_action()

		call_deferred("_rebuild_after_change")

	func _sort_rows() -> void:
		var new_rows := map.rows.duplicate()
		new_rows.sort_custom(
			func(a: EngineBSFCMapRow, b: EngineBSFCMapRow) -> bool:
				return a.rpm < b.rpm
		)

		undo_redo.create_action("Sort BSFC map rows")
		undo_redo.add_do_property(map, "rows", new_rows)
		undo_redo.add_undo_property(map, "rows", map.rows)
		undo_redo.add_do_method(map, "emit_changed")
		undo_redo.add_undo_method(map, "emit_changed")
		undo_redo.commit_action()

		call_deferred("_rebuild_after_change")

	func _rebuild_after_change() -> void:
		for child in get_children():
			child.queue_free()
		_build()


class BSFCHeatmap extends Control:
	var map: EngineBSFCMap

	const LEFT_MARGIN := 90.0
	const RIGHT_MARGIN := 12.0
	const TOP_MARGIN := 70.0
	const BOTTOM_MARGIN := 34.0
	const HEADER_GAP := 10.0
	const font_size := 30.0
	const CELL_HEIGHT := 55.0

	func _ready() -> void:
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


	func _update_minimum_height() -> void:
		if map == null:
			return

		custom_minimum_size.y = (
			TOP_MARGIN +
			map.rows.size() * CELL_HEIGHT +
			BOTTOM_MARGIN
		)

	func _draw() -> void:
		if map == null || map.rows.size() < 2:
			return

		var plot := Rect2(
			LEFT_MARGIN,
			TOP_MARGIN,
			size.x - LEFT_MARGIN - RIGHT_MARGIN,
			map.rows.size() * CELL_HEIGHT
		)

		var columns := 5
		var rows := map.rows.size()
		var cell_width := plot.size.x / columns
		var cell_height := CELL_HEIGHT

		var minimum := INF
		var maximum := -INF

		for row in map.rows:
			for property_name in [
				"load_10",
				"load_25",
				"load_50",
				"load_75",
				"load_100"
			]:
				var value: float = row.get(property_name)
				minimum = minf(minimum, value)
				maximum = maxf(maximum, value)

		var range_value := maxf(maximum - minimum, 0.001)

		for row_index in rows:
			var row: EngineBSFCMapRow = map.rows[row_index]
			var values := [
				row.load_10,
				row.load_25,
				row.load_50,
				row.load_75,
				row.load_100
			]

			var y := plot.position.y + row_index * cell_height

			for column in columns:
				var normalized := clampf(
					(values[column] - minimum) / range_value,
					0.0,
					1.0
				)

				var cell_color := Color.from_hsv(
					0.65 - normalized * 0.65,
					0.75,
					0.95
				)

				var rect := Rect2(
					plot.position.x + column * cell_width,
					y,
					cell_width,
					cell_height
				)

				draw_rect(rect, cell_color)
				draw_rect(
					rect,
					Color(0.15, 0.15, 0.15),
					false,
					1.0
				)

				var value_text := "%d" % values[column]
				var text_size := ThemeDB.fallback_font.get_string_size(
					value_text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1.0,
					font_size
				)

				draw_string(
					ThemeDB.fallback_font,
					Vector2(
						rect.position.x + (rect.size.x - text_size.x) * 0.5,
						rect.position.y + (rect.size.y + text_size.y) * 0.5
					),
					value_text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1.0,
					font_size,
					Color.WHITE
				)

			var rpm_text := "%d" % row.rpm
			var rpm_text_size := ThemeDB.fallback_font.get_string_size(
				rpm_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size
			)

			draw_string(
				ThemeDB.fallback_font,
				Vector2(
					LEFT_MARGIN - HEADER_GAP - rpm_text_size.x,
					y + (cell_height + rpm_text_size.y) * 0.5
				),
				rpm_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size,
				Color.WHITE
			)

		# Load column headers
		for column in columns:
			var x := plot.position.x + column * cell_width
			var header : String = EngineBSFCMapEditor.LOAD_NAMES[column]
			var header_size := ThemeDB.fallback_font.get_string_size(
				header,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size
			)

			draw_string(
				ThemeDB.fallback_font,
				Vector2(
					x + (cell_width - header_size.x) * 0.5,
					TOP_MARGIN - HEADER_GAP
				),
				header,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size,
				Color.WHITE
			)

		# Load axis label
		draw_string(
			ThemeDB.fallback_font,
			Vector2(
				plot.position.x,
				font_size
			),
			"Load",
			HORIZONTAL_ALIGNMENT_CENTER,
			plot.size.x,
			font_size,
			Color.WHITE
		)

		# RPM axis label
		draw_string(
			ThemeDB.fallback_font,
			Vector2(
				0.0,
				plot.position.y - HEADER_GAP
			),
			"RPM",
			HORIZONTAL_ALIGNMENT_RIGHT,
			LEFT_MARGIN - HEADER_GAP,
			font_size,
			Color.WHITE
		)
