class_name RewardRules
extends RefCounted
## Star checks and coin lines. The results screen only prints the strings.


static func product_coins(base: int, factor: float) -> int:
	return roundi(float(base) * factor)


static func chest_coins_for(base_clear_coins: int, multiplier: float) -> int:
	return product_coins(base_clear_coins, multiplier)


static func judge(result: RunResult) -> Dictionary:
	var cleared := result.outcome == "win"
	# Each star has its own check. Squad and finale hits do not imply each other.
	var squad := cleared and result.headcount >= result.star2_headcount
	var hits := cleared and result.finale_skill_hits <= 1
	return {
		"clear": cleared,
		"squad": squad,
		"hits": hits,
		"count": int(cleared) + int(squad) + int(hits),
	}


static func multiplier_for(result: RunResult, stars: int) -> float:
	if stars <= 0:
		return 0.0
	var table := result.star_coin_multipliers
	if table.is_empty():
		return [1.0, 1.2, 1.5][clampi(stars, 1, 3) - 1]
	return float(table[mini(stars, table.size()) - 1])


static func build(result: RunResult, profile: PlayerProfile) -> Settlement:
	var stars := judge(result)
	var view := Settlement.new()
	view.won = bool(stars["clear"])
	view.star_clear = view.won
	view.star_squad = bool(stars["squad"])
	view.star_hits = bool(stars["hits"])
	view.star_count = int(stars["count"])
	view.star_multiplier = multiplier_for(result, view.star_count)
	view.headcount = result.headcount
	view.star2_target = result.star2_headcount
	view.finale_skill_hits = result.finale_skill_hits
	view.level_index = result.level_index
	view.base_clear_coins = result.base_clear_coins
	view.run_coins = result.run_coins
	if view.won:
		view.clear_coins = product_coins(result.base_clear_coins, view.star_multiplier)
		view.payout_coins = view.clear_coins + result.run_coins
		view.fail_coins = 0
		view.clear_line = "通关金币  %d × %.1f = %d" % [
			result.base_clear_coins, view.star_multiplier, view.clear_coins
		]
		view.run_line = "局内金币  %d" % result.run_coins
		view.total_line = "合计  %d" % view.payout_coins
		view.show_clear_line = true
		view.show_parts_line = true
	else:
		var progress := clampf(result.progress, 0.0, 1.0)
		view.fail_coins = product_coins(result.base_clear_coins, result.fail_coin_ratio * progress)
		view.payout_coins = view.fail_coins
		view.clear_coins = 0
		var pct := roundi(progress * 100.0)
		view.clear_line = ""
		view.run_line = "进度  %d%%" % pct
		view.total_line = "失败金币  %d" % view.fail_coins
		view.show_clear_line = false
		view.show_parts_line = false
	view.grant_first_clear = view.won and not profile.has_first_clear(result.level_index)
	view.parts = result.first_clear_parts if view.grant_first_clear else 0
	view.parts_line = "首通零件  %d" % view.parts if view.show_parts_line else ""
	# Chest is 2× the level's base clear coins. Run coins stay out of it.
	var chest_base := chest_coins_for(result.base_clear_coins, result.three_star_chest_coin_multiplier)
	view.chest_awarded = view.star_count == 3 and not profile.has_three_star(result.level_index)
	view.show_chest_line = view.chest_awarded
	if view.chest_awarded:
		view.chest_coins = chest_base
		view.chest_parts = result.three_star_chest_parts
		view.chest_line = "三星宝箱  %d 金币 + %d 零件" % [view.chest_coins, view.chest_parts]
	else:
		view.chest_line = ""
	view.can_retry = true
	view.can_back = true
	view.can_next = view.won and result.level_index + 1 <= LevelCatalog.PATHS.size()
	return view


static func apply(profile: PlayerProfile, view: Settlement) -> void:
	if view == null or view.applied:
		return
	view.applied = true
	profile.coins += view.payout_coins
	profile.parts += view.parts
	if view.grant_first_clear:
		profile.mark_first_clear(view.level_index)
	if view.chest_awarded:
		profile.coins += view.chest_coins
		profile.parts += view.chest_parts
		profile.mark_three_star(view.level_index)
	if view.won:
		profile.note_clear(view.level_index)
