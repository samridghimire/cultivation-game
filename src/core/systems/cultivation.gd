class_name Cultivation
extends RefCounted
## Pure cultivation rules: qi gathering, minor stage advancement, and major
## realm breakthroughs. No nodes or signals; GameState calls these and emits events.


## Qi gathered per day. `density` is the spiritual energy of the location
## multiplied by any sect bonus (1.0 = an ordinary mortal village). Known
## cultivation techniques multiply it further; injuries slow it.
static func qi_per_day(c: CharacterData, data: GameData, density: float = 1.0) -> float:
	var realm: RealmDef = data.realms[c.realm_index]
	var comprehension_mult := 0.5 + c.attribute("comprehension") / 20.0
	return realm.base_qi_per_day * SpiritualRoots.cultivation_multiplier(c.spiritual_roots, data) * comprehension_mult * density * Techniques.cultivation_multiplier(c, data) * Injuries.cultivation_multiplier(c, data) * (1.0 + Bloodlines.bonus(c, data, "qi_mult"))


## Cultivate for `days`. Returns {qi_gained, stages_gained, at_bottleneck}.
static func cultivate(c: CharacterData, data: GameData, days: int, density: float = 1.0) -> Dictionary:
	var result := add_qi(c, data, qi_per_day(c, data, density) * days)
	LifeStats.add(c, "qi_gathered", int(result["qi_gained"]))
	return result


## What cultivating `days` at `density` would do, without changing `c`:
## {days (capped at the bottleneck), qi_gain, stages_gained, realm_label (after),
## stops_at_bottleneck, qi_per_day}. days and qi_gain are 0 at the bottleneck or with no qi gathered.
static func preview(c: CharacterData, data: GameData, days: int, density: float = 1.0) -> Dictionary:
	var copy := CharacterData.from_dict(c.to_dict())
	var per_day := qi_per_day(copy, data, density)
	var out := {"days": 0, "qi_gain": 0, "stages_gained": 0, "realm_label": realm_label(copy, data), "stops_at_bottleneck": false, "qi_per_day": per_day}
	if per_day <= 0.0 or is_at_bottleneck(copy, data):
		return out
	var needed := days_to_bottleneck(copy, data, density)
	var capped := needed > 0 and needed < days
	if capped:
		days = needed
	var result := add_qi(copy, data, per_day * days)
	out["days"] = days
	out["qi_gain"] = int(result["qi_gained"])
	out["stages_gained"] = result["stages_gained"]
	out["realm_label"] = realm_label(copy, data)
	out["stops_at_bottleneck"] = capped or bool(result["at_bottleneck"])
	return out


## Adds qi, advancing minor stages automatically. Qi stops accumulating at the
## final stage of a realm (the bottleneck) until a breakthrough succeeds.
static func add_qi(c: CharacterData, data: GameData, amount: float) -> Dictionary:
	var start_qi := c.qi
	var stages_gained := 0
	var absorbed := 0.0
	c.qi += amount
	while true:
		var realm: RealmDef = data.realms[c.realm_index]
		var needed := realm.qi_required(c.stage)
		if c.qi < needed:
			break
		if c.stage < realm.stage_count() - 1:
			c.qi -= needed
			absorbed += needed
			c.stage += 1
			stages_gained += 1
		else:
			c.qi = needed
			break
	return {
		"qi_gained": absorbed + c.qi - start_qi,
		"stages_gained": stages_gained,
		"at_bottleneck": is_at_bottleneck(c, data),
	}


## Days of cultivation at `density` needed to fill qi up to the bottleneck of the
## current realm (rounded up). 0 if already there; -1 if no qi is gathered.
static func days_to_bottleneck(c: CharacterData, data: GameData, density: float = 1.0) -> int:
	if is_at_bottleneck(c, data):
		return 0
	var per_day := qi_per_day(c, data, density)
	if per_day <= 0.0:
		return -1
	var realm: RealmDef = data.realms[c.realm_index]
	var remaining := realm.qi_required(c.stage) - c.qi
	for stage in range(c.stage + 1, realm.stage_count()):
		remaining += realm.qi_required(stage)
	return maxi(1, ceili(remaining / per_day - 0.000001))


