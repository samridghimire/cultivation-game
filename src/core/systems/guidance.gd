class_name Guidance
extends RefCounted
## "Next steps" hints so a player always knows what to do. Hints are plain
## strings built from existing system queries, most urgent first; no rules
## live here. Shown on the character sheet and as a HUD hint line.

## Years of life left at which the lifespan warning appears.
const LIFESPAN_WARNING_YEARS := 10
## Artifact lives at or below which recharging is suggested.
const LOW_ARTIFACT_LIVES := 1
## Highest realm index (Qi Refining) that still gets newcomer hints.
const NEWCOMER_MAX_REALM := 1
const TECHNIQUE_HINT := "Learn a technique from a manual. Merchants sell them."
const ELDER_MO_FLAG := "talked_elder_mo"
const CHORE_REGION := "qingshi_village"


## Up to `limit` hints for `c`. `density` is the qi density where the player
## stands (region x sect bonus), used for the days-to-next-stage estimate.
## `people` (the NPCs, optional) enables the family hints. `flags` (world flags)
## and `region_id` drive the newcomer hints shown while Mortal or Qi Refining.
static func hints(c: CharacterData, data: GameData, density: float = 1.0, limit: int = 5, people: Dictionary = {}, flags: Dictionary = {}, region_id: String = "") -> PackedStringArray:
	var out: PackedStringArray = []
	var years := Cultivation.years_left(c, data)
	if years <= LIFESPAN_WARNING_YEARS:
		out.append("Only %d %s of life remain. Break through to a higher realm or find a longevity treasure." % [years, "year" if years == 1 else "years"])
	if Injuries.has_any(c):
		out.append("Treat your injuries (%s): they slow your cultivation to x%s. Use a healing item or see a doctor." % [", ".join(Injuries.describe(c, data)), String.num(Injuries.cultivation_multiplier(c, data), 2)])
	if Sects.duty_days_left(c) <= Sects.DUTY_REMINDER_DAYS:
		var duty := Sects.duty_reminder(c, data)
		if duty != "":
			out.append(duty)
	if Children.is_pregnant(c):
		var days := int(c.pregnancy.get("days_left", 0))
		out.append("A child is due in %s." % Calendar.format_duration(days))
	var newcomer := _newcomer_hints(c, data, flags, region_id) if c.realm_index <= NEWCOMER_MAX_REALM else PackedStringArray()
	out.append_array(newcomer)
	out.append(_cultivation_hint(c, data, density))
	if c.artifact_lives >= 0 and c.artifact_lives <= LOW_ARTIFACT_LIVES:
		out.append("Your Creation Artifact holds %d %s. Recharge it for %d spirit stones before you take risks." % [c.artifact_lives, "life" if c.artifact_lives == 1 else "lives", CreationArtifact.recharge_cost(c, data)])
	if c.realm_index > NEWCOMER_MAX_REALM:
		var sect := _sect_hint(c, data)
		if sect != "":
			out.append(sect)
	var missions := _mission_hint(c, data, flags)
	if missions != "":
		out.append(missions)
	if c.professions.is_empty():
		out.append("Work at a workshop to learn a profession and earn spirit stones.")
	if c.techniques.is_empty() and c.realm_index > NEWCOMER_MAX_REALM:
		out.append(TECHNIQUE_HINT)
	for hint in [_dao_hint(c, data), _abode_hint(c, data), _family_hint(c, data, people)]:
		if hint != "":
			out.append(hint)
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
		if Tribulation.has_tribulation(data, c.realm_index + 1):
			text += " Success calls down a Heavenly Tribulation: ready shield talismans"
			text += ", and steel yourself against a heart demon." if Tribulation.faces_heart_demon(c, data) else "."
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
	if Sects.check_promotion(c, data) == "":
		return "The trial for %s is open. Attempt it at a sect hall." % sect.rank_name(rank + 1)
	var need := int(sect.ranks[rank + 1].get("contribution", 0)) - int(c.sect["contribution"])
	return "Earn %d more sect contribution (missions, duties) to become %s." % [maxi(need, 0), sect.rank_name(rank + 1)]


## Members: how many sect missions they can take right now.
static func _mission_hint(c: CharacterData, data: GameData, flags: Dictionary = {}) -> String:
	if c.is_rogue():
		return ""
	var ready := Sects.available_missions(c, data, flags).filter(func(id: String) -> bool: return Sects.check_mission(c, data, id, flags) == "").size()
	if ready == 0:
		return ""
	return "%d sect %s ready on the mission board at a sect hall." % [ready, "mission is" if ready == 1 else "missions are"]


