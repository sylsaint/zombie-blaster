class_name CrowdView
extends Node3D
## One MultiMesh per body mesh, plus blobs, bullets, and the squad.
## Instance count changes do not add nodes or materials.


const GRUNT_CAP := 320
const ELITE_CAP := 8
const BOSS_CAP := 2
const BULLET_CAP := 64
const SQUAD_CAP := 40
const BLOB_CAP := 380

var shared_material: ShaderMaterial
var toon := ToonLook.new()
var grunt_mm: MultiMeshInstance3D
var walker_lod_mm: MultiMeshInstance3D
var runner_mm: MultiMeshInstance3D
var runner_lod_mm: MultiMeshInstance3D
var elite_mm: MultiMeshInstance3D
var boss_mm: MultiMeshInstance3D
var blob_mm: MultiMeshInstance3D
var bullet_mm: MultiMeshInstance3D
var squad_mm: MultiMeshInstance3D
var squad_body_mm: MultiMeshInstance3D
var squad_weapon_mm: MultiMeshInstance3D
var outline_squad_body: MultiMeshInstance3D
var outline_squad_weapon: MultiMeshInstance3D
var outline_elite: MultiMeshInstance3D
var outline_boss: MultiMeshInstance3D
var outline_walker: MultiMeshInstance3D
var outline_walker_lod: MultiMeshInstance3D
var warning_mm: MultiMeshInstance3D
var gem_mm: MultiMeshInstance3D
var bar_mm: MultiMeshInstance3D
var casualty_mm: MultiMeshInstance3D

var _grunt_mesh: Mesh
var _elite_mesh: Mesh
var _boss_mesh: Mesh
var _soldier_mesh: Mesh
var profile: SimProfile
var squad_mesh_rebinds: int = 0
var shown_outfit: int = 1
var shown_weapon: int = 1
var _lod := CrowdLod.new(4096)
var _buf_grunt := PackedFloat32Array()
var _buf_walker_lod := PackedFloat32Array()
var _buf_runner := PackedFloat32Array()
var _buf_runner_lod := PackedFloat32Array()
var _buf_elite := PackedFloat32Array()
var _buf_boss := PackedFloat32Array()
var _buf_blob := PackedFloat32Array()
var _buf_bullet := PackedFloat32Array()
var _buf_squad := PackedFloat32Array()
var _buf_weapon := PackedFloat32Array()
var _buf_warning := PackedFloat32Array()
var _buf_gem := PackedFloat32Array()
var _buf_bar := PackedFloat32Array()
var _buf_casualty := PackedFloat32Array()
var walker_high_fallback: bool = true
var walker_low_fallback: bool = true
var walker_vat_high: VatClipset
var walker_vat_low: VatClipset
var walker_high_material: ShaderMaterial
var walker_low_material: ShaderMaterial
var runner_high_fallback: bool = true
var runner_low_fallback: bool = true
var boss_fallback: bool = true


