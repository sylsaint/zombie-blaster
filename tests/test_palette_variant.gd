extends GutTest

const _SHADERS := [
	"res://assets/vfx/crowd_instance.gdshader",
	"res://assets/vfx/crowd_toon.gdshader",
]
const _CELL_PX := 32


func test_variant_sample_is_a_cell_center_on_an_8_row_palette() -> void:
	var palette := load("res://assets/textures/palette.png") as Texture2D
	assert_not_null(palette)
	assert_eq(palette.get_width(), 256)
	assert_eq(palette.get_height(), 256)
	var rows := palette.get_height() / _CELL_PX
	assert_eq(rows, 8, "square 32px cells on a 256px sheet")
	var seen_v := -1.0
	for path in _SHADERS:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("vec2(variant, 0.5)"), path)
		assert_true(src.contains("(PALETTE_VARIANT_ROW + 0.5) / PALETTE_ROWS"), path)
		var shader_rows := _const_float(src, "PALETTE_ROWS")
		var row := _const_float(src, "PALETTE_VARIANT_ROW")
		assert_almost_eq(shader_rows, float(rows), 0.001, path)
		assert_almost_eq(row, 2.0, 0.001, "%s keeps the old nearest row" % path)
		var v := (row + 0.5) / shader_rows
		_assert_cell_center(v, shader_rows, path)
		if seen_v < 0.0:
			seen_v = v
		else:
			assert_almost_eq(v, seen_v, 0.00001, path)


func _assert_cell_center(v: float, rows: float, path: String) -> void:
	var cell := 1.0 / rows
	assert_almost_eq(fposmod(v, cell), cell * 0.5, 0.00001, path)
	var index := v * rows - 0.5
	assert_almost_eq(index, roundf(index), 0.00001, path)
	assert_gte(index, 0.0, path)
	assert_lt(index, rows, path)


func _const_float(src: String, name: String) -> float:
	var token := "const float %s = " % name
	var at := src.find(token)
	assert_ne(at, -1, name)
	var tail := src.substr(at + token.length())
	var end := tail.find(";")
	assert_gt(end, 0, name)
	return float(tail.substr(0, end).strip_edges())
