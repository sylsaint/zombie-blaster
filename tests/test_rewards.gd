extends GutTest

const _Clock := preload("res://scripts/game_clock.gd")


var _paths: Array[String] = []
var _seq: int = 0


func after_each() -> void:
	for path in _paths:
		var dir := DirAccess.open("user://")
		if dir == null:
			continue
		var suffixes: Array[String] = ["", SaveStore.BAK_SUFFIX, SaveStore.TMP_SUFFIX]
		for suffix in suffixes:
			var file_name: String = str(path) + suffix
			file_name = file_name.get_file()
			if dir.file_exists(file_name):
				dir.remove(file_name)
	_paths.clear()
	var clock := get_node_or_null("/root/GameClock")
	if clock != null and clock.hit_stop_remaining() > 0.0:
		clock.advance(clock.hit_stop_remaining() + 0.05)


func _scratch(tag: String) -> String:
	_seq += 1
	var path := "user://gut_%s_%d.json" % [tag, _seq]
	_paths.append(path)
	return path


func _clock():
	return get_node("/root/GameClock")


func _result(level: LevelData, outcome: String, head: int, hits: int, progress: float, run_coins: int) -> RunResult:
	var result := RunResult.new()
	result.outcome = outcome
	result.level_index = level.level_index
	result.headcount = head
	result.finale_skill_hits = hits
	result.progress = progress
	result.run_coins = run_coins
	result.base_clear_coins = level.base_clear_coins
	result.star2_headcount = level.star2_headcount
	result.first_clear_parts = level.first_clear_parts
	result.three_star_chest_coin_multiplier = level.three_star_chest_coin_multiplier
	result.three_star_chest_parts = level.three_star_chest_parts
	result.three_star_chest_paid_separately = level.three_star_chest_paid_separately
	result.fail_coin_ratio = level.fail_coin_ratio
	result.star_coin_multipliers = level.star_coin_multipliers
	return result


func _events(items: Array) -> Array[LevelEvent]:
	var out: Array[LevelEvent] = []
	for item in items:
		out.append(item)
	return out


func _flow(path: String) -> CampaignFlow:
	var root := Node.new()
	root.name = "Harness"
	add_child_autofree(root)
	var host := LevelHost.new()
	host.name = "LevelHost"
	var flow := CampaignFlow.new()
	flow.name = "UI"
	flow.save_path = path
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	menu.name = "MainMenu"
	var select: Node = load("res://scenes/ui/level_select.tscn").instantiate()
	select.name = "LevelSelect"
	var results: Node = load("res://scenes/ui/results_screen.tscn").instantiate()
	results.name = "Results"
	flow.add_child(menu)
	flow.add_child(select)
	flow.add_child(results)
	root.add_child(host)
	root.add_child(flow)
	return flow


func _force(session: LevelSession, outcome: String, head: int, hits: int, run_coins: int) -> void:
	session.sim.squad.count = head
	session.run_coins = run_coins
	session._finale_skill_hits = hits
	session._finish(outcome)


func test_ac_rw_01_clear_coins_use_star_multiplier_plus_run_coins() -> void:
	var bases := {1: 100, 2: 120, 3: 140}
	var mults := {1: 1.0, 2: 1.2, 3: 1.5}
	var clear_for := {
		1: {1: 100, 2: 120, 3: 150},
		2: {1: 120, 2: 144, 3: 180},
		3: {1: 140, 2: 168, 3: 210},
	}
	for index in bases.keys():
		var level := LevelCatalog.load_index(int(index))
		assert_eq(level.base_clear_coins, int(bases[index]))
		var run := 13
		for stars in [1, 2, 3]:
			var head := 0
			var hits := 9
			if stars >= 2:
				head = level.star2_headcount
			if stars == 3:
				hits = 1
			var view := RewardRules.build(_result(level, "win", head, hits, 1.0, run), PlayerProfile.new())
			assert_eq(view.star_count, stars, "level %d expected %d stars" % [int(index), stars])
			assert_almost_eq(view.star_multiplier, float(mults[stars]), 0.001)
			var clear := int(clear_for[index][stars])
			assert_eq(view.clear_coins, clear)
			assert_eq(view.payout_coins, clear + run)
			assert_false(view.total_line.contains("三星宝箱"))


func test_ac_rw_01_level_table_chests() -> void:
	var expected := {1: 200, 2: 240, 3: 280}
	for index in expected.keys():
		var level := LevelCatalog.load_index(int(index))
		assert_almost_eq(level.three_star_chest_coin_multiplier, 2.0, 0.001)
		assert_true(level.three_star_chest_paid_separately)
		assert_eq(level.base_clear_coins * 2, int(expected[index]))
		var chest := RewardRules.chest_coins_for(level.base_clear_coins, level.three_star_chest_coin_multiplier)
		assert_eq(chest, int(expected[index]))
		var view := RewardRules.build(
			_result(level, "win", level.star2_headcount, 0, 1.0, 77),
			PlayerProfile.new()
		)
		assert_eq(view.star_count, 3)
		assert_eq(view.chest_coins, int(expected[index]))
		assert_eq(view.payout_coins, roundi(float(level.base_clear_coins) * 1.5) + 77)
		assert_ne(view.chest_coins, view.payout_coins)
		assert_true(view.chest_line.begins_with("三星宝箱"))
		assert_true(view.chest_line.contains(str(expected[index])))
		assert_false(view.total_line.contains("三星宝箱"))
		assert_false(view.total_line.contains(str(view.chest_coins)))
	assert_eq(RewardRules.chest_coins_for(100, 2.0), 200)
	assert_eq(RewardRules.chest_coins_for(140, 2.0), 280)


