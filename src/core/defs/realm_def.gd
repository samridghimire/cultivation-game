class_name RealmDef
extends RefCounted
## One major cultivation realm (e.g. Qi Refining) and its minor stages.

var id := ""
var name := ""
var stage_names: PackedStringArray = [""]
var qi_base := 0.0
var qi_growth := 1.0
var base_qi_per_day := 0.0
var lifespan_years := 0
## Chance to break INTO this realm from the previous realm's final stage.
var breakthrough_chance := 1.0
## Fraction of qi lost when a breakthrough into this realm fails.
var failure_qi_loss := 0.0
## Heavenly Tribulation summoned when breaking INTO this realm ({} = none):
## {waves, strength, growth, variance} (see Tribulation).
var tribulation: Dictionary = {}


static func from_dict(d: Dictionary) -> RealmDef:
	var r := RealmDef.new()
	r.id = d.get("id", "")
	r.name = d.get("name", r.id)
	r.stage_names = PackedStringArray(d.get("stage_names", [""]))
	r.qi_base = float(d.get("qi_base", 0))
	r.qi_growth = float(d.get("qi_growth", 1))
	r.base_qi_per_day = float(d.get("base_qi_per_day", 0))
	r.lifespan_years = int(d.get("lifespan_years", 0))
	r.breakthrough_chance = float(d.get("breakthrough_chance", 1))
	r.failure_qi_loss = float(d.get("failure_qi_loss", 0))
	r.tribulation = d.get("tribulation", {})
	return r


func stage_count() -> int:
	return stage_names.size()


func qi_required(stage: int) -> float:
	return qi_base * pow(qi_growth, stage)


func stage_label(stage: int) -> String:
	if stage < 0 or stage >= stage_count() or stage_names[stage] == "":
		return name
	return "%s, %s" % [name, stage_names[stage]]
