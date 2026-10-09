class_name XpTrack
extends RefCounted
## Kill XP and queued card offers. Elite kills queue an offer without adding XP.
## The k-th XP rank costs 10 + 8 * (k - 1). Elite offers do not advance that curve.


var xp: int = 0
var xp_ranks: int = 0
var pending: int = 0
var offers_opened: int = 0


static func requirement_for(k: int) -> int:
	return 10 + 8 * (maxi(k, 1) - 1)


func next_requirement() -> int:
	return requirement_for(xp_ranks + 1)


## Returns how many new XP offers were queued.
func add(amount: int) -> int:
	if amount <= 0:
		return 0
	xp += amount
	var gained := 0
	var guard := 0
	while guard < 64:
		var need := requirement_for(xp_ranks + 1)
		if xp < need:
			break
		xp -= need
		xp_ranks += 1
		pending += 1
		gained += 1
		guard += 1
	return gained


func grant_offer() -> void:
	pending += 1


func take_offer() -> void:
	if pending > 0:
		pending -= 1
