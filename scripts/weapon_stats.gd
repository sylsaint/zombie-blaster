class_name WeaponStats
extends Resource
## One weapon tier. Numbers live in data/weapons so tuning does not touch code.


@export var weapon_name: String = "手枪"
@export var damage: float = 10.0
@export var interval: float = 0.4
@export var pellets: int = 1
@export var spread_degrees: float = 0.0
@export var bullet_speed: float = 30.0
@export var bullet_range: float = 30.0
## Extra enemies a pellet passes through after the first hit.
@export var pierce: int = 0


static func pistol() -> WeaponStats:
	var weapon := WeaponStats.new()
	weapon.weapon_name = "手枪"
	weapon.damage = 10.0
	weapon.interval = 0.4
	weapon.pellets = 1
	weapon.spread_degrees = 0.0
	weapon.bullet_speed = 30.0
	weapon.bullet_range = 30.0
	weapon.pierce = 0
	return weapon