func setup() -> void:
	if shared_material != null:
		return
	var walker_arch := EnemyCatalog.walker()
	var runner_arch := EnemyCatalog.runner()
	var elite_arch := EnemyCatalog.elite()
	var boss_arch := EnemyCatalog.boss()
	var grunt_fb := PlaceholderMeshes.grunt()
	var walker_lod_fb := PlaceholderMeshes.walker_lod()
	var runner_fb := PlaceholderMeshes.runner()
	var runner_lod_fb := PlaceholderMeshes.runner_lod()
	var elite_fb := PlaceholderMeshes.elite()
	var boss_fb := PlaceholderMeshes.boss()
	_grunt_mesh = ModelResolver.resolve(walker_arch.mesh_high, grunt_fb)
	var walker_lod_mesh: Mesh = ModelResolver.resolve(walker_arch.mesh_low, walker_lod_fb)
	var runner_mesh: Mesh = ModelResolver.resolve(runner_arch.mesh_high, runner_fb)
	var runner_lod_mesh: Mesh = ModelResolver.resolve(runner_arch.mesh_low, runner_lod_fb)
	_elite_mesh = ModelResolver.resolve(elite_arch.mesh_high, elite_fb)
	# Body only. BossView owns the glb, the weakpoint node, and its glow.
	_boss_mesh = ModelResolver.resolve(boss_arch.mesh_high, boss_fb)
	walker_high_fallback = _grunt_mesh == grunt_fb
	walker_low_fallback = walker_lod_mesh == walker_lod_fb
	if not walker_high_fallback:
		walker_vat_high = VatClipset.for_model(walker_arch.mesh_high)
	if not walker_low_fallback:
		walker_vat_low = VatClipset.for_model(walker_arch.mesh_low)
	_apply_vat_aabb(_grunt_mesh, walker_vat_high)
	_apply_vat_aabb(walker_lod_mesh, walker_vat_low)
	runner_high_fallback = runner_mesh == runner_fb
	runner_low_fallback = runner_lod_mesh == runner_lod_fb
	boss_fallback = _boss_mesh == boss_fb
	_soldier_mesh = PlaceholderMeshes.soldier()
	var soldier_real := ResourceLoader.exists(SoldierVisuals.body_path(1))
	toon.setup()
	shared_material = toon.crowd_material
	var enemy_uv := not walker_high_fallback
	_configure_palette(shared_material, enemy_uv)
	walker_high_material = _vat_material(shared_material, walker_vat_high)
	walker_low_material = _vat_material(shared_material, walker_vat_low)
	if walker_high_material != null:
		toon.track_material(walker_high_material)
	if walker_low_material != null:
		toon.track_material(walker_low_material)
	var squad_mat: Material = toon.squad_material
	if soldier_real and enemy_uv:
		# Squad, runners, elites, and the boss share one palette material.
		# Each walker LOD has its own VAT texture, so those two cannot.
		squad_mat = shared_material
	elif soldier_real:
		_configure_palette(toon.squad_material, true)
		toon.squad_material.set_shader_parameter("use_uniform_color", 0.0)
		toon.squad_material.set_shader_parameter("wobble_enabled", 0.0)
		squad_mat = toon.squad_material
	else:
		toon.squad_material.set_shader_parameter("palette", shared_material.get_shader_parameter("palette"))
	var bullet_mat := StandardMaterial3D.new()
	bullet_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bullet_mat.albedo_color = Color(1.0, 0.86, 0.25)
	bullet_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var blob_mat := ShaderMaterial.new()
	blob_mat.shader = load("res://assets/vfx/blob_shadow_clip.gdshader")

	var warning_mat := StandardMaterial3D.new()
	warning_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warning_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning_mat.albedo_color = Color(0.9, 0.16, 0.12, 0.45)
	warning_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gem_mat := StandardMaterial3D.new()
	gem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gem_mat.albedo_color = Color(0.95, 0.82, 0.28)
	var bar_mat := StandardMaterial3D.new()
	bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_mat.albedo_color = Color(0.78, 0.16, 0.14)

	var grunt_mat: Material = walker_high_material if walker_high_material != null else shared_material
	var walker_lod_mat: Material = walker_low_material if walker_low_material != null else shared_material
	grunt_mm = _add_body("Grunts", _grunt_mesh, GRUNT_CAP, grunt_mat)
	walker_lod_mm = _add_body("WalkerLod", walker_lod_mesh, GRUNT_CAP, walker_lod_mat)
	runner_mm = _add_body("Runners", runner_mesh, GRUNT_CAP, shared_material)
	runner_lod_mm = _add_body("RunnerLod", runner_lod_mesh, GRUNT_CAP, shared_material)
	elite_mm = _add_body("Elites", _elite_mesh, ELITE_CAP, shared_material)
	boss_mm = _add_body("Boss", _boss_mesh, BOSS_CAP, shared_material)
	blob_mm = _add_plain("Blobs", PlaceholderMeshes.blob(), BLOB_CAP, blob_mat, false)
	bullet_mm = _add_plain("Bullets", PlaceholderMeshes.bullet(), BULLET_CAP, bullet_mat, false)
	squad_body_mm = _add_plain("SquadBodies", SoldierVisuals.body_mesh(1), SQUAD_CAP, squad_mat, false)
	squad_weapon_mm = _add_plain("SquadWeapons", SoldierVisuals.weapon_mesh(1), SQUAD_CAP, squad_mat, false)
	squad_mm = squad_body_mm
	outline_squad_body = _add_outline("OutlineSquadBodies", squad_body_mm)
	outline_squad_weapon = _add_outline("OutlineSquadWeapons", squad_weapon_mm)
	outline_elite = _add_outline("OutlineElites", elite_mm)
	outline_boss = _add_outline("OutlineBoss", boss_mm)
	outline_walker = _add_vat_outline("OutlineWalkers", grunt_mm, walker_vat_high)
	outline_walker_lod = _add_vat_outline("OutlineWalkerLod", walker_lod_mm, walker_vat_low)
	toon.bind_outlines([
		outline_squad_body, outline_squad_weapon, outline_elite, outline_boss,
		outline_walker, outline_walker_lod,
	])
	shown_outfit = 1
	shown_weapon = 1
	squad_mesh_rebinds = 0
	warning_mm = _add_plain("Warnings", PlaceholderMeshes.ground_quad(), GroundWarning.CAP, warning_mat, false)
	gem_mm = _add_plain("XpGems", PlaceholderMeshes.gem(), XpDropPool.CAPACITY, gem_mat, false)
	bar_mm = _add_plain("EliteBars", PlaceholderMeshes.ground_quad(), ELITE_CAP, bar_mat, false)
	var casualty_mesh: Mesh = SoldierVisuals.body_mesh(1) if soldier_real else _soldier_mesh
	var casualty_mat: Material = squad_mat if soldier_real else shared_material
	casualty_mm = _add_body("Casualties", casualty_mesh, CasualtyPool.CAP, casualty_mat)
	_buf_grunt = _make_buffer(grunt_mm)
	_buf_walker_lod = _make_buffer(walker_lod_mm)
	_buf_runner = _make_buffer(runner_mm)
	_buf_runner_lod = _make_buffer(runner_lod_mm)
	_buf_elite = _make_buffer(elite_mm)
	_buf_boss = _make_buffer(boss_mm)
	_buf_blob = _make_buffer(blob_mm)
	_buf_bullet = _make_buffer(bullet_mm)
	_buf_squad = _make_buffer(squad_body_mm)
	_buf_weapon = _make_buffer(squad_weapon_mm)
	_buf_warning = _make_buffer(warning_mm)
	_buf_gem = _make_buffer(gem_mm)
	_buf_bar = _make_buffer(bar_mm)
	_buf_casualty = _make_buffer(casualty_mm)


