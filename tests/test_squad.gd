extends GutTest

const _EXPECTED := {
	1: 10.0,
	5: 30.851693136000478,
	20: 81.41810630738087,
	100: 251.18864315095794,
}


func test_shot_damage_matches_headcount_curve() -> void:
	for n in [1, 5, 20, 100]:
		var expected: float = _EXPECTED[n]
		var got := SquadAnchor.shot_damage(10.0, n, 0.0)
		assert_almost_eq(got, expected, expected * 0.005, "n=%d" % n)


func test_damage_bonus_multiplies_the_shot() -> void:
	var expected := 30.851693136000478 * 1.2
	var got := SquadAnchor.shot_damage(10.0, 5, 0.2)
	assert_almost_eq(got, expected, expected * 0.005)


func test_rate_bonus_divides_the_interval() -> void:
	assert_almost_eq(SquadAnchor.shot_interval(0.4, 0.0), 0.4, 0.0001)
	assert_almost_eq(SquadAnchor.shot_interval(0.4, 1.0), 0.2, 0.0001)
	assert_almost_eq(SquadAnchor.shot_interval(0.4, 0.15), 0.4 / 1.15, 0.0001)


func test_pistol_resource_is_the_default_tier() -> void:
	var weapon := load("res://data/weapons/pistol.tres") as WeaponStats
	assert_eq(weapon.weapon_name, "手枪")
	assert_almost_eq(weapon.damage, 10.0, 0.001)
	assert_almost_eq(weapon.interval, 0.4, 0.001)
	assert_eq(weapon.pellets, 1)
	assert_almost_eq(weapon.bullet_speed, 30.0, 0.001)
	assert_almost_eq(weapon.bullet_range, 30.0, 0.001)
	assert_eq(weapon.pierce, 0)


func test_pellet_count_does_not_scale_with_headcount() -> void:
	var solo := SquadAnchor.lateral_offsets(1, 1, 0)
	var crowd := SquadAnchor.lateral_offsets(1, 100, 0)
	assert_eq(solo.size(), 1)
	assert_eq(crowd.size(), 1)
	var fan := SquadAnchor.lateral_offsets(5, 100, 0)
	assert_eq(fan.size(), 5)


func test_spread_width_is_formation_diameter_above_20() -> void:
	assert_almost_eq(SquadAnchor.trajectory_width(20), 0.0, 0.0001)
	assert_almost_eq(SquadAnchor.trajectory_width(1), 0.0, 0.0001)
	var radius := SquadAnchor.formation_radius(21)
	var width := SquadAnchor.trajectory_width(21)
	assert_almost_eq(width, radius * 2.0, 0.0001)
	var offsets := SquadAnchor.lateral_offsets(5, 21, 0)
	assert_almost_eq(offsets[0], -width * 0.5, 0.0001)
	assert_almost_eq(offsets[4], width * 0.5, 0.0001)
	var tight := SquadAnchor.lateral_offsets(5, 10, 0)
	for value in tight:
		assert_almost_eq(value, 0.0, 0.0001)


func test_single_pellet_stays_inside_the_spread() -> void:
	var width := SquadAnchor.trajectory_width(40)
	for cursor in 7:
		var offsets := SquadAnchor.lateral_offsets(1, 40, cursor)
		assert_lte(absf(offsets[0]), width * 0.5 + 0.0001)


func test_forward_speed_is_four_and_can_stop() -> void:
	var squad := SquadAnchor.new()
	squad.set_cooldown(10.0)
	squad.forward_speed = 4.0
	squad.tick(1.0)
	assert_almost_eq(squad.position.z, -4.0, 4.0 * 0.02)
	squad.forward_speed = 0.0
	var stopped := squad.position.z
	squad.tick(2.0)
	assert_almost_eq(squad.position.z, stopped, 0.0001)


func test_lateral_speed_is_capped_and_stays_inside_the_lane() -> void:
	var squad := SquadAnchor.new()
	squad.forward_speed = 0.0
	squad.set_cooldown(10.0)
	squad.apply_drag(10000.0, 100.0)
	assert_almost_eq(squad.target_x, 3.0, 0.0001)
	squad.tick(0.1)
	assert_almost_eq(squad.position.x, 1.4, 0.001)
	assert_lte(absf(squad.position.x), 3.0)
	squad.tick(5.0)
	assert_almost_eq(squad.position.x, 3.0, 0.0001)


func test_full_width_drag_reaches_the_other_inset() -> void:
	var squad := SquadAnchor.new()
	squad.forward_speed = 0.0
	squad.set_cooldown(10.0)
	squad.position.x = -3.0
	squad.target_x = -3.0
	squad.apply_drag(1080.0, 1080.0)
	assert_almost_eq(squad.target_x, 3.0, 0.0001)
	squad.tick(6.0 / 14.0)
	assert_almost_eq(squad.position.x, 3.0, 0.02)
	squad.tick(1.0)
	assert_almost_eq(squad.position.x, 3.0, 0.0001)


func test_visible_soldiers_cap_at_40() -> void:
	var squad := SquadAnchor.new()
	squad.count = 100
	squad.forward_speed = 0.0
	squad.set_cooldown(10.0)
	squad.tick(1.0)
	assert_eq(squad.count, 100)
	assert_eq(squad.visible_count(), 40)
	assert_eq(squad.displayed_offsets.size(), 40)
	var radius := SquadAnchor.formation_radius(100)
	assert_almost_eq(radius, 2.4, 0.0001)
	for offset in squad.displayed_offsets:
		assert_lte(Vector2(offset.x, offset.z).length(), radius + 0.001)


func test_formation_radius_formula() -> void:
	assert_almost_eq(SquadAnchor.formation_radius(1), 0.35, 0.0001)
	assert_almost_eq(SquadAnchor.formation_radius(5), 0.35 * sqrt(5.0), 0.0001)
	assert_eq(SquadAnchor.visible_count_for(7), 7)
	assert_eq(SquadAnchor.visible_count_for(40), 40)
	assert_eq(SquadAnchor.visible_count_for(150), 40)


func test_rate_bonus_shortens_the_fire_cooldown() -> void:
	var squad := SquadAnchor.new()
	squad.count = 5
	squad.forward_speed = 0.0
	squad.rate_bonus = 0.0
	squad.set_cooldown(squad.current_interval())
	squad.tick(0.39)
	assert_eq(squad.pending_shots.size(), 0)
	squad.tick(0.02)
	assert_eq(squad.pending_shots.size(), 1)
	var slow: Dictionary = squad.pending_shots[0]
	assert_almost_eq(float(slow["damage"]), SquadAnchor.shot_damage(10.0, 5, 0.0), 0.01)
	assert_eq((slow["offsets"] as PackedFloat32Array).size(), 1)
	squad.consume_shots()
	squad.rate_bonus = 1.0
	squad.set_cooldown(squad.current_interval())
	assert_almost_eq(squad.current_interval(), 0.2, 0.0001)
	squad.tick(0.19)
	assert_eq(squad.pending_shots.size(), 0)
	squad.tick(0.02)
	assert_eq(squad.pending_shots.size(), 1)
