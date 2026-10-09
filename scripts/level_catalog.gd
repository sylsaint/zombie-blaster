class_name LevelCatalog
extends RefCounted

const PATHS: PackedStringArray = [
	"res://data/levels/level_01.tres",
	"res://data/levels/level_02.tres",
	"res://data/levels/level_03.tres",
]


static func path_for(level_index: int) -> String:
	return PATHS[clampi(level_index, 1, PATHS.size()) - 1]


static func load_index(level_index: int) -> LevelData:
	return load(path_for(level_index)) as LevelData


static func load_all() -> Array[LevelData]:
	var out: Array[LevelData] = []
	for path in PATHS:
		var level := load(path) as LevelData
		if level != null:
			out.append(level)
	return out