func logical_batch_count() -> int:
	var n := 0
	for child in get_children():
		if child is MultiMeshInstance3D:
			n += 1
	return n


func set_toon_flags(cel: bool, rim: bool, outline: bool) -> void:
	toon.cel_enabled = cel
	toon.rim_enabled = rim
	toon.outline_enabled = outline
	toon.apply()


func visible_multimesh_count() -> int:
	var n := 0
	for child in get_children():
		if child is MultiMeshInstance3D and (child as MultiMeshInstance3D).visible:
			var mm := (child as MultiMeshInstance3D).multimesh
			if mm != null and mm.visible_instance_count > 0:
				n += 1
	return n


func visible_body_instances() -> int:
	var n := 0
	for node in [grunt_mm, walker_lod_mm, runner_mm, runner_lod_mm, elite_mm, boss_mm]:
		if node and node.multimesh:
			n += node.multimesh.visible_instance_count
	return n


func body_triangles() -> int:
	var total := 0
	for node in [grunt_mm, walker_lod_mm, runner_mm, runner_lod_mm, elite_mm, boss_mm, squad_body_mm, squad_weapon_mm]:
		if node == null or node.multimesh == null or node.multimesh.mesh == null:
			continue
		total += node.multimesh.visible_instance_count * PlaceholderMeshes.triangle_count(node.multimesh.mesh)
	return total


