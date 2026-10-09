class_name SoldierVisuals
extends RefCounted
## Tier -> mesh path. Drop a .glb at the path and the next load uses it.
## Until then the greybox placeholder for that tier is cached.


const BODY_PATHS := {
	1: "res://assets/models/chr_soldier_a.glb",
	2: "res://assets/models/chr_soldier_b.glb",
	3: "res://assets/models/chr_soldier_c.glb",
}
const WEAPON_PATHS := {
	1: "res://assets/models/wpn_pistol.glb",
	2: "res://assets/models/wpn_rifle.glb",
	3: "res://assets/models/wpn_shotgun.glb",
	4: "res://assets/models/wpn_gatling.glb",
	5: "res://assets/models/wpn_rocket.glb",
}

static var _bodies: Array = []
static var _weapons: Array = []


static func body_path(tier: int) -> String:
	return String(BODY_PATHS.get(clampi(tier, 1, 3), BODY_PATHS[1]))


static func weapon_path(tier: int) -> String:
	return String(WEAPON_PATHS.get(clampi(tier, 1, 5), WEAPON_PATHS[1]))


static func body_mesh(tier: int) -> Mesh:
	tier = clampi(tier, 1, 3)
	if _bodies.size() <= tier:
		_bodies.resize(tier + 1)
	if _bodies[tier] == null:
		_bodies[tier] = _resolve(body_path(tier), tier, true)
	return _bodies[tier]


static func weapon_mesh(tier: int) -> Mesh:
	tier = clampi(tier, 1, 5)
	if _weapons.size() <= tier:
		_weapons.resize(tier + 1)
	if _weapons[tier] == null:
		_weapons[tier] = _resolve(weapon_path(tier), tier, false)
	return _weapons[tier]


static func _resolve(path: String, tier: int, body: bool) -> Mesh:
	var loaded := _load_mesh(path)
	if loaded is ArrayMesh:
		OutlineNormals.bake_inplace(loaded as ArrayMesh)
		return loaded
	if loaded != null:
		return loaded
	if body:
		return PlaceholderMeshes.soldier_body(tier)
	return PlaceholderMeshes.weapon_mesh(tier)


static func _load_mesh(path: String) -> Mesh:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is Mesh:
		return (res as Mesh).duplicate() as Mesh
	if res is PackedScene:
		var node := (res as PackedScene).instantiate()
		var found := _find_mesh(node)
		var copy: Mesh = null
		if found != null:
			copy = found.duplicate() as Mesh
		node.free()
		return copy
	return null


static func _find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			return mesh
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null