## The first glimpsed Dao insight that can still be deepened.
static func _dao_hint(c: CharacterData, data: GameData) -> String:
	for insight_id in Dao.known_ids(c, data):
		if Dao.check_contemplate(c, data, insight_id) == "":
			return "Contemplate the %s at a meditation spot to deepen it (%s)." % [Dao.def_of(data, insight_id)["name"], Dao.progress_text(c, data, insight_id)]
	return ""


## Seclusion at the player's abode, or claiming one once they cultivate.
static func _abode_hint(c: CharacterData, data: GameData) -> String:
	if c.abode != "":
		var density := float(Abodes.get_def(data, c.abode).get("qi_density", 1.0)) * (1.0 + Abodes.array_bonus(c, data))
		return "Cultivate in seclusion at %s (qi x%s)." % [Abodes.abode_name(data, c.abode), String.num(density, 2)]
	if c.realm_index >= 1 and not data.abodes.is_empty():
		return "Claim a cave abode to cultivate in seclusion and store your treasures."
	return ""


## Trying for a child with a spouse, or courting someone when unmarried.
static func _family_hint(c: CharacterData, data: GameData, people: Dictionary) -> String:
	if people.is_empty() or Children.is_pregnant(c):
		return ""
	var spouses := Family.living_spouses(c, people)
	if spouses.is_empty():
		if c.age_years() >= int(data.family.get("adult_age", 16)):
			return "Win someone's favor with chats and gifts, then court them to start a family."
		return ""
	if not c.children.is_empty():
		return ""
	for spouse_id in spouses:
		var spouse: CharacterData = people[spouse_id]
		if Children.check_conception(c, spouse, data) == "":
			return "You could try for a child with %s at a meditation spot." % spouse.name
	return ""


