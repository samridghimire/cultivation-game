class_name HerbLore
extends RefCounted
## GATHER-001: the gathering skill. Each trip adds xp (CharacterData.gather_xp); the more xp, the likelier
## an extra unit per found stack and the better the odds of the table's rare entries. The numbers live in
## regions.json "herb_lore" (`cfg` below); an empty `cfg` means no herb lore. Pure: randomness comes from `rng`.

const RARE_WEIGHT := 2.0  # a non-empty gather_table entry at or below this weight is "rare"


static func is_rare(entry: Dictionary) -> bool:
	return Fishing.is_rare(entry)


## Appends a message to `errors` for every problem in the regions.json herb_lore block.
static func validate(cfg: Dictionary, errors: Array[String]) -> void:
	if cfg.is_empty():
		return
	var ranks: Array = cfg.get("ranks", [])
	if ranks.is_empty() or int((ranks[0] as Dictionary).get("min", -1)) != 0:
		errors.append("herb_lore.ranks must start at min 0")
	var prev := -1
	for r: Dictionary in ranks:
		if int(r.get("min", -1)) <= prev or String(r.get("name", "")) == "":
			errors.append("herb_lore.ranks need ascending min and a name")
			break
		prev = int(r["min"])
	if int(cfg.get("xp_cap", 0)) <= 0:
		errors.append("herb_lore.xp_cap must be > 0")
	var chance := float(cfg.get("bonus_chance_max", 0.0))
	if chance < 0.0 or chance > 1.0:
		errors.append("herb_lore.bonus_chance_max must be 0..1")
	if float(cfg.get("rare_mult_max", 1.0)) < 1.0:
		errors.append("herb_lore.rare_mult_max must be >= 1")


## Rank title for `xp` ("" without a config).
static func rank_name(cfg: Dictionary, xp: int) -> String:
	var name := ""
	for r: Dictionary in cfg.get("ranks", []):
		if xp >= int(r["min"]):
			name = String(r["name"])
	return name


## "Herb lore: Forager (32/50)" or "(120)" at the top rank.
static func status_line(cfg: Dictionary, xp: int) -> String:
	for r: Dictionary in cfg.get("ranks", []):
		if int(r["min"]) > xp:
			return "Herb lore: %s (%d/%d)" % [rank_name(cfg, xp), xp, int(r["min"])]
	return "Herb lore: %s (%d)" % [rank_name(cfg, xp), xp]


## 0..1: how far `xp` is towards the cap.
static func progress(cfg: Dictionary, xp: int) -> float:
	var cap := int(cfg.get("xp_cap", 0))
	if cap <= 0:
		return 0.0
	return float(mini(maxi(xp, 0), cap)) / cap


## Chance that each found stack comes with one more unit.
static func bonus_chance(cfg: Dictionary, xp: int) -> float:
	return float(cfg.get("bonus_chance_max", 0.0)) * progress(cfg, xp)


## `table` with every rare entry's weight scaled up; unchanged at xp 0.
static func skill_table(cfg: Dictionary, table: Array, xp: int) -> Array:
	if xp <= 0 or cfg.is_empty():
		return table
	var mult := 1.0 + (float(cfg.get("rare_mult_max", 1.0)) - 1.0) * progress(cfg, xp)
	var scaled: Array = []
	for entry: Dictionary in table:
		var e := entry.duplicate()
		if is_rare(e):
			e["weight"] = float(e.get("weight", 1)) * mult
		scaled.append(e)
	return scaled


## Adds one unit to each stack in `found` with `bonus_chance` (one draw per stack, none at xp 0).
## Returns the item ids that got the extra unit.
static func bonus_units(cfg: Dictionary, found: Dictionary, xp: int, rng: RandomNumberGenerator) -> Array[String]:
	var got: Array[String] = []
	if xp <= 0 or cfg.is_empty():
		return got
	var chance := bonus_chance(cfg, xp)
	for item_id: String in found.keys():
		if rng.randf() < chance:
			found[item_id] = int(found[item_id]) + 1
			got.append(item_id)
	return got


## Xp for a trip that found `found` from `table`: 1, or 2 with a rare find.
static func xp_gain(_cfg: Dictionary, table: Array, found: Dictionary) -> int:
	return Fishing.xp_gain(table, found)