func clear_draws() -> void:
	for node in [grunt_mm, walker_lod_mm, runner_mm, runner_lod_mm, elite_mm, boss_mm, blob_mm, bullet_mm, squad_body_mm, squad_weapon_mm, warning_mm, gem_mm, bar_mm, casualty_mm]:
		if node != null and node.multimesh != null:
			node.multimesh.visible_instance_count = 0


## Menu stand-in. Same body and pistol MultiMeshes the fight uses.
func show_idle_squad(points: PackedVector3Array) -> void:
	var n := mini(points.size(), SQUAD_CAP)
	var i := 0
	while i < n:
		var o := i * 12
		var px := points[i].x
		var pz := points[i].z
		_write_origin(_buf_squad, o, px, pz)
		_write_origin(_buf_weapon, o, px, pz)
		var blob := i * 12
		_buf_blob[blob + 0] = 0.7
		_buf_blob[blob + 1] = 0.0
		_buf_blob[blob + 2] = 0.0
		_buf_blob[blob + 3] = px
		_buf_blob[blob + 4] = 0.0
		_buf_blob[blob + 5] = 1.0
		_buf_blob[blob + 6] = 0.0
		_buf_blob[blob + 7] = 0.04
		_buf_blob[blob + 8] = 0.0
		_buf_blob[blob + 9] = 0.0
		_buf_blob[blob + 10] = 0.7
		_buf_blob[blob + 11] = pz
		i += 1
	_commit(squad_body_mm, _buf_squad, n)
	_commit(squad_weapon_mm, _buf_weapon, n)
	_commit(blob_mm, _buf_blob, n)


func sync(sim: CombatSim) -> void:
	var t0 := Time.get_ticks_usec()
	var tw := Time.get_ticks_usec()
	var crowd := _write_crowds(sim)
	var n_elite := _write_kind(_buf_elite, 16, sim, EnemyPool.Archetype.ELITE, ELITE_CAP, true)
	var n_boss := _write_kind(_buf_boss, 16, sim, EnemyPool.Archetype.BOSS, BOSS_CAP, true)
	var n_blob := _write_blobs(sim)
	var n_bullet := _write_bullets(sim)
	_apply_squad_tier(sim.squad)
	var n_squad := _write_squad(sim)
	var n_warning := _write_warnings(sim)
	var n_gem := _write_gems(sim)
	var n_bar := _write_bars(sim)
	var n_casualty := _write_casualties(sim)
	var t_upload := Time.get_ticks_usec()
	_commit(grunt_mm, _buf_grunt, int(crowd.x))
	_commit(walker_lod_mm, _buf_walker_lod, int(crowd.y))
	_commit(runner_mm, _buf_runner, int(crowd.z))
	_commit(runner_lod_mm, _buf_runner_lod, int(crowd.w))
	_commit(elite_mm, _buf_elite, n_elite)
	_commit(boss_mm, _buf_boss, n_boss)
	_commit(blob_mm, _buf_blob, n_blob)
	_commit(bullet_mm, _buf_bullet, n_bullet)
	_commit(squad_body_mm, _buf_squad, n_squad)
	_commit(squad_weapon_mm, _buf_weapon, n_squad)
	_commit(warning_mm, _buf_warning, n_warning)
	_commit(gem_mm, _buf_gem, n_gem)
	_commit(bar_mm, _buf_bar, n_bar)
	_commit(casualty_mm, _buf_casualty, n_casualty)
	if profile != null:
		profile.view_write_us += int(t_upload - tw)
		profile.view_upload_us += int(Time.get_ticks_usec() - t_upload)
		profile.view_us += int(Time.get_ticks_usec() - t0)


