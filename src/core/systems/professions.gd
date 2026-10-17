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
	if gained > 0:
		LifeStats.add(c, "profession_ranks", gained)
	return gained


## What `days` of work would pay: {xp, income}. `work` applies exactly this.
static func work_preview(c: CharacterData, data: GameData, prof_id: String, days: int) -> Dictionary:
	var def: ProfessionDef = data.professions[prof_id]
	var xp := days * c.attribute(def.primary_attribute) / 10.0
	var income := int(def.work_income * (rank_of(c, prof_id) + 1) * days / float(Calendar.DAYS_PER_MONTH))
	return {"xp": xp, "income": income}


## Works the profession for `days`: earns XP and spirit stones.
## Returns {xp, ranks_gained, income}.
static func work(c: CharacterData, data: GameData, prof_id: String, days: int) -> Dictionary:
	var preview := work_preview(c, data, prof_id, days)
	var xp: float = preview["xp"]
	var income: int = preview["income"]
	var ranks_gained := add_xp(c, data, prof_id, xp)
	c.add_item("spirit_stone", income)
	LifeStats.record_stones(c, income)
	LifeStats.add(c, "profession_stones", income)
	return {"xp": xp, "ranks_gained": ranks_gained, "income": income}


## The first recipe id (data order) of `prof_id` that `c` does not know with
## min_rank <= rank + 1, lowest min_rank first; "" if none (PROF-008).
static func next_unknown_recipe(c: CharacterData, data: GameData, prof_id: String) -> String:
	var limit := rank_of(c, prof_id) + 1
	var best := ""
	var best_rank := 1 << 30
	for recipe: Dictionary in data.recipes.values():
		if String(recipe.get("profession", "")) != prof_id or Alchemy.knows(c, data, recipe["id"]):
			continue
		var mr := int(recipe.get("min_rank", 0))
		if mr <= limit and mr < best_rank:
			best = recipe["id"]
			best_rank = mr
	return best


## What the rank just reached opens, for the rank-up message; "" if nothing to say. `from_rank` is
## the rank before the jump: recipes with from_rank < min_rank <= rank are named (-1: only the new rank's).
static func rank_up_line(c: CharacterData, data: GameData, prof_id: String, from_rank: int = -1) -> String:
	var r := rank_of(c, prof_id)
	var names: PackedStringArray = []
	for id: String in Alchemy.known_recipes(c, data, prof_id):
		var mr := int(data.recipes[id].get("min_rank", 0))
		if (mr == r) if from_rank < 0 else (mr > from_rank and mr <= r):
			names.append(String(data.recipes[id].get("name", id)))
	if not names.is_empty():
		if names.size() == 1:
			return "You can now refine %s." % names[0]
		if names.size() == 2:
			return "You can now refine %s and %s." % [names[0], names[1]]
		return "You can now refine %s, %s and %d more." % [names[0], names[1], names.size() - 2]
	var next_id := next_unknown_recipe(c, data, prof_id)
	if next_id == "" or int(data.recipes[next_id].get("min_rank", 0)) > r:
		return ""
	var line := "%s is now within your skill; find its recipe scroll." % data.recipes[next_id].get("name", next_id)
	var scroll_id := data.scroll_for_recipe(next_id)
	if scroll_id != "":
		var item: Dictionary = data.items[scroll_id]
		for rid: String in data.regions:
			for p: Dictionary in data.regions[rid].get("places", []):
				if String(p.get("type", "")) == "merchant" and Items.merchant_sells(data, item, p.get("stock_tags", []), int(p.get("max_price", 0))):
					return line + " Scrolls are sold by merchants."
	return line
