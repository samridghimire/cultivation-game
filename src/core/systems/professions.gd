class_name Professions
extends RefCounted
## Profession ranks and XP (Alchemist, Blacksmith, Talisman Master, ...).


static func rank_of(c: CharacterData, prof_id: String) -> int:
	return int(c.professions.get(prof_id, {}).get("rank", 0))


static func xp_of(c: CharacterData, prof_id: String) -> float:
	return float(c.professions.get(prof_id, {}).get("xp", 0.0))


static func max_rank(data: GameData) -> int:
	return data.profession_rank_names.size() - 1


static func rank_title(c: CharacterData, data: GameData, prof_id: String) -> String:
	var def: ProfessionDef = data.professions[prof_id]
	return "%s %s" % [data.profession_rank_names[rank_of(c, prof_id)], def.name]


## Adds XP and promotes as many ranks as earned. Returns ranks gained.
static func add_xp(c: CharacterData, data: GameData, prof_id: String, amount: float) -> int:
	var def: ProfessionDef = data.professions[prof_id]
	var rank := rank_of(c, prof_id)
	var xp := xp_of(c, prof_id) + amount
	var gained := 0
	while rank < max_rank(data) and xp >= def.xp_to_next(rank):
		xp -= def.xp_to_next(rank)
		rank += 1
		gained += 1
	if rank >= max_rank(data):
		xp = 0.0
	c.professions[prof_id] = {"rank": rank, "xp": xp}
	return gained


## Works the profession for `days`: earns XP and spirit stones.
## Returns {xp, ranks_gained, income}.
static func work(c: CharacterData, data: GameData, prof_id: String, days: int) -> Dictionary:
	var def: ProfessionDef = data.professions[prof_id]
	var xp := days * c.attribute(def.primary_attribute) / 10.0
	var income := int(def.work_income * (rank_of(c, prof_id) + 1) * days / float(Calendar.DAYS_PER_MONTH))
	var ranks_gained := add_xp(c, data, prof_id, xp)
	c.add_item("spirit_stone", income)
	return {"xp": xp, "ranks_gained": ranks_gained, "income": income}
