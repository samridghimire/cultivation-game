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
	return add_qi(c, data, qi_per_day(c, data, density) * days)


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


static func is_at_bottleneck(c: CharacterData, data: GameData) -> bool:
	var realm: RealmDef = data.realms[c.realm_index]
	return c.stage == realm.stage_count() - 1 and c.qi >= realm.qi_required(c.stage)


static func can_attempt_breakthrough(c: CharacterData, data: GameData) -> bool:
	return is_at_bottleneck(c, data) and c.realm_index < data.realms.size() - 1


static func breakthrough_chance(c: CharacterData, data: GameData) -> float:
	if c.realm_index >= data.realms.size() - 1:
		return 0.0
	var next: RealmDef = data.realms[c.realm_index + 1]
	var fortune_bonus := (c.attribute("fortune") - 10) * 0.01
	return clampf(next.breakthrough_chance + c.breakthrough_bonus + fortune_bonus + Bloodlines.bonus(c, data, "breakthrough"), 0.01, 0.99)


## Attempts a major breakthrough. Consumes any pending breakthrough bonus.
## A failure may also inflict an injury ("breakthrough_failure" in injuries.json).
## Returns {attempted, success, chance, realm_name, injury} (injury id or "").
static func attempt_breakthrough(c: CharacterData, data: GameData, rng: RandomNumberGenerator) -> Dictionary:
	if not can_attempt_breakthrough(c, data):
		return {"attempted": false, "success": false, "chance": 0.0, "realm_name": "", "injury": ""}
	var chance := breakthrough_chance(c, data)
	var next: RealmDef = data.realms[c.realm_index + 1]
	c.breakthrough_bonus = 0.0
	var success := rng.randf() < chance
	if success:
		c.realm_index += 1
		c.stage = 0
		c.qi = 0.0
	var injury := ""
	if not success:
		c.qi *= 1.0 - next.failure_qi_loss
		injury = Injuries.roll(c, data, "breakthrough_failure", rng)
	return {"attempted": true, "success": success, "chance": chance, "realm_name": next.name, "injury": injury}


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
