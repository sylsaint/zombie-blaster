class_name ExpectedSquad
extends RefCounted
## Configures a squad to a level's expected DPS.
## Each shot is one walker of damage so kill-rate is not eaten by overkill.


const SHOT := 20.0


static func configure(squad: SquadAnchor, dps: float) -> void:
	squad.count = 48
	squad.damage_bonus = 0.0
	squad.rate_bonus = 0.0
	squad.forward_speed = SquadAnchor.FORWARD_SPEED_DEFAULT
	var scale := SquadAnchor.shot_damage(1.0, squad.count, 0.0)
	var weapon := WeaponStats.pistol()
	weapon.damage = SHOT / maxf(scale, 0.0001)
	weapon.interval = SHOT / maxf(dps, 1.0)
	weapon.pellets = 1
	weapon.pierce = 0
	weapon.bullet_speed = 30.0
	weapon.bullet_range = 30.0
	weapon.spread_degrees = 0.0
	squad.weapon = weapon
	squad.set_cooldown(0.0)


static func realized_dps(squad: SquadAnchor) -> float:
	var shot := SquadAnchor.shot_damage(squad.weapon.damage, squad.count, squad.damage_bonus)
	return shot / maxf(squad.current_interval(), 0.0001)


## Drives a mini-boss with the expected DPS. Dodges telegraphs (shots miss)
## and keeps firing otherwise. Stun hits are doubled inside the fight.
static func simulate_boss(fight: BossFight, dps: float, lane_limit: float = 3.0) -> float:
	var interval := SHOT / maxf(dps, 1.0)
	var cooldown := 0.0
	var t := 0.0
	var guard := 0
	while not fight.victorious and guard < 25000:
		guard += 1
		var dt := 0.02
		var squad_x := 0.0
		if fight.telegraph.active:
			squad_x = fight.telegraph.dodge_x(lane_limit)
		fight.tick(dt, squad_x, 0.0, 48, SquadAnchor.formation_radius(48))
		if fight.telegraph.active or not fight.accepts_damage():
			cooldown = interval
		else:
			cooldown -= dt
			var shots := 0
			while cooldown <= 0.0 and shots < 8:
				fight.apply_damage(SHOT)
				cooldown += interval
				shots += 1
		t += dt
		if fight.stage == BossFight.Stage.DEAD:
			break
	return t