## Days of meditation at `density` until the next stage (or the realm's bottleneck
## when the next step is the breakthrough). -1 at the bottleneck or with no qi gathered.
static func days_to_next_stage(c: CharacterData, data: GameData, density: float = 1.0) -> int:
	if is_at_bottleneck(c, data):
		return -1
	var per_day := qi_per_day(c, data, density)
	if per_day <= 0.0:
		return -1
	var remaining := data.realms[c.realm_index].qi_required(c.stage) - c.qi
	return maxi(1, ceili(remaining / per_day - 0.000001))


## "450/900 qi to the 2nd Layer", or the breakthrough state at the bottleneck.
static func progress_text(c: CharacterData, data: GameData) -> String:
	var realm: RealmDef = data.realms[c.realm_index]
	if is_at_bottleneck(c, data):
		if is_final_realm(c, data):
			return "at the peak of the path"
		return "ready to break through to %s" % data.realms[c.realm_index + 1].name
	var goal := "the bottleneck"
	if c.stage + 1 < realm.stage_count():
		goal = "the %s" % realm.stage_names[c.stage + 1] if realm.stage_names[c.stage + 1] != "" else "the next stage"
	return "%d/%d qi to %s" % [int(c.qi), ceili(realm.qi_required(c.stage)), goal]


static func is_at_bottleneck(c: CharacterData, data: GameData) -> bool:
	var realm: RealmDef = data.realms[c.realm_index]
	return c.stage == realm.stage_count() - 1 and c.qi >= realm.qi_required(c.stage)


static func can_attempt_breakthrough(c: CharacterData, data: GameData) -> bool:
	return is_at_bottleneck(c, data) and c.realm_index < data.realms.size() - 1


static func breakthrough_chance(c: CharacterData, data: GameData) -> float:
	var total := 0.0
	for term in chance_breakdown(c, data):
		total += float(term["value"])
	return clampf(total, 0.01, 0.99) if not is_final_realm(c, data) else 0.0


## The terms of breakthrough_chance(), largest first, zero terms left out:
## [{label: String, value: float}], e.g. [{"Base (Foundation Establishment)", 0.30},
## {"Foundation Establishment Pill", 0.25}, {"Fortune 14", 0.04}]. Base is always
## present. Values sum (before the clamp) to the unclamped chance. [] in the final realm.
static func chance_breakdown(c: CharacterData, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if is_final_realm(c, data):
		return out
	var next: RealmDef = data.realms[c.realm_index + 1]
	out.append({"label": "Base (%s)" % next.name, "value": next.breakthrough_chance})
	var terms: Array[Dictionary] = [
		{"label": _pill_label(c, data), "value": c.breakthrough_bonus},
		{"label": "Fortune %d" % c.attribute("fortune"), "value": (c.attribute("fortune") - 10) * 0.01},
		{"label": "Dao insights", "value": Dao.breakthrough_bonus(c, data)},
		{"label": "Bloodline", "value": Bloodlines.bonus(c, data, "breakthrough")},
	]
	for term in terms:
		if not is_zero_approx(float(term["value"])):
			out.append(term)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["value"])) > absf(float(b["value"])))
	return out


static func is_final_realm(c: CharacterData, data: GameData) -> bool:
	return c.realm_index >= data.realms.size() - 1


## "<Realm> Pill" style name when the pending bonus came from a realm pill, else a generic one.
static func _pill_label(c: CharacterData, data: GameData) -> String:
	if c.breakthrough_pill != "":
		for item: Dictionary in data.items.values():
			if String(item.get("effects", {}).get("breakthrough_realm", "")) == c.breakthrough_pill:
				return String(item["name"])
	return "Pills and herbs taken"


