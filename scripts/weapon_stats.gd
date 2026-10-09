class_name WeaponStats
extends Resource
## One weapon tier. Numbers live in data/weapons so tuning does not touch code.


@export var weapon_name: String = "手枪"
@export var tier: int = 1
@export var outfit_tier: int = 1
@export var damage: float = 10.0
@export var interval: float = 0.4
@export var pellets: int = 1
@export var spread_degrees: float = 0.0
@export var bullet_speed: float = 30.0
@export var bullet_range: float = 30.0
## Extra enemies a pellet passes through after the first hit.
@export var pierce: int = 0
## Rocket tiers only. M1 combat does not apply it.
@export var explosion_radius: float = 0.0
@export var body_mesh_path: String = "res://assets/models/chr_soldier_a.glb"
@export var weapon_mesh_path: String = "res://assets/models/wpn_pistol.glb"
## Soldier-local muzzle, metres. x is the gun axis (+0.33). y is height above
## the feet. z is forward from the glb bounds (minimum Z; the mesh faces -Z).
@export var muzzle_offset: Vector3 = Vector3(0.33, 0.56, -0.728)


static func solo_dps(weapon: WeaponStats) -> float:
	if weapon == null or weapon.interval <= 0.0001:
		return 0.0
	return weapon.damage * float(maxi(weapon.pellets, 1)) / weapon.interval


static func pistol() -> WeaponStats:
	return _armed(1, 1, "手枪", 10.0, 0.4, 1, 0.0, 0.0, "res://assets/models/chr_soldier_a.glb", "res://assets/models/wpn_pistol.glb", Vector3(0.33, 0.56, -0.728))


static func rifle() -> WeaponStats:
	return _armed(2, 2, "步枪", 12.0, 0.2, 1, 0.0, 0.0, "res://assets/models/chr_soldier_b.glb", "res://assets/models/wpn_rifle.glb", Vector3(0.33, 0.57, -1.157))


static func shotgun() -> WeaponStats:
	return _armed(3, 2, "霰弹枪", 9.0, 0.55, 5, 30.0, 0.0, "res://assets/models/chr_soldier_b.glb", "res://assets/models/wpn_shotgun.glb", Vector3(0.33, 0.59, -1.240))


static func gatling() -> WeaponStats:
	return _armed(4, 3, "加特林", 10.0, 0.08, 1, 6.0, 0.0, "res://assets/models/chr_soldier_c.glb", "res://assets/models/wpn_gatling.glb", Vector3(0.33, 0.57, -1.288))


static func rocket() -> WeaponStats:
	return _armed(5, 3, "火箭炮", 60.0, 0.7, 1, 0.0, 2.0, "res://assets/models/chr_soldier_c.glb", "res://assets/models/wpn_rocket.glb", Vector3(0.33, 0.59, -1.086))


static func _armed(tier_n: int, outfit: int, title: String, dmg: float, gap: float, pellet_count: int, spread: float, blast: float, body_path: String, gun_path: String, muzzle: Vector3) -> WeaponStats:
	var weapon := _make(tier_n, outfit, title, dmg, gap, pellet_count, spread, blast, body_path, gun_path)
	weapon.muzzle_offset = muzzle
	return weapon


static func _make(tier_n: int, outfit: int, title: String, dmg: float, gap: float, pellet_count: int, spread: float, blast: float, body_path: String, gun_path: String) -> WeaponStats:
	var weapon := WeaponStats.new()
	weapon.tier = tier_n
	weapon.outfit_tier = outfit
	weapon.weapon_name = title
	weapon.damage = dmg
	weapon.interval = gap
	weapon.pellets = pellet_count
	weapon.spread_degrees = spread
	weapon.explosion_radius = blast
	weapon.bullet_speed = 30.0
	weapon.bullet_range = 30.0
	weapon.pierce = 0
	weapon.body_mesh_path = body_path
	weapon.weapon_mesh_path = gun_path
	return weapon