func _write_crowds(sim: CombatSim) -> Vector4:
	var pool := sim.enemies
	_lod.classify(pool.active_ids, pool.active_n, pool.species, pool.state, pool.x, pool.z, sim.squad.position.x, sim.squad.position.z)
	var n_wh := 0
	var n_wl := 0
	var n_rh := 0
	var n_rl := 0
	var a := 0
	while a < pool.active_n:
		var i := pool.active_ids[a]
		a += 1
		if pool.state[i] == EnemyPool.State.FREE:
			continue
		var high := _lod.is_high(i)
		if pool.species[i] == EnemyPool.Species.WALKER:
			if high:
				if n_wh < GRUNT_CAP:
					_put_body(_buf_grunt, n_wh, pool, i, walker_vat_high)
					n_wh += 1
			elif n_wl < GRUNT_CAP:
				_put_body(_buf_walker_lod, n_wl, pool, i, walker_vat_low)
				n_wl += 1
		elif pool.species[i] == EnemyPool.Species.RUNNER:
			if high:
				if n_rh < GRUNT_CAP:
					_put_body(_buf_runner, n_rh, pool, i, null)
					n_rh += 1
			elif n_rl < GRUNT_CAP:
				_put_body(_buf_runner_lod, n_rl, pool, i, null)
				n_rl += 1
	return Vector4(n_wh, n_wl, n_rh, n_rl)


func set_vat_enabled(enabled: bool) -> void:
	var flag := 1.0 if enabled else 0.0
	for mat in [walker_high_material, walker_low_material]:
		if mat != null:
			mat.set_shader_parameter("vat_enabled", flag)
	if outline_walker != null and outline_walker.material_override is ShaderMaterial:
		(outline_walker.material_override as ShaderMaterial).set_shader_parameter("vat_enabled", flag)
	if outline_walker_lod != null and outline_walker_lod.material_override is ShaderMaterial:
		(outline_walker_lod.material_override as ShaderMaterial).set_shader_parameter("vat_enabled", flag)


func _put_body(buf: PackedFloat32Array, index: int, pool: EnemyPool, id: int, vat: VatClipset = null) -> void:
	var o := index * 16
	buf[o + 0] = 1.0
	buf[o + 1] = 0.0
	buf[o + 2] = 0.0
	buf[o + 3] = pool.x[id]
	buf[o + 4] = 0.0
	buf[o + 5] = 1.0
	buf[o + 6] = 0.0
	buf[o + 7] = 0.0
	buf[o + 8] = 0.0
	buf[o + 9] = 0.0
	buf[o + 10] = 1.0
	buf[o + 11] = pool.z[id]
	buf[o + 12] = 1.0 if pool.flash_left[id] > 0.0 else 0.0
	var dissolve := 0.0
	if pool.state[id] == EnemyPool.State.DYING:
		dissolve = clampf(1.0 - pool.dissolve_left[id] / EnemyPool.DISSOLVE_TIME, 0.0, 1.0)
	buf[o + 13] = dissolve
	if vat != null:
		# Stable until the clip changes. The shader turns start time into a frame.
		buf[o + 14] = pool.vat_start[id]
		buf[o + 15] = VatClipset.pack_clip(pool.variant[id], pool.vat_clip[id])
	else:
		buf[o + 14] = fposmod(pool.vat_frame[id], 64.0) / 64.0
		buf[o + 15] = pool.variant[id]


func _write_warnings(sim: CombatSim) -> int:
	var warnings := sim.warnings
	var n := 0
	var i := 0
	while i < GroundWarning.CAP:
		if warnings.active[i] != 0:
			var width := (warnings.x1[i] - warnings.x0[i]) * (1.0 + 0.05 * sin(warnings.age[i] * 16.0))
			_put_quad(_buf_warning, n, (warnings.x0[i] + warnings.x1[i]) * 0.5, 0.06, sim.squad.position.z, width, 8.0)
			n += 1
		i += 1
	return n


func _write_gems(sim: CombatSim) -> int:
	var drops := sim.drops
	var n := 0
	var i := 0
	var cap := drops.capacity()
	while i < cap and n < XpDropPool.CAPACITY:
		if drops.alive[i] != 0:
			var bob := sin(drops.phase[i]) * 0.08
			_put_quad(_buf_gem, n, drops.x[i], 0.15 + bob, drops.z[i], 1.0, 1.0)
			n += 1
		i += 1
	return n


