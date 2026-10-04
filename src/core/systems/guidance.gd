class_name Guidance
extends RefCounted
## "Next steps" hints so a player always knows what to do. Hints are plain
## strings built from existing system queries, most urgent first; no rules
## live here. Shown on the character sheet and as a HUD hint line.

## Years of life left at which the lifespan warning appears.
const LIFESPAN_WARNING_YEARS := 10
## Artifact lives at or below which recharging is suggested.
const LOW_ARTIFACT_LIVES := 1


## Up to `limit` hints for `c`. `density` is the qi density where the player
## stands (region x sect bonus), used for the days-to-next-stage estimate.
static func hints(c: CharacterData, data: GameData, density: float = 1.0, limit: int = 5) -> PackedStringArray:
	var out: PackedStringArray = []
	var years := Cultivation.years_left(c, data)
	if years <= LIFESPAN_WARNING_YEARS:
		out.append("Only %d %s of life remain. Break through to a higher realm or find a longevity treasure." % [years, "year" if years == 1 else "years"])
	if Injuries.has_any(c):
		out.append("Treat your injuries (%s): they slow your cultivation to x%s. Use a healing item or see a doctor." % [", ".join(Injuries.describe(c, data)), String.num(Injuries.cultivation_multiplier(c, data), 2)])
	if Children.is_pregnant(c):
		var days := int(c.pregnancy.get("days_left", 0))
		out.append("A child is due in %s." % Calendar.format_duration(days))
	out.append(_cultivation_hint(c, data, density))
	if c.artifact_lives >= 0 and c.artifact_lives <= LOW_ARTIFACT_LIVES:
		out.append("Your Creation Artifact holds %d %s. Recharge it for %d spirit stones before you take risks." % [c.artifact_lives, "life" if c.artifact_lives == 1 else "lives", CreationArtifact.recharge_cost(c, data)])
	var sect := _sect_hint(c, data)
	if sect != "":
		out.append(sect)
	if c.professions.is_empty():
		out.append("Work at a workshop to learn a profession and earn spirit stones.")
	if c.techniques.is_empty():
		out.append("Learn a technique from a manual. Merchants sell them.")
	if out.size() > limit:
		out.resize(limit)
	return out


## Breakthrough odds (and pills that help) at a bottleneck, else qi and days to the next stage.
static func _cultivation_hint(c: CharacterData, data: GameData, density: float) -> String:
	if Cultivation.can_attempt_breakthrough(c, data):
		var next: RealmDef = data.realms[c.realm_index + 1]
		var text := "You are ready to break through to %s (%d%% chance). Attempt it at a meditation spot." % [next.name, roundi(Cultivation.breakthrough_chance(c, data) * 100)]
		var pills := breakthrough_items(c, data)
		if not pills.is_empty():
			text += " Using %s first raises the odds." % ", ".join(pills)
		elif c.breakthrough_bonus <= 0.0:
			text += " Breakthrough pills raise the odds."
		return text
	if Cultivation.is_at_bottleneck(c, data):
		return "You stand at the peak of the highest realm known."
	var needed := maxf(Cultivation.qi_required(c, data) - c.qi, 0.0)
	var rate := Cultivation.qi_per_day(c, data, density)
	var eta := " (about %s of meditation here)" % Calendar.format_duration(ceili(needed / rate)) if rate > 0.0 else ""
	return "Gather %d more qi to reach the next stage%s." % [ceili(needed), eta]


## Names of held items whose effects add a breakthrough bonus.
static func breakthrough_items(c: CharacterData, data: GameData) -> PackedStringArray:
	var names: PackedStringArray = []
	for item_id in c.inventory:
		var item: Dictionary = data.items.get(item_id, {})
		if c.item_count(item_id) > 0 and float(item.get("effects", {}).get("breakthrough_bonus", 0.0)) > 0.0:
			names.append(String(item["name"]))
	names.sort()
	return names


## Rogues: which sects would take them. Members: contribution to the next rank.
static func _sect_hint(c: CharacterData, data: GameData) -> String:
	if c.is_rogue():
		var open: PackedStringArray = []
		for sect: SectDef in data.sects.values():
			if Sects.check_join(c, data, sect.id)["ok"]:
				open.append(sect.name)
		if open.is_empty():
			return ""
		return "As a rogue cultivator you could join %s at a sect hall." % " or ".join(open)
	var sect: SectDef = data.sects[c.sect["id"]]
	var rank := int(c.sect["rank"])
	if rank + 1 >= sect.ranks.size():
		return ""
	var need := int(sect.ranks[rank + 1].get("contribution", 0)) - int(c.sect["contribution"])
	return "Earn %d more sect contribution (missions, duties) to become %s." % [maxi(need, 0), sect.rank_name(rank + 1)]
