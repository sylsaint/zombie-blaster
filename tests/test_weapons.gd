extends GutTest

const _Clock := preload("res://scripts/game_clock.gd")


func test_pistol_and_rifle_solo_dps() -> void:
	var pistol := WeaponCatalog.tier(1)
	var rifle := WeaponCatalog.tier(2)
	assert_eq(pistol.weapon_name, "手枪")
	assert_eq(rifle.weapon_name, "步枪")
	assert_eq(pistol.outfit_tier, 1)
	assert_eq(rifle.outfit_tier, 2)
	assert_almost_eq(WeaponStats.solo_dps(pistol), 25.0, 25.0 * 0.005)
	assert_almost_eq(WeaponStats.solo_dps(rifle), 60.0, 60.0 * 0.005)
	assert_eq(pistol.body_mesh_path, SoldierVisuals.body_path(1))
	assert_eq(rifle.weapon_mesh_path, SoldierVisuals.weapon_path(2))
	assert_eq(pistol.body_mesh_path, "res://assets/models/chr_soldier_a.glb")
	assert_eq(rifle.body_mesh_path, "res://assets/models/chr_soldier_b.glb")
	assert_true(ResourceLoader.exists(SoldierVisuals.body_path(1)))
	assert_true(ResourceLoader.exists(SoldierVisuals.weapon_path(2)))
	assert_almost_eq(pistol.muzzle_offset.x, 0.33, 0.001)
	assert_almost_eq(pistol.muzzle_offset.y, -0.728, 0.001)
	assert_almost_eq(rifle.muzzle_offset.y, -1.157, 0.001)


func test_later_tiers_are_data_only() -> void:
	var shotgun := WeaponCatalog.tier(3)
	var gatling := WeaponCatalog.tier(4)
	var rocket := WeaponCatalog.tier(5)
	assert_eq(shotgun.pellets, 5)
	assert_almost_eq(shotgun.spread_degrees, 30.0, 0.001)
	assert_eq(shotgun.outfit_tier, 2)
	assert_eq(shotgun.body_mesh_path, "res://assets/models/chr_soldier_b.glb")
	assert_almost_eq(shotgun.muzzle_offset.y, -1.240, 0.001)
	assert_eq(gatling.body_mesh_path, "res://assets/models/chr_soldier_c.glb")
	assert_almost_eq(gatling.muzzle_offset.y, -1.288, 0.001)
	assert_almost_eq(rocket.muzzle_offset.y, -1.086, 0.001)
	assert_almost_eq(WeaponStats.solo_dps(shotgun), 82.0, 82.0 * 0.005)
	assert_almost_eq(gatling.interval, 0.08, 0.0001)
	assert_almost_eq(gatling.spread_degrees, 6.0, 0.001)
	assert_eq(gatling.outfit_tier, 3)
	assert_almost_eq(WeaponStats.solo_dps(gatling), 125.0, 125.0 * 0.005)
	assert_almost_eq(rocket.explosion_radius, 2.0, 0.001)
	assert_eq(rocket.outfit_tier, 3)
	assert_almost_eq(WeaponStats.solo_dps(rocket), 86.0, 86.0 * 0.005)
	var squad := SquadAnchor.new()
	GateRules.apply_weapon(squad)
	GateRules.apply_weapon(squad)
	assert_eq(squad.weapon_tier(), GateRules.M1_MAX_WEAPON_TIER)


func test_shot_damage_for_both_m1_tiers() -> void:
	for n in [1, 5, 20, 100]:
		var pistol := SquadAnchor.shot_damage(10.0, n, 0.0)
		var rifle := SquadAnchor.shot_damage(12.0, n, 0.0)
		assert_almost_eq(pistol, 10.0 * pow(float(n), 0.7), pistol * 0.005)
		assert_almost_eq(rifle, 12.0 * pow(float(n), 0.7), rifle * 0.005)
	var boosted := SquadAnchor.shot_damage(12.0, 5, 0.2)
	assert_almost_eq(boosted, 12.0 * pow(5.0, 0.7) * 1.2, boosted * 0.005)