func test_ac_rw_01_results_screen_splits_chest_from_the_total() -> void:
	var screen := load("res://scenes/ui/results_screen.tscn").instantiate() as ResultsScreen
	add_child_autofree(screen)
	var level := LevelCatalog.load_index(1)
	var win := RewardRules.build(_result(level, "win", 20, 0, 1.0, 77), PlayerProfile.new())
	assert_eq(win.chest_coins, 200)
	assert_eq(win.payout_coins, 227)
	screen.present(win)
	var total := screen.get_node("%TotalLine") as Label
	var chest := screen.get_node("%ChestLine") as Label
	assert_ne(total.get_parent(), chest.get_parent())
	assert_eq(total.text, win.total_line)
	assert_eq(chest.text, win.chest_line)
	assert_true(chest.visible)
	assert_true(chest.text.contains("200"))
	assert_false(total.text.contains("200"))
	assert_eq(screen.get_node("%Title").text, "胜利")
	assert_true(_star_filled(screen, "StarClearRow"))
	assert_true(_star_filled(screen, "StarSquadRow"))
	assert_true(_star_filled(screen, "StarHitsRow"))
	assert_eq((screen.get_node("%StarClear") as Label).theme_type_variation, &"StatLabel")
	assert_eq((screen.get_node("%StarSquad") as Label).theme_type_variation, &"StatLabel")
	assert_eq((screen.get_node("%StarHits") as Label).theme_type_variation, &"StatLabel")
	assert_eq((screen.get_node("%ChestLine") as Label).theme_type_variation, &"StatLabel")
	assert_eq((screen.get_node("%StarClear") as Label).text, "通关")
	assert_false((screen.get_node("%StarClear") as Label).text.contains("★"))
	assert_false((screen.get_node("%StarClear") as Label).text.contains("☆"))
	assert_false((screen.get_node("%Retry") as Button).disabled)
	assert_false((screen.get_node("%Next") as Button).disabled)
	assert_false((screen.get_node("%Back") as Button).disabled)
	var level3 := LevelCatalog.load_index(3)
	var boss := RewardRules.build(_result(level3, "win", 32, 1, 1.0, 0), PlayerProfile.new())
	assert_eq(level3.base_clear_coins, 140)
	assert_eq(boss.chest_coins, 280)
	assert_eq(boss.clear_coins, 210)
	assert_eq(boss.parts, 15)
	assert_eq(boss.chest_parts, 5)
	screen.present(boss)
	assert_true((screen.get_node("%ChestLine") as Label).text.contains("280"))
	assert_false((screen.get_node("%TotalLine") as Label).text.contains("280"))
	assert_true((screen.get_node("%Next") as Button).disabled)
	var fail := RewardRules.build(_result(level, "lose", 0, 0, 0.5, 10), PlayerProfile.new())
	screen.present(fail)
	assert_eq(screen.get_node("%Title").text, "失败")
	assert_false((screen.get_node("%ClearLine") as Label).visible)
	assert_false((screen.get_node("%ClearLine") as Label).text.contains("通关金币"))
	assert_true((screen.get_node("%RunLine") as Label).text.begins_with("进度"))
	assert_true((screen.get_node("%TotalLine") as Label).text.begins_with("失败金币"))
	assert_false((screen.get_node("%ChestLine") as Label).visible)
	assert_true((screen.get_node("%Next") as Button).disabled)
	assert_false((screen.get_node("%Retry") as Button).disabled)
	assert_false((screen.get_node("%Back") as Button).disabled)
	assert_false((screen.get_node("%StarClearRow") as Control).visible)
	assert_false((screen.get_node("%StarSquadRow") as Control).visible)
	assert_false((screen.get_node("%StarHitsRow") as Control).visible)
	assert_eq((screen.get_node("%StarSquad") as Label).text, "")
	assert_true((screen.get_node("%RunLine") as Label).visible)
	assert_true((screen.get_node("%TotalLine") as Label).visible)
	assert_eq((screen.get_node("Margin/Sheet/Column/Breakdown") as PanelContainer).theme_type_variation, &"RewardPanel")
	assert_eq((screen.get_node("%ClearLine") as Label).theme_type_variation, &"RewardLabel")
	assert_eq((screen.get_node("%RunLine") as Label).theme_type_variation, &"RewardLabel")
	assert_eq((screen.get_node("%TotalLine") as Label).theme_type_variation, &"RewardLabel")
	assert_eq((screen.get_node("%PartsLine") as Label).theme_type_variation, &"RewardLabel")


func test_ac_rw_02_stars_are_judged_independently() -> void:
	var level := LevelCatalog.load_index(1)
	var only: Dictionary = RewardRules.judge(_result(level, "win", 19, 2, 1.0, 0))
	assert_true(only["clear"])
	assert_false(only["squad"])
	assert_false(only["hits"])
	assert_eq(only["count"], 1)
	var squad: Dictionary = RewardRules.judge(_result(level, "win", 20, 2, 1.0, 0))
	assert_true(squad["clear"])
	assert_true(squad["squad"])
	assert_false(squad["hits"])
	assert_eq(squad["count"], 2)
	var hits: Dictionary = RewardRules.judge(_result(level, "win", 19, 1, 1.0, 0))
	assert_true(hits["clear"])
	assert_false(hits["squad"])
	assert_true(hits["hits"])
	assert_eq(hits["count"], 2)
	var all_three: Dictionary = RewardRules.judge(_result(level, "win", 20, 0, 1.0, 0))
	assert_eq(all_three["count"], 3)
	var wipe: Dictionary = RewardRules.judge(_result(level, "lose", 100, 0, 0.4, 0))
	assert_false(wipe["clear"])
	assert_false(wipe["squad"])
	assert_false(wipe["hits"])
	assert_eq(wipe["count"], 0)
	var level3 := LevelCatalog.load_index(3)
	assert_eq(level3.star2_headcount, 32)
	var short: Dictionary = RewardRules.judge(_result(level3, "win", 31, 1, 1.0, 0))
	assert_true(short["clear"])
	assert_false(short["squad"])
	assert_true(short["hits"])
	var enough: Dictionary = RewardRules.judge(_result(level3, "win", 32, 2, 1.0, 0))
	assert_true(enough["squad"])
	assert_false(enough["hits"])
	var screen := load("res://scenes/ui/results_screen.tscn").instantiate() as ResultsScreen
	add_child_autofree(screen)
	var mixed := RewardRules.build(_result(level, "win", 5, 1, 1.0, 0), PlayerProfile.new())
	assert_eq(mixed.star_count, 2)
	assert_almost_eq(mixed.star_multiplier, 1.2, 0.001)
	assert_eq(mixed.clear_coins, 120)
	screen.present(mixed)
	assert_true(_star_filled(screen, "StarClearRow"))
	assert_false(_star_filled(screen, "StarSquadRow"))
	assert_true(_star_filled(screen, "StarHitsRow"))
	assert_true((screen.get_node("%StarSquadRow") as Control).visible)
	assert_eq((screen.get_node("%StarSquad") as Label).text, "人数 5 / 20")
	assert_false((screen.get_node("%StarSquad") as Label).text.contains("☆"))