## Attempts a major breakthrough. Consumes any pending breakthrough bonus.
## A failure may also inflict an injury ("breakthrough_failure" in injuries.json).
## A successful roll into a realm with a tribulation must then survive it
## (Tribulation.endure); falling fails the breakthrough, and falling to the
## final wave kills (died = true; the caller handles death).
## Returns {attempted, success, chance, realm_name, injury, tribulation, died}
## (injury id or ""; tribulation is Tribulation.endure's result or {}).
## `npc`: NPCs face the tribulation's npc_strength (Tribulation.waves).
static func attempt_breakthrough(c: CharacterData, data: GameData, rng: RandomNumberGenerator, npc: bool = false) -> Dictionary:
	if not can_attempt_breakthrough(c, data):
		return {"attempted": false, "success": false, "chance": 0.0, "realm_name": "", "injury": "", "tribulation": {}, "died": false}
	var chance := breakthrough_chance(c, data)
	var next: RealmDef = data.realms[c.realm_index + 1]
	c.breakthrough_bonus = 0.0
	c.breakthrough_pill = ""
	var success := rng.randf() < chance
	var injury := ""
	var trib := {}
	if success and Tribulation.has_tribulation(data, c.realm_index + 1):
		trib = Tribulation.endure(c, data, c.realm_index + 1, rng, npc)
		success = trib["survived"]
		injury = trib["injury"]
	if success:
		c.realm_index += 1
		c.stage = 0
		c.qi = 0.0
	else:
		c.qi *= 1.0 - next.failure_qi_loss
		if trib.is_empty():
			injury = Injuries.roll(c, data, "breakthrough_failure", rng)
	return {"attempted": true, "success": success, "chance": chance, "realm_name": next.name, "injury": injury, "tribulation": trib, "died": bool(trib.get("died", false))}


## Total lifespan: the realm's, adjusted by Constitution, plus years gained from
## longevity treasures, minus years burned for power.
static func lifespan_years(c: CharacterData, data: GameData) -> int:
	var realm: RealmDef = data.realms[c.realm_index]
	return realm.lifespan_years + (c.attribute("constitution") - 10) + c.lifespan_bonus_years - c.lifespan_spent_years


## Whole years left before death by old age (never negative).
static func years_left(c: CharacterData, data: GameData) -> int:
	return maxi(lifespan_years(c, data) - c.age_years(), 0)


## Burns `years` of lifespan. Returns false (and burns nothing) for a non-positive amount.
static func burn_lifespan(c: CharacterData, years: int) -> bool:
	if years <= 0:
		return false
	c.lifespan_spent_years += years
	return true


## Adds `years` of lifespan. Returns false (and adds nothing) for a non-positive amount.
static func extend_lifespan(c: CharacterData, years: int) -> bool:
	if years <= 0:
		return false
	c.lifespan_bonus_years += years
	return true


static func realm_label(c: CharacterData, data: GameData) -> String:
	return data.realms[c.realm_index].stage_label(c.stage)


static func qi_required(c: CharacterData, data: GameData) -> float:
	return data.realms[c.realm_index].qi_required(c.stage)


## Expected years to fill every stage of a realm and then break into the next one
## at a cultivation speed of `qi_mult` x the realm's base rate. Failed attempts
## (at the realm's base breakthrough chance) each cost failure_qi_loss of the
## final stage's qi to refill. Ignores injuries, fortune and pills. Used to check
## realm balance: lifespan gained per realm must outpace this (data/realms.json _doc).
static func expected_realm_years(data: GameData, realm_index: int, qi_mult: float = 1.0) -> float:
	var realm: RealmDef = data.realms[realm_index]
	var qi := 0.0
	for stage in realm.stage_count():
		qi += realm.qi_required(stage)
	if realm_index < data.realms.size() - 1:
		var next: RealmDef = data.realms[realm_index + 1]
		var chance := maxf(next.breakthrough_chance, 0.01)
		var expected_failures := (1.0 - chance) / chance
		qi += expected_failures * realm.qi_required(realm.stage_count() - 1) * next.failure_qi_loss
	return qi / (realm.base_qi_per_day * maxf(qi_mult, 0.0001)) / Calendar.DAYS_PER_YEAR
