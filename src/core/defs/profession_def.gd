class_name ProfessionDef
extends RefCounted
## A craft or job a cultivator can practice (Alchemist, Blacksmith, ...).

var id := ""
var name := ""
var description := ""
var primary_attribute := ""
var xp_base := 100.0
var xp_growth := 1.8
var work_income := 0


static func from_dict(d: Dictionary) -> ProfessionDef:
	var p := ProfessionDef.new()
	p.id = d.get("id", "")
	p.name = d.get("name", p.id)
	p.description = d.get("description", "")
	p.primary_attribute = d.get("primary_attribute", "")
	p.xp_base = float(d.get("xp_base", 100))
	p.xp_growth = float(d.get("xp_growth", 1.8))
	p.work_income = int(d.get("work_income", 0))
	return p


## XP needed to advance from `rank` to `rank + 1`.
func xp_to_next(rank: int) -> float:
	return xp_base * pow(xp_growth, rank)