func test_ac_rw_03_first_clear_parts_pay_once() -> void:
	var profile := PlayerProfile.new()
	var level1 := LevelCatalog.load_index(1)
	var level3 := LevelCatalog.load_index(3)
	assert_eq(level1.first_clear_parts, 5)
	assert_eq(level3.first_clear_parts, 15)
	var win1 := RewardRules.build(_result(level1, "win", 1, 4, 1.0, 0), profile)
	assert_eq(win1.parts, 5)
	assert_false(win1.chest_awarded)
	RewardRules.apply(profile, win1)
	assert_eq(profile.parts, 5)
	assert_true(profile.has_first_clear(1))
	var repeat1 := RewardRules.build(_result(level1, "win", 1, 4, 1.0, 9), profile)
	assert_eq(repeat1.parts, 0)
	assert_eq(repeat1.payout_coins, 109)
	var fail := RewardRules.build(_result(level3, "lose", 0, 0, 1.0, 0), profile)
	assert_eq(fail.parts, 0)
	RewardRules.apply(profile, fail)
	assert_false(profile.has_first_clear(3))
	var win3 := RewardRules.build(_result(level3, "win", 1, 4, 1.0, 0), profile)
	assert_eq(win3.parts, 15)
	assert_false(win3.chest_awarded)
	RewardRules.apply(profile, win3)
	assert_eq(profile.parts, 20)
	var later := RewardRules.build(_result(level3, "win", 32, 0, 1.0, 0), profile)
	assert_eq(later.parts, 0)
	assert_true(later.chest_awarded)
	assert_eq(later.chest_coins, 280)
	assert_eq(later.chest_parts, 5)
	RewardRules.apply(profile, later)
	assert_eq(profile.parts, 25)
	var third := RewardRules.build(_result(level3, "win", 32, 0, 1.0, 2), profile)
	assert_eq(third.parts, 0)
	assert_false(third.chest_awarded)
	assert_eq(third.payout_coins, 210 + 2)
	var coins := profile.coins
	RewardRules.apply(profile, third)
	RewardRules.apply(profile, third)
	assert_eq(profile.coins, coins + third.payout_coins)


func test_ac_rw_03_repeat_clear_pays_coins_without_parts() -> void:
	var path := _scratch("repeat")
	var flow := _flow(path)
	flow.begin_level(1)
	_force(flow.host.session, "win", 4, 6, 5)
	flow._process(0.0)
	assert_true(flow.results_view.visible)
	assert_eq(flow.profile.parts, 5)
	assert_eq(flow.profile.coins, 105)
	var held := flow.profile.coins
	flow._process(0.0)
	assert_eq(flow.profile.coins, held)
	flow.begin_level(1)
	_force(flow.host.session, "win", 4, 6, 8)
	flow._process(0.0)
	assert_eq(flow.profile.parts, 5)
	assert_eq(flow.profile.coins, 213)
	var reloaded := _flow(path)
	assert_eq(reloaded.profile.parts, 5)
	assert_eq(reloaded.profile.coins, 213)
	assert_true(reloaded.profile.has_first_clear(1))
	assert_false(reloaded.profile.has_three_star(1))
	assert_eq(reloaded.profile.unlocked_through, 2)


func test_ac_rw_04_fail_coins_are_clear_times_thirty_percent_times_progress() -> void:
	var level := LevelCatalog.load_index(1)
	var profile := PlayerProfile.new()
	var half := RewardRules.build(_result(level, "lose", 0, 0, 0.5, 80), profile)
	assert_eq(half.star_count, 0)
	assert_eq(half.fail_coins, 15)
	assert_eq(half.payout_coins, 15)
	assert_eq(half.parts, 0)
	assert_false(half.chest_awarded)
	assert_eq(half.run_coins, 80)
	var full := RewardRules.build(_result(level, "lose", 30, 0, 1.0, 0), profile)
	assert_eq(full.fail_coins, 30)
	assert_eq(full.star_count, 0)
	var none := RewardRules.build(_result(level, "lose", 0, 0, 0.0, 0), profile)
	assert_eq(none.fail_coins, 0)
	var level3 := LevelCatalog.load_index(3)
	var boss := RewardRules.build(_result(level3, "lose", 0, 4, 1.0, 0), profile)
	assert_eq(boss.fail_coins, 42)
	var over := RewardRules.build(_result(level, "lose", 0, 0, 2.0, 0), profile)
	assert_eq(over.fail_coins, 30)


func test_ac_rw_04_boss_failure_counts_full_progress() -> void:
	var clock = autofree(_Clock.new())
	var level := LevelData.new()
	level.level_index = 3
	level.base_clear_coins = 140
	level.fail_coin_ratio = 0.30
	level.boss_hp = 27000.0
	var event := LevelEvent.new()
	event.distance = 0.0
	event.kind = "boss"
	level.events = _events([event])
	var session := LevelSession.new()
	session.start(level, clock)
	session.tick(0.05)
	assert_ne(session.boss, null)
	session.sim.squad.count = 0
	session.tick(0.01)
	assert_eq(session.result.outcome, "lose")
	assert_almost_eq(session.result.progress, 1.0, 0.001)
	var view := RewardRules.build(session.result, PlayerProfile.new())
	assert_eq(view.fail_coins, 42)
	var level1 := LevelCatalog.load_index(1)
	var advance := LevelSession.new()
	advance.start(level1, clock)
	advance.incoming_damage = false
	advance.lock_headcount = true
	advance.tick(2.0)
	advance.lock_headcount = false
	advance.sim.squad.count = 0
	advance.tick(0.01)
	assert_eq(advance.result.outcome, "lose")
	assert_gt(advance.result.progress, 0.0)
	assert_lt(advance.result.progress, 1.0)
	var expected := roundi(float(level1.base_clear_coins) * level1.fail_coin_ratio * advance.result.progress)
	assert_eq(RewardRules.build(advance.result, PlayerProfile.new()).fail_coins, expected)


