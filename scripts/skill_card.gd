class_name SkillCard
extends Resource
## One in-run card. Effect numbers stay on the resource so tuning does not touch code.


const SPLIT := 0
const PIERCE := 1
const BURST := 2
const RAPID := 3
const POWER := 4
const REINFORCE := 5

@export var effect_id: int = SPLIT
@export var title: String = ""
@export var blurb: String = ""
## Negative max_level means the card can be offered forever.
@export var max_level: int = 3
@export var magnitude: float = 1.0
@export var core: bool = false
@export var spread_degrees: float = 0.0
