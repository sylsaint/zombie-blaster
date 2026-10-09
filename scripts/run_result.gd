class_name RunResult
extends RefCounted
## Payload for the end-of-run event. Star payout and the chest stay on the
## level resource; this only carries what the results screen needs to judge them.


var outcome: String = ""
var level_index: int = 0
var headcount: int = 0
var finale_skill_hits: int = 0
var progress: float = 0.0
var run_coins: int = 0
var base_clear_coins: int = 0
var star2_headcount: int = 0
var first_clear_parts: int = 0
var three_star_chest_coin_multiplier: float = 2.0
var three_star_chest_parts: int = 5
var three_star_chest_paid_separately: bool = true
var fail_coin_ratio: float = 0.30
var star_coin_multipliers := PackedFloat32Array()