func test_ac_rw_05_attack_cost_matches_the_table() -> void:
	var expected := {
		1: 50,
		2: 60,
		3: 70,
		4: 90,
		5: 120,
		6: 150,
		7: 190,
		8: 230,
		9: 290,
		10: 370,
		11: 460,
		12: 580,
		13: 720,
		14: 900,
		15: 1130,
		16: 1420,
		17: 1770,
		18: 2220,
		19: 2770,
		20: 3460,
		21: 4330,
		22: 5420,
		23: 6770,
		24: 8470,
		25: 10580,
		26: 13230,
		27: 16540,
		28: 20670,
		29: 25840,
		30: 32310,
	}
	for k in expected.keys():
		assert_eq(MetaUpgrade.cost_for_level(int(k)), int(expected[k]), "level %d" % int(k))
	var profile := PlayerProfile.new()
	profile.coins = 49
	assert_false(MetaUpgrade.try_buy(profile))
	assert_eq(profile.attack_level, 0)
	assert_eq(profile.coins, 49)
	profile.coins = 10000000
	var spent := 0
	for k in range(1, 31):
		assert_eq(MetaUpgrade.next_cost(profile.attack_level), int(expected[k]))
		assert_true(MetaUpgrade.try_buy(profile))
		spent += int(expected[k])
		assert_eq(profile.attack_level, k)
	assert_eq(profile.coins, 10000000 - spent)
	assert_eq(MetaUpgrade.next_cost(30), -1)
	assert_false(MetaUpgrade.can_buy(profile))
	assert_false(MetaUpgrade.try_buy(profile))
	assert_eq(profile.attack_level, 30)
	assert_almost_eq(WeaponMods.meta_attack_bonus(30), 0.08 * 30.0, 0.0001)
	assert_almost_eq(WeaponMods.meta_attack_bonus(31), 0.08 * 30.0, 0.0001)


func test_ac_rw_05_upgrade_applies_next_run_apart_from_gate_and_skill_bonus() -> void:
	var flow := _flow(_scratch("meta"))
	flow.profile.coins = 5000
	flow.begin_level(1)
	var squad := flow.host.session.sim.squad
	assert_eq(squad.meta_attack_levels, 0)
	assert_almost_eq(squad.damage_bonus, 0.0, 0.0001)
	assert_almost_eq(squad.skill_damage_bonus, 0.0, 0.0001)
	flow.menu_view.upgrade_pressed.emit()
	assert_eq(flow.profile.attack_level, 1)
	assert_eq(squad.meta_attack_levels, 0)
	assert_almost_eq(squad.damage_bonus, 0.0, 0.0001)
	assert_almost_eq(squad.skill_damage_bonus, 0.0, 0.0001)
	flow.begin_level(1)
	squad = flow.host.session.sim.squad
	assert_eq(squad.meta_attack_levels, 1)
	assert_almost_eq(squad.damage_bonus, 0.0, 0.0001)
	assert_almost_eq(squad.skill_damage_bonus, 0.0, 0.0001)
	assert_almost_eq(squad.total_damage_bonus(), 0.08, 0.0001)
	squad.damage_bonus = 0.2
	squad.skill_damage_bonus = 0.2
	assert_eq(squad.meta_attack_levels, 1)
	assert_almost_eq(squad.total_damage_bonus(), 0.48, 0.0001)
	var shot := SquadAnchor.shot_damage(10.0, 5, squad.total_damage_bonus())
	assert_almost_eq(shot, 10.0 * pow(5.0, 0.7) * 1.48, shot * 0.005)
	var reloaded := _flow(flow.save_path)
	reloaded.begin_level(1)
	assert_eq(reloaded.host.session.sim.squad.meta_attack_levels, 1)
	assert_almost_eq(reloaded.host.session.sim.squad.damage_bonus, 0.0, 0.0001)
	assert_almost_eq(reloaded.host.session.sim.squad.skill_damage_bonus, 0.0, 0.0001)


func test_ac_rw_06_clear_unlocks_the_next_level() -> void:
	var flow := _flow(_scratch("unlock"))
	assert_true(flow.menu_view.visible)
	assert_null(flow.menu_view.theme)
	assert_eq(flow.menu_view.get_node("%Title").text, GameTitle.TEXT)
	flow.menu_view.play_pressed.emit()
	assert_true(flow.select_view.visible)
	assert_false(flow.menu_view.visible)
	assert_false(flow.select_view.level_button(1).disabled)
	assert_true(flow.select_view.level_button(2).disabled)
	assert_true(flow.select_view.level_button(3).disabled)
	flow.select_view.level_pressed.emit(2)
	assert_null(flow.host.session)
	flow.select_view.level_pressed.emit(1)
	assert_eq(flow.host.session.level.level_index, 1)
	assert_false(flow.results_view.visible)
	_force(flow.host.session, "win", 1, 9, 0)
	flow._process(0.0)
	assert_true(flow.results_view.visible)
	assert_eq(flow.results_view.get_node("%Title").text, "胜利")
	assert_eq(flow.profile.unlocked_through, 2)
	assert_false((flow.results_view.get_node("%Next") as Button).disabled)
	flow.results_view.back_pressed.emit()
	assert_true(flow.select_view.visible)
	assert_false(flow.select_view.level_button(2).disabled)
	assert_true(flow.select_view.level_button(3).disabled)
	flow.select_view.level_pressed.emit(2)
	assert_eq(flow.host.session.level.level_index, 2)
	_force(flow.host.session, "win", 1, 9, 0)
	flow._process(0.0)
	assert_eq(flow.profile.unlocked_through, 3)
	flow.results_view.next_pressed.emit()
	assert_eq(flow.host.session.level.level_index, 3)
	_force(flow.host.session, "win", 1, 9, 0)
	flow._process(0.0)
	assert_gte(flow.profile.unlocked_through, 4)
	assert_true((flow.results_view.get_node("%Next") as Button).disabled)
	flow.results_view.next_pressed.emit()
	assert_eq(flow.host.session.level.level_index, 3)
	flow.results_view.retry_pressed.emit()
	assert_eq(flow.host.session.level.level_index, 3)
	assert_false(flow.results_view.visible)