func _write_bars(sim: CombatSim) -> int:
	var pool := sim.enemies
	var n := 0
	var a := 0
	while a < pool.active_n and n < ELITE_CAP:
		var i := pool.active_ids[a]
		a += 1
		if pool.archetype[i] != EnemyPool.Archetype.ELITE or pool.state[i] == EnemyPool.State.FREE:
			continue
		var ratio := 0.0
		if pool.hp_max[i] > 0.0:
			ratio = clampf(pool.hp[i] / pool.hp_max[i], 0.0, 1.0)
		_put_quad(_buf_bar, n, pool.x[i], 3.35, pool.z[i], maxf(0.12, 1.8 * ratio), 0.16)
		n += 1
	return n


func _write_casualties(sim: CombatSim) -> int:
	var pool := sim.casualties
	var n := 0
	var i := 0
	while i < CasualtyPool.CAP:
		if pool.active[i] != 0:
			var o := n * 16
			_buf_casualty[o + 0] = 1.0
			_buf_casualty[o + 1] = 0.0
			_buf_casualty[o + 2] = 0.0
			_buf_casualty[o + 3] = pool.x[i]
			_buf_casualty[o + 4] = 0.0
			_buf_casualty[o + 5] = 1.0
			_buf_casualty[o + 6] = 0.0
			_buf_casualty[o + 7] = 0.0
			_buf_casualty[o + 8] = 0.0
			_buf_casualty[o + 9] = 0.0
			_buf_casualty[o + 10] = 1.0
			_buf_casualty[o + 11] = pool.z[i]
			_buf_casualty[o + 12] = 0.0
			_buf_casualty[o + 13] = clampf(1.0 - pool.life[i] / EnemyPool.DISSOLVE_TIME, 0.0, 1.0)
			_buf_casualty[o + 14] = 0.0
			_buf_casualty[o + 15] = 0.15
			n += 1
		i += 1
	return n


func _put_quad(buf: PackedFloat32Array, index: int, px: float, py: float, pz: float, sx: float, sz: float) -> void:
	var o := index * 12
	buf[o + 0] = sx
	buf[o + 1] = 0.0
	buf[o + 2] = 0.0
	buf[o + 3] = px
	buf[o + 4] = 0.0
	buf[o + 5] = 1.0
	buf[o + 6] = 0.0
	buf[o + 7] = py
	buf[o + 8] = 0.0
	buf[o + 9] = 0.0
	buf[o + 10] = sz
	buf[o + 11] = pz


func _write_kind(buf: PackedFloat32Array, stride: int, sim: CombatSim, kind: int, cap: int, flip: bool) -> int:
	var pool := sim.enemies
	var ids := pool.active_ids
	var states := pool.state
	var kinds := pool.archetype
	var xs := pool.x
	var zs := pool.z
	var flashes := pool.flash_left
	var dissolves := pool.dissolve_left
	var frames := pool.vat_frame
	var variants := pool.variant
	var n := 0
	var a := 0
	var xx := -1.0 if flip else 1.0
	var zz := -1.0 if flip else 1.0
	while a < pool.active_n and n < cap:
		var i := ids[a]
		a += 1
		if states[i] == EnemyPool.State.FREE or kinds[i] != kind:
			continue
		var o := n * stride
		buf[o + 0] = xx
		buf[o + 1] = 0.0
		buf[o + 2] = 0.0
		buf[o + 3] = xs[i]
		buf[o + 4] = 0.0
		buf[o + 5] = 1.0
		buf[o + 6] = 0.0
		buf[o + 7] = 0.0
		buf[o + 8] = 0.0
		buf[o + 9] = 0.0
		buf[o + 10] = zz
		buf[o + 11] = zs[i]
		buf[o + 12] = 1.0 if flashes[i] > 0.0 else 0.0
		var dissolve := 0.0
		if states[i] == EnemyPool.State.DYING:
			dissolve = clampf(1.0 - dissolves[i] / EnemyPool.DISSOLVE_TIME, 0.0, 1.0)
		buf[o + 13] = dissolve
		buf[o + 14] = fposmod(frames[i], 64.0) / 64.0
		buf[o + 15] = variants[i]
		n += 1
	return n


