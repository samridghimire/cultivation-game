class_name TechniqueDef
extends RefCounted
## A cultivation method, combat art or body-tempering technique. Bonuses are
## per mastery level and summed over every technique a character knows.

const BONUS_KEYS: PackedStringArray = ["qi_mult", "attack", "defense", "max_hp", "speed"]

var id := ""
var name := ""
var description := ""
## "cultivation", "combat", "body" or "method" (a main cultivation method, see
## Techniques.main_method: only one is active at a time).
var kind := ""
## Element id, or "" for techniques any root can use at full strength.
var element := ""
var min_realm := "mortal"
var max_level := 10
## Bonus key -> value gained per mastery level.
var bonuses: Dictionary = {}
## Item id of the manual that teaches this technique ("" = none).
var manual_item := ""
var xp_base := 60.0
var xp_growth := 1.5
## Optional activation (forbidden secret arts): {"lifespan_cost": int years,
## "days": int, "buff": {stat: fraction}}. Empty = cannot be activated.
var activation: Dictionary = {}
## Methods only: multiplier on qi gathered while this is the main method (1.0 = no change).
var qi_rate := 1.0
## Methods only: highest realm id the method can carry you through ("" = no cap).
var max_realm := ""


static func from_dict(d: Dictionary) -> TechniqueDef:
	var t := TechniqueDef.new()
	t.id = d.get("id", "")
	t.name = d.get("name", t.id)
	t.description = d.get("description", "")
	t.kind = d.get("kind", "combat")
	t.element = d.get("element", "")
	t.min_realm = d.get("min_realm", "mortal")
	t.max_level = int(d.get("max_level", 10))
	for key in d.get("bonuses", {}):
		t.bonuses[key] = float(d["bonuses"][key])
	t.manual_item = d.get("manual_item", "")
	t.xp_base = float(d.get("xp_base", 60))
	t.xp_growth = float(d.get("xp_growth", 1.5))
	t.activation = d.get("activation", {})
	t.qi_rate = float(d.get("qi_rate", 1.0))
	t.max_realm = d.get("max_realm", "")
	return t


func is_method() -> bool:
	return kind == "method"


## Practice xp needed to advance from `level` to `level + 1`.
func xp_to_next(level: int) -> float:
	return xp_base * pow(xp_growth, level - 1)