func test_ac_rw_06_save_round_trip_keeps_progress() -> void:
	var path := _scratch("round")
	var store := SaveStore.new()
	store.path = path
	var profile := PlayerProfile.new()
	profile.coins = 321
	profile.parts = 15
	profile.attack_level = 4
	profile.unlocked_through = 3
	profile.mark_first_clear(1)
	profile.mark_first_clear(3)
	profile.mark_three_star(2)
	assert_true(store.save(profile))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	var data: Dictionary = parsed
	assert_eq(int(data["version"]), SaveStore.VERSION)
	var loaded := store.load_profile()
	assert_eq(loaded.coins, 321)
	assert_eq(loaded.parts, 15)
	assert_eq(loaded.attack_level, 4)
	assert_eq(loaded.unlocked_through, 3)
	assert_true(loaded.has_first_clear(1))
	assert_false(loaded.has_first_clear(2))
	assert_true(loaded.has_first_clear(3))
	assert_false(loaded.has_three_star(1))
	assert_true(loaded.has_three_star(2))
	assert_false(loaded.has_three_star(3))
	var flow := _flow(path)
	assert_eq(flow.profile.coins, 321)
	assert_eq(flow.profile.attack_level, 4)
	flow.menu_view.play_pressed.emit()
	assert_false(flow.select_view.level_button(3).disabled)
	flow.begin_level(2)
	assert_eq(flow.host.session.sim.squad.meta_attack_levels, 4)
	assert_almost_eq(flow.host.session.sim.squad.damage_bonus, 0.0, 0.0001)
	assert_almost_eq(flow.host.session.sim.squad.skill_damage_bonus, 0.0, 0.0001)


func test_ac_rw_06_corrupt_and_old_save_do_not_crash() -> void:
	var path := _scratch("bad")
	var store := SaveStore.new()
	store.path = path
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	var fresh := store.load_profile()
	assert_eq(fresh.coins, 0)
	assert_eq(fresh.parts, 0)
	assert_eq(fresh.attack_level, 0)
	assert_eq(fresh.unlocked_through, 1)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("")
	file.close()
	assert_eq(store.load_profile().unlocked_through, 1)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"version":0,"gold":40,"weapon_parts":7,"attack":2,"progress":2,"cleared":[true,false,false],"three_star":{"3":true}}')
	file.close()
	var old := store.load_profile()
	assert_eq(old.coins, 40)
	assert_eq(old.parts, 7)
	assert_eq(old.attack_level, 2)
	assert_eq(old.unlocked_through, 2)
	assert_true(old.has_first_clear(1))
	assert_false(old.has_first_clear(2))
	assert_true(old.has_three_star(3))
	var flow := _flow(path)
	assert_eq(flow.profile.coins, 40)
	assert_eq(flow.profile.attack_level, 2)
	flow.menu_view.play_pressed.emit()
	assert_false(flow.select_view.level_button(2).disabled)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"version":0,"coins":{"a":1},"parts":"many","attack_level":null,"unlocked_through":"nope","first_clear":"yes","three_star":4}')
	file.close()
	var weird := store.load_profile()
	assert_eq(weird.coins, 0)
	assert_eq(weird.parts, 0)
	assert_eq(weird.attack_level, 0)
	assert_eq(weird.unlocked_through, 1)
	assert_false(weird.has_first_clear(1))
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"version":99,"coins":8,"extra":{"nested":true},"attack_level":99}')
	file.close()
	var future_text := FileAccess.get_file_as_string(path)
	var future := store.load_profile()
	assert_eq(future.coins, 0)
	assert_eq(future.attack_level, 0)
	assert_false(store.save(future))
	assert_eq(FileAccess.get_file_as_string(path), future_text)
	var again := _flow(path)
	assert_eq(again.profile.coins, 0)
	again.begin_level(1)
	assert_eq(again.host.session.sim.squad.meta_attack_levels, 0)
	assert_eq(FileAccess.get_file_as_string(path), future_text)


func test_ac_sq_06_fail_results_within_one_gameplay_second() -> void:
	var saved := Engine.time_scale
	var flow := _flow(_scratch("sq06"))
	flow.begin_level(1)
	var clock = _clock()
	var t_death: float = clock.gameplay_time
	flow.host.session.sim.squad.count = 0
	assert_almost_eq(clock.advance(0.25), 0.25, 0.0001)
	flow.host._process(0.25)
	flow._process(0.25)
	assert_true(flow.results_view.visible)
	assert_eq(flow.results_view.get_node("%Title").text, "失败")
	assert_true((flow.results_view.get_node("%Next") as Button).disabled)
	assert_false((flow.results_view.get_node("%Retry") as Button).disabled)
	assert_lt(clock.gameplay_time - t_death, 1.0)
	assert_lt(flow.results_gameplay_time - t_death, 1.0)
	assert_gte(flow.zero_gameplay_time, 0.0)
	assert_lt(flow.results_gameplay_time - flow.zero_gameplay_time, 1.0)
	assert_eq(Engine.time_scale, saved)
	assert_eq(Engine.time_scale, 1.0)
	var coins := flow.profile.coins
	flow._process(0.0)
	assert_eq(flow.profile.coins, coins)


func test_ac_sq_06_fail_screen_appears_while_gameplay_clock_is_frozen() -> void:
	var saved := Engine.time_scale
	var flow := _flow(_scratch("freeze"))
	flow.begin_level(1)
	var clock = _clock()
	clock.hit_stop(3000.0)
	var t_death: float = clock.gameplay_time
	flow.host.session.sim.squad.count = 0
	assert_almost_eq(clock.advance(0.5), 0.0, 0.0001)
	flow.host._process(0.5)
	flow._process(0.5)
	assert_true(flow.results_view.visible)
	assert_eq(flow.results_view.get_node("%Title").text, "失败")
	assert_lt(clock.gameplay_time - t_death, 1.0)
	assert_lt(flow.results_gameplay_time - t_death, 1.0)
	assert_eq(Engine.time_scale, saved)
	assert_eq(Engine.time_scale, 1.0)


