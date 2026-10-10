extends GutTest
## Every Android export preset uses the screen flags that present the menu.


func test_android_presets_share_edge_to_edge_and_immersive_off() -> void:
	var text := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_false(text.is_empty(), "export_presets.cfg did not load")
	var presets := _android_presets(text)
	assert_gt(presets.size(), 0, "no Android presets")
	var names: PackedStringArray = []
	for preset in presets:
		var preset_name: String = preset["name"]
		names.append(preset_name)
		assert_eq(preset["immersive_mode"], "false", "%s immersive_mode" % preset_name)
		assert_eq(preset["edge_to_edge"], "true", "%s edge_to_edge" % preset_name)
	assert_true(names.has("Android"), "missing the release preset")
	assert_true(names.has("Android Profile"), "missing the profile preset")


func _android_presets(text: String) -> Array:
	var result: Array = []
	var header_name := ""
	var header_platform := ""
	var immersive := ""
	var edge := ""
	var in_options := false
	var lines := text.split("\n")
	lines.append("[end]")
	for raw in lines:
		var line := str(raw).strip_edges()
		if line.begins_with("[") and line.ends_with("]"):
			if in_options and header_platform == "Android":
				result.append({
					"name": header_name,
					"immersive_mode": immersive,
					"edge_to_edge": edge,
				})
			in_options = line.ends_with(".options]")
			if not in_options:
				header_name = ""
				header_platform = ""
			immersive = ""
			edge = ""
			continue
		if line.begins_with("name=") and not in_options:
			header_name = line.trim_prefix("name=").trim_prefix("\"").trim_suffix("\"")
		elif line.begins_with("platform=") and not in_options:
			header_platform = line.trim_prefix("platform=").trim_prefix("\"").trim_suffix("\"")
		elif in_options and line.begins_with("screen/immersive_mode="):
			immersive = line.trim_prefix("screen/immersive_mode=")
		elif in_options and line.begins_with("screen/edge_to_edge="):
			edge = line.trim_prefix("screen/edge_to_edge=")
	return result