func test_modifier_hooks_stack() -> void:
	var squad := SquadAnchor.new()
	squad.count = 5
	squad.forward_speed = 0.0
	squad.extra_shots = 1
	squad.bonus_pierce = 2
	squad.split_level = 1
	squad.meta_attack_levels = 2
	squad.damage_bonus = 0.2
	squad.set_cooldown(squad.current_interval())
	squad.tick(squad.current_interval())
	assert_eq(squad.pending_shots.size(), 1)
	var shot: Dictionary = squad.pending_shots[0]
	assert_eq((shot["offsets"] as PackedFloat32Array).size(), 2)
	assert_eq(int(shot["pierce"]), 2)
	assert_eq(int(shot["split_count"]), 2)
	assert_eq(WeaponMods.split_child_count(0), 0)
	assert_eq(WeaponMods.split_child_count(2), 3)
	assert_eq(WeaponMods.split_child_count(3), 4)
	assert_almost_eq(WeaponMods.SPLIT_DAMAGE_SCALE, 0.5, 0.001)
	assert_almost_eq(WeaponMods.SPLIT_SPREAD_DEGREES, 30.0, 0.001)
	var expected := SquadAnchor.shot_damage(10.0, 5, 0.2 + 0.16)
	assert_almost_eq(float(shot["damage"]), expected, expected * 0.005)
	assert_almost_eq(WeaponMods.meta_attack_bonus(30), 0.08 * 30.0, 0.0001)
	assert_almost_eq(WeaponMods.meta_attack_bonus(40), 0.08 * 30.0, 0.0001)


func test_greybox_meshes_follow_the_tier_hook() -> void:
	var body_a := SoldierVisuals.body_mesh(1)
	var body_b := SoldierVisuals.body_mesh(2)
	var gun_a := SoldierVisuals.weapon_mesh(1)
	var gun_b := SoldierVisuals.weapon_mesh(2)
	assert_ne(body_a, body_b)
	assert_ne(gun_a, gun_b)
	assert_eq(SoldierVisuals.body_mesh(1), body_a)
	assert_gt(PlaceholderMeshes.triangle_count(body_a), 0)
	assert_gt(PlaceholderMeshes.triangle_count(gun_b), 0)
	var colors: PackedColorArray = body_a.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_eq(colors.size(), body_a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
	var on_screen := 40 * (PlaceholderMeshes.triangle_count(body_b) + PlaceholderMeshes.triangle_count(gun_b))
	on_screen += 300 * PlaceholderMeshes.triangle_count(PlaceholderMeshes.grunt())
	on_screen += 3 * PlaceholderMeshes.triangle_count(PlaceholderMeshes.elite())
	on_screen += PlaceholderMeshes.triangle_count(PlaceholderMeshes.boss())
	assert_lte(on_screen, 150000)


func test_weapon_gate_swaps_body_and_gun_without_a_new_draw() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 8, 4)
	sim.separation_enabled = false
	sim.squad.count = 8
	sim.squad.forward_speed = 0.0
	sim.squad.set_cooldown(10.0)
	sim.squad.position.x = 0.0
	sim.squad.target_x = 0.0
	sim.tick(0.016)
	var view := CrowdView.new()
	add_child_autofree(view)
	view.setup()
	view.sync(sim)
	var draws := view.visible_multimesh_count()
	var nodes := view.get_child_count()
	var body_before: Mesh = view.squad_body_mm.multimesh.mesh
	var gun_before: Mesh = view.squad_weapon_mm.multimesh.mesh
	assert_eq(view.shown_outfit, 1)
	assert_eq(view.shown_weapon, 1)
	assert_null(view.get_node_or_null("OutlineGrunts"))
	assert_false(view.outline_elite.visible)
	view.squad_mesh_rebinds = 0
	var runner := GateRunner.new()
	runner.set_groups([
		_weapon_group(-1.0),
		_weapon_group(-2.0),
	], sim.squad.position.z)
	sim.gates = runner
	sim.squad.forward_speed = 20.0
	sim.tick(1.0)
	view.sync(sim)
	assert_eq(sim.squad.weapon_tier(), 2)
	assert_eq(sim.squad.outfit_tier(), 2)
	assert_almost_eq(sim.squad.damage_bonus, 0.2, 0.0001)
	assert_eq(view.shown_outfit, 2)
	assert_eq(view.shown_weapon, sim.squad.weapon_tier())
	assert_eq(view.squad_body_mm.multimesh.mesh, SoldierVisuals.body_mesh(sim.squad.outfit_tier()))
	assert_eq(view.squad_weapon_mm.multimesh.mesh, SoldierVisuals.weapon_mesh(sim.squad.weapon_tier()))
	assert_ne(view.squad_body_mm.multimesh.mesh, body_before)
	assert_ne(view.squad_weapon_mm.multimesh.mesh, gun_before)
	assert_eq(view.squad_mesh_rebinds, 2)
	assert_eq(view.visible_multimesh_count(), draws)
	assert_eq(view.get_child_count(), nodes)
	assert_eq(view.squad_body_mm.multimesh.visible_instance_count, 8)
	assert_eq(view.squad_weapon_mm.multimesh.visible_instance_count, 8)
	var again := view.squad_mesh_rebinds
	view.sync(sim)
	assert_eq(view.squad_mesh_rebinds, again)