func test_portrait_theme_font_slots_are_empty() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1080)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 1920)
	assert_eq(GameTitle.TEXT, "ZOMBIE BLASTER")
	assert_eq(str(ProjectSettings.get_setting("gui/theme/custom")), "res://assets/ui/game_theme.tres")
	assert_true(FileAccess.file_exists("res://assets/ui/game_theme.tres"))
	var theme := load("res://assets/ui/game_theme.tres") as Theme
	assert_not_null(theme)
	var main_font := theme.default_font as FontVariation
	assert_not_null(main_font)
	var base := main_font.base_font as FontFile
	assert_not_null(base)
	assert_true(base.resource_path.ends_with("ZCOOLKuaiLe-Regular.ttf"))
	assert_eq(main_font.fallbacks.size(), 1)
	var fallback := main_font.fallbacks[0] as FontFile
	assert_not_null(fallback)
	assert_true(fallback.resource_path.ends_with("NotoSansSC-Medium.otf"))
	assert_true(main_font.has_char(("★").unicode_at(0)))
	assert_eq(theme.get_type_variation_base(&"Display"), &"Label")
	assert_eq(theme.get_type_variation_base(&"Body"), &"Label")
	assert_eq(theme.get_font_list(&"Display").size(), 0)
	assert_eq(theme.get_font_list(&"Body").size(), 0)
	assert_true(theme.has_font(&"font", &"Display"))
	assert_true(theme.has_font(&"font", &"Body"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_true(theme.has_stylebox(StringName(state), &"Button"))
	assert_true(theme.has_stylebox(&"panel", &"PanelContainer"))
	var dir := DirAccess.open("res://assets/ui")
	assert_not_null(dir)
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		assert_false(file_name.ends_with(".ttf") or file_name.ends_with(".otf") or file_name.ends_with(".woff"))
		file_name = dir.get_next()
	dir.list_dir_end()
	for scene_path in [
		"res://scenes/ui/results_screen.tscn",
		"res://scenes/ui/main_menu.tscn",
		"res://scenes/ui/level_select.tscn",
		"res://scenes/ui/meta_panel.tscn",
	]:
		var text := FileAccess.get_file_as_string(scene_path)
		assert_false(text.contains("theme_override_colors"))
		assert_false(text.contains("theme_override_fonts"))
		assert_false(text.contains("theme_override_font_sizes"))
		assert_false(text.contains("Color("))
		assert_false(text.contains("game_theme"))
		var view := load(scene_path).instantiate() as Control
		add_child_autofree(view)
		assert_null(view.theme)
		_assert_named_controls(view)
		_assert_buttons_skip_focus(view)
		if scene_path != "res://scenes/ui/meta_panel.tscn":
			assert_almost_eq(view.anchor_right, 1.0, 0.001)
			assert_almost_eq(view.anchor_bottom, 1.0, 0.001)
	var cards := load("res://scenes/ui/card_select.tscn").instantiate() as Control
	add_child_autofree(cards)
	_assert_buttons_skip_focus(cards)
	var menu := load("res://scenes/ui/main_menu.tscn").instantiate() as MainMenu
	add_child_autofree(menu)
	assert_eq((menu.get_node("%Title") as Label).theme_type_variation, &"Display")
	assert_eq((menu.get_node("Margin/Sheet/Column/Subtitle") as Label).theme_type_variation, &"HeaderLabel")
	assert_eq((menu.get_node("%Meta/Attack") as Label).theme_type_variation, &"StatLabel")
	assert_eq((menu.get_node("%Meta/Wallet") as Label).theme_type_variation, &"StatLabel")
	assert_eq((menu.get_node("%Meta/Upgrade") as Button).theme_type_variation, &"UpgradeButton")
	assert_eq((menu.get_node("%Title") as Label).text, GameTitle.TEXT)


func test_release_exclude_keeps_menu_and_level_select() -> void:
	var text := FileAccess.get_file_as_string("res://export_presets.cfg")
	var filters: Array[String] = []
	for line in text.split("\n"):
		if not line.begins_with("exclude_filter="):
			continue
		var raw := line.trim_prefix("exclude_filter=").strip_edges()
		raw = raw.trim_prefix("\"").trim_suffix("\"")
		for part in raw.split(","):
			var pattern := part.strip_edges()
			if not pattern.is_empty():
				filters.append(pattern)
	assert_gt(filters.size(), 0)
	for scene_path in [
		"scenes/ui/main_menu.tscn",
		"scenes/ui/level_select.tscn",
		"scenes/ui/results_screen.tscn",
		"scenes/ui/meta_panel.tscn",
	]:
		assert_true(FileAccess.file_exists("res://" + scene_path))
		for pattern in filters:
			assert_false(scene_path.match(pattern))


func test_qa_clear_coins_and_chest_use_base_only() -> void:
	var level := LevelCatalog.load_index(1)
	var profile := PlayerProfile.new()
	var win := RewardRules.build(_result(level, "win", 20, 0, 1.0, 40), profile)
	assert_eq(win.star_count, 3)
	assert_almost_eq(win.star_multiplier, 1.5, 0.0001)
	assert_eq(win.clear_coins, 150)
	assert_eq(win.payout_coins, 190)
	assert_eq(win.chest_coins, 200)
	assert_eq(win.chest_coins, level.base_clear_coins * 2)
	assert_ne(win.chest_coins, 200 + 40)
	assert_true(win.show_chest_line)
	var one := RewardRules.build(_result(level, "win", 10, 4, 1.0, 7), profile)
	assert_eq(one.star_count, 1)
	assert_eq(one.clear_coins, 100)
	assert_eq(one.payout_coins, 107)
	assert_eq(one.chest_coins, 0)
	assert_false(one.show_chest_line)
	var boss := LevelCatalog.load_index(3)
	var chest := RewardRules.build(_result(boss, "win", 32, 0, 1.0, 99), profile)
	assert_eq(boss.base_clear_coins, 140)
	assert_eq(chest.clear_coins, 210)
	assert_eq(chest.payout_coins, 309)
	assert_eq(chest.chest_coins, 280)
	assert_false(chest.total_line.contains("280"))


func test_qa_first_clear_parts_are_five_or_fifteen() -> void:
	var normal := LevelCatalog.load_index(1)
	var second := LevelCatalog.load_index(2)
	var boss := LevelCatalog.load_index(3)
	assert_eq(normal.first_clear_parts, 5)
	assert_eq(second.first_clear_parts, 5)
	assert_eq(boss.first_clear_parts, 15)
	var profile := PlayerProfile.new()
	var first := RewardRules.build(_result(normal, "win", 10, 4, 1.0, 0), profile)
	assert_eq(first.parts, 5)
	RewardRules.apply(profile, first)
	var again := RewardRules.build(_result(normal, "win", 20, 0, 1.0, 0), profile)
	assert_eq(again.parts, 0)
	var mid := RewardRules.build(_result(second, "win", 10, 4, 1.0, 0), profile)
	assert_eq(mid.parts, 5)
	RewardRules.apply(profile, mid)
	var boss_clear := RewardRules.build(_result(boss, "win", 10, 4, 1.0, 0), profile)
	assert_eq(boss_clear.parts, 15)
	assert_false(boss_clear.chest_awarded)
	RewardRules.apply(profile, boss_clear)
	var boss_again := RewardRules.build(_result(boss, "win", 32, 0, 1.0, 0), profile)
	assert_eq(boss_again.parts, 0)


func test_qa_boss_failure_on_level_3_pays_full_thirty_percent() -> void:
	var source := LevelCatalog.load_index(3)
	assert_eq(source.base_clear_coins, 140)
	assert_almost_eq(source.fail_coin_ratio, 0.3, 0.0001)
	var level := source.duplicate(true) as LevelData
	var found := false
	for event in level.events:
		if event.kind == "boss":
			event.distance = 0.0
			found = true
	assert_true(found)
	var clock = autofree(_Clock.new())
	var session := LevelSession.new()
	session.start(level, clock)
	session.tick(0.05)
	assert_ne(session.boss, null)
	assert_almost_eq(session.progress_ratio(), 1.0, 0.001)
	session.sim.squad.count = 0
	session.tick(0.01)
	assert_eq(session.result.outcome, "lose")
	assert_almost_eq(session.result.progress, 1.0, 0.001)
	assert_eq(session.result.base_clear_coins, 140)
	var view := RewardRules.build(session.result, PlayerProfile.new())
	assert_eq(view.fail_coins, 42)
	assert_eq(view.payout_coins, 42)
	assert_eq(view.parts, 0)
	assert_false(view.chest_awarded)
	assert_false(view.show_clear_line)
	var untouched := LevelCatalog.load_index(3)
	var boss_distance := -1.0
	for event in untouched.events:
		if event.kind == "boss":
			boss_distance = event.distance
	assert_almost_eq(boss_distance, 400.0, 0.001)


func test_qa_three_star_chest_is_not_tied_to_first_clear() -> void:
	var level := LevelCatalog.load_index(1)
	var profile := PlayerProfile.new()
	var one := RewardRules.build(_result(level, "win", 10, 4, 1.0, 3), profile)
	assert_eq(one.star_count, 1)
	assert_true(one.grant_first_clear)
	assert_eq(one.parts, 5)
	assert_false(one.chest_awarded)
	assert_eq(one.chest_coins, 0)
	assert_false(one.show_chest_line)
	RewardRules.apply(profile, one)
	assert_true(profile.has_first_clear(1))
	assert_false(profile.has_three_star(1))
	var three := RewardRules.build(_result(level, "win", 20, 1, 1.0, 9), profile)
	assert_eq(three.star_count, 3)
	assert_false(three.grant_first_clear)
	assert_eq(three.parts, 0)
	assert_true(three.chest_awarded)
	assert_eq(three.chest_coins, 200)
	assert_eq(three.chest_parts, 5)
	assert_eq(three.payout_coins, 150 + 9)
	assert_true(three.show_chest_line)
	RewardRules.apply(profile, three)
	assert_true(profile.has_three_star(1))
	assert_eq(profile.parts, 10)
	var replay := RewardRules.build(_result(level, "win", 20, 0, 1.0, 1), profile)
	assert_eq(replay.star_count, 3)
	assert_false(replay.chest_awarded)
	assert_eq(replay.chest_coins, 0)
	assert_false(replay.show_chest_line)
	var coins := profile.coins
	RewardRules.apply(profile, replay)
	assert_eq(profile.coins, coins + replay.payout_coins)
	assert_eq(profile.parts, 10)


func test_qa_attack_costs_for_the_first_five_levels() -> void:
	assert_eq(MetaUpgrade.cost_for_level(1), 50)
	assert_eq(MetaUpgrade.cost_for_level(2), 60)
	assert_eq(MetaUpgrade.cost_for_level(3), 70)
	assert_eq(MetaUpgrade.cost_for_level(4), 90)
	assert_eq(MetaUpgrade.cost_for_level(5), 120)
	var profile := PlayerProfile.new()
	profile.coins = 50 + 60 + 70 + 90 + 120
	var costs: Array[int] = [50, 60, 70, 90, 120]
	for cost in costs:
		assert_eq(MetaUpgrade.next_cost(profile.attack_level), cost)
		assert_true(MetaUpgrade.try_buy(profile))
	assert_eq(profile.attack_level, 5)
	assert_eq(profile.coins, 0)


func test_qa_bad_save_falls_back_without_touching_backup() -> void:
	var path := _scratch("fallback")
	var store := SaveStore.new()
	store.path = path
	var older := PlayerProfile.new()
	older.coins = 15
	older.parts = 3
	assert_true(store.save(older))
	var newer := PlayerProfile.new()
	newer.coins = 40
	assert_true(store.save(newer))
	var bak := FileAccess.get_file_as_string(path + SaveStore.BAK_SUFFIX)
	assert_true(bak.contains("\"coins\": 15"))
	for bad in ["", "   \n", "{", "{\"version\":1,\"coins\":", "null", "[1,2]", "{ this is not json"]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(bad)
		file.close()
		var loaded := store.load_profile()
		assert_eq(loaded.coins, 15)
		assert_eq(loaded.parts, 3)
		assert_eq(FileAccess.get_file_as_string(path + SaveStore.BAK_SUFFIX), bak)
		assert_true(store.save(loaded))
		assert_eq(FileAccess.get_file_as_string(path + SaveStore.BAK_SUFFIX), bak)
		assert_true(FileAccess.get_file_as_string(path).contains("\"coins\": 15"))
	var dir := DirAccess.open("user://")
	dir.remove(path.get_file())
	var from_bak := store.load_profile()
	assert_eq(from_bak.coins, 15)
	assert_eq(FileAccess.get_file_as_string(path + SaveStore.BAK_SUFFIX), bak)
	var junk_main := "{"
	var junk_bak := "trunc"
	var main_file := FileAccess.open(path, FileAccess.WRITE)
	main_file.store_string(junk_main)
	main_file.close()
	var bak_file := FileAccess.open(path + SaveStore.BAK_SUFFIX, FileAccess.WRITE)
	bak_file.store_string(junk_bak)
	bak_file.close()
	var fresh := store.load_profile()
	assert_eq(fresh.coins, 0)
	assert_eq(fresh.unlocked_through, 1)
	assert_eq(FileAccess.get_file_as_string(path), junk_main)
	assert_eq(FileAccess.get_file_as_string(path + SaveStore.BAK_SUFFIX), junk_bak)


func test_qa_old_save_migrates_and_newer_save_is_kept() -> void:
	var path := _scratch("versions")
	var store := SaveStore.new()
	store.path = path
	var old_text := '{"version":0,"gold":40,"weapon_parts":7,"attack":2,"progress":2,"cleared":[true,false,false],"three_star":{"3":true}}'
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(old_text)
	file.close()
	var migrated := store.load_profile()
	assert_eq(migrated.coins, 40)
	assert_eq(migrated.parts, 7)
	assert_eq(migrated.attack_level, 2)
	assert_eq(migrated.unlocked_through, 2)
	assert_true(migrated.has_first_clear(1))
	assert_false(migrated.has_first_clear(2))
	assert_true(migrated.has_three_star(3))
	assert_true(store.save(migrated))
	var written: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_eq(typeof(written), TYPE_DICTIONARY)
	var written_data: Dictionary = written
	assert_eq(int(written_data["version"]), SaveStore.VERSION)
	assert_eq(int(written_data["coins"]), 40)
	assert_eq(int(written_data["parts"]), 7)
	assert_eq(FileAccess.get_file_as_string(path + SaveStore.BAK_SUFFIX), old_text)
	var future := '{"version":99,"coins":8,"extra":{"nested":true},"attack_level":99}'
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(future)
	file.close()
	var bak_now := FileAccess.get_file_as_string(path + SaveStore.BAK_SUFFIX)
	var loaded := store.load_profile()
	assert_eq(loaded.coins, 0)
	assert_eq(loaded.parts, 0)
	assert_eq(loaded.attack_level, 0)
	assert_eq(loaded.unlocked_through, 1)
	loaded.coins = 123
	assert_false(store.save(loaded))
	assert_eq(FileAccess.get_file_as_string(path), future)
	assert_eq(FileAccess.get_file_as_string(path + SaveStore.BAK_SUFFIX), bak_now)
	assert_false(FileAccess.file_exists(path + SaveStore.TMP_SUFFIX))


func test_qa_save_writes_are_atomic_and_ignore_stale_tmp() -> void:
	var path := _scratch("atomic")
	var store := SaveStore.new()
	store.path = path
	var first := PlayerProfile.new()
	first.coins = 11
	first.parts = 2
	assert_true(store.save(first))
	assert_true(FileAccess.file_exists(path))
	assert_false(FileAccess.file_exists(path + SaveStore.TMP_SUFFIX))
	var tmp := FileAccess.open(path + SaveStore.TMP_SUFFIX, FileAccess.WRITE)
	tmp.store_string('{"version":1,"coins":999}')
	tmp.close()
	var loaded := store.load_profile()
	assert_eq(loaded.coins, 11)
	assert_eq(loaded.parts, 2)
	assert_eq(FileAccess.get_file_as_string(path + SaveStore.TMP_SUFFIX), '{"version":1,"coins":999}')
	loaded.coins = 22
	assert_true(store.save(loaded))
	assert_false(FileAccess.file_exists(path + SaveStore.TMP_SUFFIX))
	assert_true(FileAccess.file_exists(path + SaveStore.BAK_SUFFIX))
	var main: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var bak: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + SaveStore.BAK_SUFFIX))
	assert_eq(typeof(main), TYPE_DICTIONARY)
	assert_eq(typeof(bak), TYPE_DICTIONARY)
	var main_data: Dictionary = main
	var bak_data: Dictionary = bak
	assert_eq(int(main_data["coins"]), 22)
	assert_eq(int(main_data["version"]), SaveStore.VERSION)
	assert_eq(int(bak_data["coins"]), 11)
	assert_eq(int(bak_data["parts"]), 2)


func _assert_named_controls(node: Node) -> void:
	if node is Control:
		var control := node as Control
		var named := not str(node.name).is_empty() and not str(node.name).begins_with("@")
		assert_true(named or control.theme_type_variation != StringName())
	for child in node.get_children():
		_assert_named_controls(child)


func _assert_buttons_skip_focus(node: Node) -> void:
	if node is BaseButton:
		assert_eq((node as BaseButton).focus_mode, Control.FOCUS_NONE)
	for child in node.get_children():
		_assert_buttons_skip_focus(child)


func _star_filled(screen: Node, row_name: String) -> bool:
	var icon := screen.get_node("%" + row_name).get_node("Icon") as TextureRect
	if icon.texture == null:
		return false
	return icon.texture.resource_path.ends_with("icon_star_filled.png")