## First-steps pointers for Mortal and Qi Refining players, most useful first.
static func _newcomer_hints(c: CharacterData, data: GameData, flags: Dictionary, region_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if not flags.get(ELDER_MO_FLAG, false):
		out.append("Ask Elder Mo in Qingshi Village where to begin.")
	if not Cultivation.is_at_bottleneck(c, data):
		for item_id in c.inventory:
			var item: Dictionary = data.items.get(item_id, {})
			var fx: Dictionary = item.get("effects", {})
			# Never steer a newcomer toward pills that burn lifespan or taint the heart.
			var harmful := fx.has("burn_lifespan") or int(fx.get("alignment", 0)) < 0
			if c.item_count(item_id) > 0 and float(fx.get("qi", 0.0)) > 0.0 and not harmful:
				out.append("Use your %s (Inventory, I) to gather qi at once." % item["name"])
				break
	if region_id == CHORE_REGION:
		for deed: Dictionary in data.deeds.values():
			if String(deed["id"]).begins_with("chore_") and not flags.get(String(deed.get("blocked_by_flag", "")), false):
				out.append("Headman Zhou has chores that pay stones and pills.")
				break
	if c.techniques.is_empty():
		out.append(TECHNIQUE_HINT)
	var sect := _sect_hint(c, data)
	if sect != "":
		out.append(sect)
	return out


## Journal entries {section, text, tone} answering "what can I do now?", in
## display order (WU-007 renders them). tone is "normal", "warning" (urgent) or
## "dim" (waiting / on cooldown). `today` is the GameClock day, `events` the live
## world events. Pure: nothing is mutated.
static func journal(c: CharacterData, data: GameData, flags: Dictionary, today: int, region_id: String, density: float = 1.0, people: Dictionary = {}, events: Array = [], clan: ClanData = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hint_lines := hints(c, data, density, 99, people, flags, region_id)
	var urgent := 0
	if Cultivation.years_left(c, data) <= LIFESPAN_WARNING_YEARS:
		urgent += 1
	if Injuries.has_any(c):
		urgent += 1
	if Sects.duty_days_left(c) <= Sects.DUTY_REMINDER_DAYS and Sects.duty_reminder(c, data) != "":
		urgent += 1
	for i in hint_lines.size():
		_add(out, "Next steps", hint_lines[i], "warning" if i < urgent else "normal")
	_breakthrough_entries(out, c, data, density)
	if not c.is_rogue():
		_sect_entries(out, c, data, flags)
	for id: String in c.deed_days:
		var deed: Dictionary = data.deeds.get(id, {})
		var left := Deeds.cooldown_left(c, deed, today)
		if left > 0:
			_add(out, "Deeds", "%s: again in %d days" % [String(deed.get("name", id)), left], "dim")
	for instance in WorldEvents.active_in(events, region_id):
		var event_id := String(instance["id"])
		var def := WorldEvents.def_of(data, event_id)
		var days_left := maxi(0, int(instance["end_day"]) - today)
		_add(out, "World events", "%s here (%d days left)" % [WorldEvents.event_name(data, event_id), days_left], "normal")
		for kind in ["tournament", "defence"]:
			if def.has(kind):
				var reason := WorldEvents.check_join(data, events, c, event_id, kind, region_id)
				_add(out, "World events", "%s: %s" % [kind.capitalize(), "you can enter" if reason == "" else reason], "normal" if reason == "" else "dim")
	_milestone_entries(out, c, data)
	return out


static func _add(out: Array[Dictionary], section: String, text: String, tone: String) -> void:
	out.append({"section": section, "text": text, "tone": tone})


static func _breakthrough_entries(out: Array[Dictionary], c: CharacterData, data: GameData, density: float) -> void:
	var realm: RealmDef = data.realms[c.realm_index]
	var next_label := ""
	if c.stage + 1 < realm.stage_count():
		next_label = realm.stage_label(c.stage + 1)
	elif c.realm_index + 1 < data.realms.size():
		next_label = data.realms[c.realm_index + 1].name
	if next_label != "":
		_add(out, "Breakthrough", "Qi: %s / %s for %s" % [_commas(int(c.qi)), _commas(int(Cultivation.qi_required(c, data))), next_label], "normal")
	if Cultivation.is_at_bottleneck(c, data):
		_add(out, "Breakthrough", "You are at a bottleneck: break through to go further.", "warning")
	else:
		var days := Cultivation.days_to_bottleneck(c, data, density)
		if days > 0:
			_add(out, "Breakthrough", "About %d days of meditation here." % days, "normal")
	var pills: PackedStringArray = []
	for item_id in c.inventory:
		var item: Dictionary = data.items.get(item_id, {})
		if c.item_count(item_id) > 0 and float(item.get("effects", {}).get("breakthrough_bonus", 0.0)) > 0.0:
			pills.append("%s (held %d)" % [String(item["name"]), c.item_count(item_id)])
	pills.sort()
	if not pills.is_empty():
		_add(out, "Breakthrough", "Pills that help: %s" % ", ".join(pills), "normal")


static func _sect_entries(out: Array[Dictionary], c: CharacterData, data: GameData, flags: Dictionary = {}) -> void:
	var duty := Sects.monthly_duty(c, data)
	if duty > 0:
		var days_left := Calendar.DAYS_PER_MONTH - c.age_days % Calendar.DAYS_PER_MONTH
		var unmet := Sects.duty_progress(c) < duty
		_add(out, "Sect", "Monthly duty: %d / %d contribution, %d days left this month." % [Sects.duty_progress(c), duty, days_left], "warning" if unmet and days_left <= 7 else "normal")
	for id in Sects.available_missions(c, data, flags):
		var name := String(data.sect_missions[id].get("name", id))
		var reason := Sects.check_mission(c, data, id, flags)
		if reason == "":
			var danger := Sects.mission_danger(c, data, id)
			var tail := "%d days" % int(data.sect_missions[id].get("days", 1))
			if danger != "":
				tail += ", danger: %s" % danger
			_add(out, "Sect", "Ready: %s (%s)" % [name, tail], "normal")
		elif Sects.mission_cooldown_left(c, id) > 0 and reason.begins_with("This mission is not offered again"):
			_add(out, "Sect", "%s: again in %d days" % [name, Sects.mission_cooldown_left(c, id)], "dim")


static func _milestone_entries(out: Array[Dictionary], c: CharacterData, data: GameData) -> void:
	if data.milestones.is_empty():
		return
	var earned := 0
	var pending: Array[Dictionary] = []
	for def: Dictionary in data.milestones:
		if c.milestones.has(String(def["id"])):
			earned += 1
		else:
			pending.append(def)
	_add(out, "Milestones", "Milestones: %d of %d" % [earned, data.milestones.size()], "normal")
	for def in pending.slice(0, 3):
		_add(out, "Milestones", "%s: %s" % [String(def.get("name", def["id"])), String(def.get("description", ""))], "dim")


static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