func _write_blobs(sim: CombatSim) -> int:
	var buf := _buf_blob
	var pool := sim.enemies
	var ids := pool.active_ids
	var xs := pool.x
	var zs := pool.z
	var rad := pool.radius
	var n := 0
	var a := 0
	while a < pool.active_n and n < BLOB_CAP:
		var i := ids[a]
		a += 1
		var diameter := rad[i] * 2.2
		var o := n * 12
		buf[o + 0] = diameter
		buf[o + 1] = 0.0
		buf[o + 2] = 0.0
		buf[o + 3] = xs[i]
		buf[o + 4] = 0.0
		buf[o + 5] = 1.0
		buf[o + 6] = 0.0
		buf[o + 7] = 0.04
		buf[o + 8] = 0.0
		buf[o + 9] = 0.0
		buf[o + 10] = diameter
		buf[o + 11] = zs[i]
		n += 1
	var anchor := sim.squad.position
	var offsets := sim.squad.displayed_offsets
	var s := 0
	while s < offsets.size() and n < BLOB_CAP:
		var o2 := n * 12
		buf[o2 + 0] = 0.7
		buf[o2 + 1] = 0.0
		buf[o2 + 2] = 0.0
		buf[o2 + 3] = anchor.x + offsets[s].x
		buf[o2 + 4] = 0.0
		buf[o2 + 5] = 1.0
		buf[o2 + 6] = 0.0
		buf[o2 + 7] = 0.04
		buf[o2 + 8] = 0.0
		buf[o2 + 9] = 0.0
		buf[o2 + 10] = 0.7
		buf[o2 + 11] = anchor.z + offsets[s].z
		n += 1
		s += 1
	return n


func _write_bullets(sim: CombatSim) -> int:
	var buf := _buf_bullet
	var pool := sim.bullets
	var n := 0
	var i := 0
	while i < pool.capacity and n < BULLET_CAP:
		if pool.alive[i] != 0:
			var o := n * 12
			buf[o + 0] = 1.0
			buf[o + 1] = 0.0
			buf[o + 2] = 0.0
			buf[o + 3] = pool.x[i]
			buf[o + 4] = 0.0
			buf[o + 5] = 1.0
			buf[o + 6] = 0.0
			buf[o + 7] = pool.y[i]
			buf[o + 8] = 0.0
			buf[o + 9] = 0.0
			buf[o + 10] = 1.0
			buf[o + 11] = pool.z[i]
			n += 1
		i += 1
	return n


func _apply_squad_tier(squad: SquadAnchor) -> void:
	var outfit := squad.outfit_tier()
	var gun := squad.weapon_tier()
	if outfit != shown_outfit:
		squad_body_mm.multimesh.mesh = SoldierVisuals.body_mesh(outfit)
		shown_outfit = outfit
		squad_mesh_rebinds += 1
	if gun != shown_weapon:
		squad_weapon_mm.multimesh.mesh = SoldierVisuals.weapon_mesh(gun)
		shown_weapon = gun
		squad_mesh_rebinds += 1


func _write_squad(sim: CombatSim) -> int:
	var offsets := sim.squad.displayed_offsets
	var n := mini(offsets.size(), SQUAD_CAP)
	var anchor := sim.squad.position
	var i := 0
	while i < n:
		var o := i * 12
		var px := anchor.x + offsets[i].x
		var pz := anchor.z + offsets[i].z
		# Weapons are modeled in soldier space (gun at the right hip). Offset 0.
		_write_origin(_buf_squad, o, px, pz)
		_write_origin(_buf_weapon, o, px, pz)
		i += 1
	return n


