class_name WeaponCatalog
extends RefCounted
## Tier -> WeaponStats. M1 gates stop at tier 2. Tiers 3-5 are data only.


const _PATHS: PackedStringArray = [
	"",
	"res://data/weapons/pistol.tres",
	"res://data/weapons/rifle.tres",
	"res://data/weapons/shotgun.tres",
	"res://data/weapons/gatling.tres",
	"res://data/weapons/rocket.tres",
]

static var _templates: Array = []


static func tier(level: int) -> WeaponStats:
	return _template(level).duplicate() as WeaponStats


static func _template(level: int) -> WeaponStats:
	var index := clampi(level, 1, 5)
	if _templates.size() < 6:
		_templates.resize(6)
	if _templates[index] == null:
		var loaded: WeaponStats = null
		var path := _PATHS[index]
		if path != "" and ResourceLoader.exists(path):
			loaded = load(path) as WeaponStats
		if loaded == null:
			loaded = _fallback(index)
		_templates[index] = loaded
	return _templates[index]


static func _fallback(level: int) -> WeaponStats:
	match level:
		2:
			return WeaponStats.rifle()
		3:
			return WeaponStats.shotgun()
		4:
			return WeaponStats.gatling()
		5:
			return WeaponStats.rocket()
		_:
			return WeaponStats.pistol()
