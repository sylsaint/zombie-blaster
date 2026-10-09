class_name Settlement
extends RefCounted
## One run's payout. Chest coins stay off payout_coins so the results
## screen can print them on their own line.


var won: bool = false
var star_clear: bool = false
var star_squad: bool = false
var star_hits: bool = false
var star_count: int = 0
var star_multiplier: float = 0.0
var headcount: int = 0
var star2_target: int = 0
var finale_skill_hits: int = 0
var level_index: int = 0
var base_clear_coins: int = 0
var run_coins: int = 0
var clear_coins: int = 0
var fail_coins: int = 0
## Normal settlement only. The chest is added beside this, not inside it.
var payout_coins: int = 0
var parts: int = 0
var grant_first_clear: bool = false
var chest_awarded: bool = false
var chest_coins: int = 0
var chest_parts: int = 0
var can_retry: bool = true
var can_next: bool = false
var can_back: bool = true
var clear_line: String = ""
var run_line: String = ""
var total_line: String = ""
var parts_line: String = ""
var chest_line: String = ""
var applied: bool = false