func test_weapon_gate_at_max_tier_does_not_rebind_meshes() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 4, 4)
	sim.separation_enabled = false
	sim.squad.count = 5
	sim.squad.forward_speed = 0.0
	sim.squad.set_cooldown(10.0)
	sim.squad.equip_tier(2)
	sim.tick(0.016)
	var view := CrowdView.new()
	add_child_autofree(view)
	view.setup()
	view.sync(sim)
	assert_eq(view.shown_outfit, 2)
	assert_eq(view.shown_weapon, 2)
	var body: Mesh = view.squad_body_mm.multimesh.mesh
	var gun: Mesh = view.squad_weapon_mm.multimesh.mesh
	var draws := view.visible_multimesh_count()
	view.squad_mesh_rebinds = 0
	var runner := GateRunner.new()
	runner.set_groups([_weapon_group(-1.0), _weapon_group(-2.0)], sim.squad.position.z)
	sim.gates = runner
	sim.squad.forward_speed = 20.0
	sim.tick(1.0)
	view.sync(sim)
	assert_eq(sim.squad.weapon_tier(), 2)
	assert_eq(sim.squad.outfit_tier(), 2)
	assert_almost_eq(sim.squad.damage_bonus, 0.4, 0.0001)
	assert_eq(view.squad_mesh_rebinds, 0)
	assert_eq(view.squad_body_mm.multimesh.mesh, body)
	assert_eq(view.squad_weapon_mm.multimesh.mesh, gun)
	assert_eq(view.visible_multimesh_count(), draws)
	assert_eq(view.squad_body_mm.multimesh.visible_instance_count, mini(sim.squad.count, 40))


func test_visible_soldiers_stay_on_two_meshes() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 4, 4)
	sim.squad.count = 100
	sim.squad.forward_speed = 0.0
	sim.squad.set_cooldown(10.0)
	sim.tick(0.2)
	var view := CrowdView.new()
	add_child_autofree(view)
	view.setup()
	view.sync(sim)
	assert_eq(sim.squad.visible_count(), 40)
	assert_eq(view.squad_body_mm.multimesh.visible_instance_count, 40)
	assert_eq(view.squad_weapon_mm.multimesh.visible_instance_count, 40)
	assert_eq(view.squad_body_mm.multimesh.instance_count, CrowdView.SQUAD_CAP)


func test_toon_toggles_default_off_and_outline_skips_grunts() -> void:
	var view := CrowdView.new()
	add_child_autofree(view)
	view.setup()
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 4, 4)
	sim.squad.count = 4
	sim.squad.forward_speed = 0.0
	sim.squad.set_cooldown(10.0)
	sim.tick(0.016)
	view.sync(sim)
	assert_false(view.outline_squad_body.visible)
	assert_false(view.outline_elite.visible)
	assert_false(view.outline_boss.visible)
	assert_eq(view.shared_material.shader.resource_path, "res://assets/vfx/crowd_instance.gdshader")
	var base := view.visible_multimesh_count()
	view.set_toon_flags(true, false, false)
	var ramp: Texture2D = view.shared_material.get_shader_parameter("cel_ramp")
	assert_true(ramp != null)
	assert_eq(ramp.get_width(), 3)
	assert_eq(view.shared_material.shader.resource_path, "res://assets/vfx/crowd_toon.gdshader")
	assert_eq(view.toon.squad_material.shader.resource_path, "res://assets/vfx/crowd_toon.gdshader")
	view.set_toon_flags(false, true, false)
	assert_eq(view.shared_material.shader.resource_path, "res://assets/vfx/crowd_instance.gdshader")
	assert_almost_eq(float(view.shared_material.get_shader_parameter("rim_enabled")), 1.0, 0.001)
	view.set_toon_flags(false, false, true)
	assert_true(view.outline_squad_body.visible)
	assert_true(view.outline_squad_weapon.visible)
	assert_true(view.outline_elite.visible)
	assert_null(view.get_node_or_null("OutlineGrunts"))
	assert_eq(view.visible_multimesh_count(), base + 2)
	assert_eq(view.outline_squad_body.multimesh, view.squad_body_mm.multimesh)
	view.set_toon_flags(false, false, false)
	assert_false(view.outline_squad_body.visible)
	assert_eq(view.visible_multimesh_count(), base)
	assert_almost_eq(float(view.shared_material.get_shader_parameter("rim_enabled")), 0.0, 0.001)


func _weapon_group(z: float) -> GateGroup:
	var span := GateSpan.new()
	span.kind = GateRules.WEAPON
	span.amount = 1.0
	span.x_min = -3.75
	span.x_max = 3.75
	var group := GateGroup.new()
	group.z = z
	group.spans.append(span)
	return group