func _write_origin(buf: PackedFloat32Array, o: int, px: float, pz: float) -> void:
	buf[o + 0] = 1.0
	buf[o + 1] = 0.0
	buf[o + 2] = 0.0
	buf[o + 3] = px
	buf[o + 4] = 0.0
	buf[o + 5] = 1.0
	buf[o + 6] = 0.0
	buf[o + 7] = 0.0
	buf[o + 8] = 0.0
	buf[o + 9] = 0.0
	buf[o + 10] = 1.0
	buf[o + 11] = pz


func _commit(node: MultiMeshInstance3D, buf: PackedFloat32Array, count: int) -> void:
	var mm := node.multimesh
	mm.visible_instance_count = count
	mm.buffer = buf


func _make_buffer(node: MultiMeshInstance3D) -> PackedFloat32Array:
	var mm := node.multimesh
	var stride := 12
	if mm.use_colors:
		stride += 4
	if mm.use_custom_data:
		stride += 4
	var buf := PackedFloat32Array()
	buf.resize(mm.instance_count * stride)
	return buf


func _vat_material(base: ShaderMaterial, vat: VatClipset) -> ShaderMaterial:
	if vat == null:
		return null
	var mat := base.duplicate() as ShaderMaterial
	vat.apply_to(mat)
	return mat


func _apply_vat_aabb(mesh: Mesh, vat: VatClipset) -> void:
	if vat == null or not (mesh is ArrayMesh):
		return
	# Death falls to about z + 1.9 m. The lane-sized node AABB still culls the
	# whole crowd as one object; this is the per-mesh bound that pose uses.
	(mesh as ArrayMesh).custom_aabb = vat.padded_aabb()


func _add_vat_outline(node_name: String, source: MultiMeshInstance3D, vat: VatClipset) -> MultiMeshInstance3D:
	if vat == null:
		return null
	var mat := toon.outline_material.duplicate() as ShaderMaterial
	vat.apply_to(mat)
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = source.multimesh
	inst.material_override = mat
	inst.visible = false
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	inst.custom_aabb = source.custom_aabb
	add_child(inst)
	return inst


func _add_outline(node_name: String, source: MultiMeshInstance3D) -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = source.multimesh
	inst.material_override = toon.outline_material
	inst.visible = false
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	inst.custom_aabb = source.custom_aabb
	add_child(inst)
	return inst


func _configure_palette(mat: ShaderMaterial, mesh_uv: bool) -> void:
	mat.set_shader_parameter("vat_enabled", 0.0)
	mat.set_shader_parameter("vat_frame_count", 1.0)
	if mesh_uv:
		var tex: Texture2D = load("res://assets/textures/palette.png")
		mat.set_shader_parameter("palette", tex)
		mat.set_shader_parameter("use_mesh_uv", 1.0)
		mat.set_shader_parameter("use_uniform_color", 0.0)
		mat.set_shader_parameter("wobble_enabled", 0.0)
		return
	mat.set_shader_parameter("use_mesh_uv", 0.0)
	var image := Image.create(8, 1, false, Image.FORMAT_RGBA8)
	var colors := [
		Color(0.42, 0.5, 0.3),
		Color(0.36, 0.42, 0.26),
		Color(0.5, 0.4, 0.28),
		Color(0.33, 0.36, 0.24),
		Color(0.45, 0.22, 0.2),
		Color(0.55, 0.18, 0.16),
		Color(0.32, 0.16, 0.18),
		Color(0.62, 0.24, 0.16),
	]
	for i in colors.size():
		image.set_pixel(i, 0, colors[i])
	var tex := ImageTexture.create_from_image(image)
	mat.set_shader_parameter("palette", tex)


func _add_body(node_name: String, mesh: Mesh, capacity: int, mat: Material) -> MultiMeshInstance3D:
	return _add_plain(node_name, mesh, capacity, mat, true)


func _add_plain(node_name: String, mesh: Mesh, capacity: int, mat: Material, custom: bool) -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = MultiMeshBuffer.make_multimesh(mesh, capacity, custom)
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	inst.custom_aabb = AABB(Vector3(-80.0, -5.0, -8000.0), Vector3(160.0, 20.0, 16000.0))
	add_child(inst)
	return inst
