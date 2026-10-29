class_name Rivals
extends RefCounted
## The player's named rival (RIV-002): a generated NPC of the player's age with
## a strong root and high diligence, so it climbs the realms faster than most.
## CharacterData.rival holds its id. Encounters with a `rival` condition
## ("any", "stronger", "equal", "weaker": the rival's major realm compared to
## the player's) only happen while the rival lives; their text may use
## {rival} and {rival_realm}. Rules live in data/karma.json "rival".

const RELATIONS: Array[String] = ["any", "stronger", "equal", "weaker"]
const ATTITUDES: Array[String] = ["friendly", "bitter", "proud"]
const FIRST_MEETING_EVENT := "rival_first_meeting"
const FIRST_MEETING_FLAG := "rival_met"
const SEEN_REALM_FLAG := "rival_seen_realm"
const SURPASSED_FLAG := "rival_surpassed"
const SUCCESSOR_DAY_FLAG := "rival_successor_day"  # RIVAL-014: day a new rival names the player
const MEETING_FROM_FLAG := "rival_meeting_from"  # RIVAL-014: first meeting window starts here
const BOUTS_WON_FLAG := "rival_bouts_won"  # RIVAL-016: bouts against the current rival (a successor starts at 0)
const BOUTS_LOST_FLAG := "rival_bouts_lost"
const QUIET_UNTIL_FLAG := "rival_quiet_until"  # RIVAL-021: no rival encounter rolls before this day
const SPUR_CAP := 0.95


static func rules(data: GameData) -> Dictionary:
	return data.karma.get("rival", {})


## Spawns `c`'s rival in `region_id` and remembers it. Returns the rival.
static func spawn(c: CharacterData, people: Dictionary, data: GameData, rng: RandomNumberGenerator, region_id: String) -> CharacterData:
	var r := rules(data)
	var purity: Array = r.get("root_purity", [70, 90])
	var elements: Array = data.root_elements.map(func(e: Dictionary) -> String: return String(e["id"]))
	var element := String(elements[rng.randi_range(0, elements.size() - 1)]) if not elements.is_empty() else "fire"
	var rival := Npcs.spawn(people, data, rng, {
		"age_years": maxi(c.age_years(), 1),
		"roots": {element: rng.randi_range(int(purity[0]), int(purity[1]))},
		"realm": data.realms[c.realm_index].id,
		"stage": c.stage,
		"region": region_id,
		"diligence": float(r.get("diligence", 0.6)),
		"proud": bool(r.get("proud", true)),
	})
	c.rival = rival.id
	return rival


## `c`'s living rival, or null.
static func rival_of(c: CharacterData, people: Dictionary) -> CharacterData:
	if c == null or c.rival == "":
		return null
	var rival: CharacterData = people.get(c.rival)
	return rival if rival != null and rival.alive else null


## True when the rival's first meeting should play now (RIVAL-003): the rival
## lives, the meeting has not played (world flag FIRST_MEETING_FLAG), and
## `today` is inside [first_meeting_day, first_meeting_day + first_meeting_window].
static func first_meeting_due(c: CharacterData, people: Dictionary, data: GameData, flags: Dictionary, today: int) -> bool:
	if rival_of(c, people) == null or flags.get(FIRST_MEETING_FLAG, false):
		return false
	var r := rules(data)
	var start := int(flags.get(MEETING_FROM_FLAG, r.get("first_meeting_day", 10)))
	return today >= start and today <= start + int(r.get("first_meeting_window", 365))



## RIVAL-021: days between rival encounters while exploring; 0 = no cooldown.
static func encounter_cooldown(data: GameData) -> int:
	return int(rules(data).get("encounter_cooldown_days", 60))


## True when the rival may turn up in an encounter roll on day `today` (RIVAL-021).
static func encounter_ready(_data: GameData, flags: Dictionary, today: int) -> bool:
	return today >= int(flags.get(QUIET_UNTIL_FLAG, 0))


## Starts the cooldown after a rival encounter on day `today` (RIVAL-021).
static func note_encounter(data: GameData, flags: Dictionary, today: int) -> void:
	var cooldown := encounter_cooldown(data)
	if cooldown > 0:
		flags[QUIET_UNTIL_FLAG] = today + cooldown


## RIVAL-014: days from word of the rival's death (not by the player's hand) until a successor appears; 0 = never.
static func successor_delay(data: GameData) -> int:
	return int(rules(data).get("successor_delay_days", 180))


## RIVAL-014: true once the successor's day (world flag SUCCESSOR_DAY_FLAG) has come.
static func successor_due(flags: Dictionary, today: int) -> bool:
	return flags.has(SUCCESSOR_DAY_FLAG) and today >= int(flags[SUCCESSOR_DAY_FLAG])


static func successor_line(rival: CharacterData, old_name: String) -> String:
	return "Word spreads of %s, a young cultivator who means to take %s's place as your rival." % [rival.name, old_name]


## RIVAL-005: one line of news when the living `rival` reached a higher realm
## than `last_seen_realm`, else "".
static func news(c: CharacterData, rival: CharacterData, last_seen_realm: int, data: GameData) -> String:
	if rival == null or not rival.alive or rival.realm_index <= last_seen_realm:
		return ""
	return "Word reaches you: your rival %s has broken through to %s." % [rival.name, data.realms[rival.realm_index].name]


## RIVAL-009: how the rival feels about `c`: "bitter" when `c`'s grudge against them reaches
## karma.json rival `bitter_grudge`, else "friendly" when `favor` reaches `friendly_favor`, else "proud".
static func attitude(c: CharacterData, rival: CharacterData, favor: int, data: GameData) -> String:
	var r := rules(data)
	if Karma.grudge(c, rival.id) >= int(r.get("bitter_grudge", 10)):
		return "bitter"
	if favor >= int(r.get("friendly_favor", 20)):
		return "friendly"
	return "proud"


## RIVAL-022: the attitudes an encounter's `rival_attitude` allows (a string or an array of them); [] when ungated.
static func attitudes_of(encounter: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = encounter.get("rival_attitude", [])
	if raw is Array:
		for a: Variant in raw:
			out.append(String(a))
	elif String(raw) != "":
		out.append(String(raw))
	return out


## The journal wording of an `attitude`; "" for the default "proud".
static func attitude_text(attitude: String) -> String:
	match attitude:
		"bitter":
			return "they hold a grudge"
		"friendly":
			return "a friendly rivalry"
	return ""


## RIVAL-013: the line announcing a move from attitude `before` to `after`; "" when nothing changed.
static func attitude_change_line(name: String, before: String, after: String) -> String:
	if before == "" or after == "" or before == after:
		return ""
	if after == "bitter":
		return "%s now holds a grudge against you." % name
	if after == "friendly":
		return "%s warms to you. Your rivalry turns friendly." % name
	if before == "bitter":
		return "%s lets the old grudge go, but still means to beat you." % name
	return "%s cools toward you and is your proud rival again." % name


## RIVAL-011: one line of news for a rival who has died, else "". The player's
## own kill ("slain by ...") already posts its line, so it gives "".
static func death_news(_c: CharacterData, rival: CharacterData) -> String:
	if rival == null or rival.alive or rival.cause_of_death.begins_with("slain by "):
		return ""
	var cause := rival.cause_of_death
	if cause == "old age":
		return "Word reaches you: your rival %s has died of old age." % rival.name
	if cause == "heavenly tribulation":
		return "Word reaches you: your rival %s perished under the Heavenly Tribulation." % rival.name
	if cause.begins_with("fell in battle"):
		return "Word reaches you: your rival %s %s." % [rival.name, cause]
	return "Word reaches you: your rival %s is dead." % rival.name


## True when `c` has reached a higher major realm than a living `rival`
## (RIVAL-006). The same realm never counts, whatever the stage, and neither does a rival who is
## still a mortal: they spawn mortal, so the player's own awakening would "surpass" them on day 15 (QA-078).
static func surpassed(c: CharacterData, rival: CharacterData) -> bool:
	return rival != null and rival.alive and rival.realm_index > 0 and c.realm_index > rival.realm_index


## RIVAL-008: being surpassed spurs the rival: their diligence rises by
## karma.json rival `spurred_diligence`, capped at SPUR_CAP. Returns the new value.
static func spur(rival: CharacterData, data: GameData) -> float:
	rival.diligence = minf(maxf(rival.diligence, 0.0) + float(rules(data).get("spurred_diligence", 0.1)), SPUR_CAP)
	return rival.diligence


## RIVAL-020: true when `c`'s breakthrough from `old_realm_index` brought them level with a living
## rival who stood ahead (the rival's realm is above the old one and now equals `c`'s).
static func caught_up(c: CharacterData, rival: CharacterData, old_realm_index: int) -> bool:
	return rival != null and rival.alive and rival.realm_index > old_realm_index and relation(c, rival) == "equal"


static func caught_up_line(rival: CharacterData) -> String:
	return "You have caught up with %s. A bout between you is a fair fight now." % rival.name


## True when a rival already marked surpassed has climbed past `c` again.
static func overtook(c: CharacterData, rival: CharacterData) -> bool:
	return rival != null and rival.alive and relation(c, rival) == "stronger"


## "stronger", "equal" or "weaker": the rival's major realm against `c`'s.
static func relation(c: CharacterData, rival: CharacterData) -> String:
	if rival.realm_index > c.realm_index:
		return "stronger"
	if rival.realm_index < c.realm_index:
		return "weaker"
	return "equal"


## How `rival` stands against `c` in words: "far ahead of you" (higher major
## realm), "a few steps ahead" (same realm, higher stage), "level with you",
## "behind you" (lower realm, or same realm and lower stage).
static func relation_text(c: CharacterData, rival: CharacterData) -> String:
	if rival.realm_index > c.realm_index:
		return "far ahead of you"
	if rival.realm_index < c.realm_index:
		return "behind you"
	if rival.stage > c.stage:
		return "a few steps ahead"
	if rival.stage < c.stage:
		return "behind you"
	return "level with you"


## "bouts 2 won, 1 lost" against the current rival (RIVAL-016), "" before any bout. The lifetime
## totals are life stats; these world flags restart when a successor rival appears.
static func bout_record_text(flags: Dictionary) -> String:
	var won := int(flags.get(BOUTS_WON_FLAG, 0))
	var lost := int(flags.get(BOUTS_LOST_FLAG, 0))
	if won == 0 and lost == 0:
		return ""
	return "bouts %d won, %d lost" % [won, lost]


## YEAR-010: the year-in-review line on where the rival stands, "" before the first meeting
## (`flags` has no FIRST_MEETING_FLAG) or when there is no living rival.
static func year_line(c: CharacterData, rival: CharacterData, flags: Dictionary) -> String:
	if rival == null or not rival.alive or not flags.get(FIRST_MEETING_FLAG, false):
		return ""
	var line := "%s is %s." % [rival.name, relation_text(c, rival)]
	var record := bout_record_text(flags)
	if record != "":
		line += " Bouts: %s." % record.trim_prefix("bouts ")
	return line


## Whether an encounter's `rival` condition holds (no condition = always).
static func allows(c: CharacterData, rival: CharacterData, condition: String) -> bool:
	if condition == "":
		return true
	if rival == null:
		return false
	return condition == "any" or relation(c, rival) == condition


## Fills {rival} and {rival_realm} in encounter text.
static func fill(text: String, rival: CharacterData, data: GameData) -> String:
	if rival == null or not text.contains("{rival"):
		return text
	return text.replace("{rival_realm}", Cultivation.realm_label(rival, data)).replace("{rival}", rival.name)


## Load errors for the rival rules and encounter rival fields.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r := rules(data)
	if not r.is_empty():
		var purity: Array = r.get("root_purity", [])
		if purity.size() != 2 or int(purity[0]) > int(purity[1]) or int(purity[0]) < 1:
			errors.append("karma.json rival root_purity must be [min, max] with 1 <= min <= max")
		if float(r.get("diligence", 0.0)) <= 0.0 or float(r.get("diligence", 0.0)) > 1.0:
			errors.append("karma.json rival diligence must be in (0, 1]")
	if r.has("spurred_diligence") and (not (r["spurred_diligence"] is int or r["spurred_diligence"] is float) or float(r["spurred_diligence"]) < 0.0 or float(r["spurred_diligence"]) > 1.0):
		errors.append("karma.json rival spurred_diligence must be in 0-1")
	for key: String in ["first_meeting_day", "first_meeting_window"]:
		if r.has(key) and (not (r[key] is int or r[key] is float) or int(r[key]) < 0):
			errors.append("karma.json rival %s must be a whole number >= 0" % key)
	if r.has("friendly_favor") and (not (r["friendly_favor"] is int or r["friendly_favor"] is float) or int(r["friendly_favor"]) < 1 or int(r["friendly_favor"]) > 100):
		errors.append("karma.json rival friendly_favor must be a whole number 1-100")
	if r.has("encounter_cooldown_days") and (not (r["encounter_cooldown_days"] is int or r["encounter_cooldown_days"] is float) or int(r["encounter_cooldown_days"]) < 0):
		errors.append("karma.json rival encounter_cooldown_days must be a whole number >= 0")
	if r.has("successor_delay_days") and (not (r["successor_delay_days"] is int or r["successor_delay_days"] is float) or int(r["successor_delay_days"]) < 0):
		errors.append("karma.json rival successor_delay_days must be a whole number >= 0")
	if r.has("bitter_grudge") and (not (r["bitter_grudge"] is int or r["bitter_grudge"] is float) or int(r["bitter_grudge"]) < 1):
		errors.append("karma.json rival bitter_grudge must be a whole number >= 1")
	for e: Dictionary in data.encounters.values():
		if e.has("rival") and not RELATIONS.has(String(e["rival"])):
			errors.append("Encounter '%s' has unknown rival condition '%s'" % [e["id"], e["rival"]])
		if e.has("rival_attitude"):
			for att: String in attitudes_of(e):
				if not ATTITUDES.has(att):
					errors.append("Encounter '%s' has unknown rival_attitude '%s'" % [e["id"], att])
			if not e.has("rival"):
				errors.append("Encounter '%s' has a rival_attitude but no rival condition" % e["id"])
		var uses_rival := e.has("fight_rival") or e.has("rival_grudge") or e.has("rival_favor") or String(e.get("text", "")).contains("{rival")
		for choice: Dictionary in e.get("choices", []):
			uses_rival = uses_rival or choice.has("fight_rival") or choice.has("rival_grudge") or choice.has("rival_favor") or String(choice.get("text", "")).contains("{rival") or String(choice.get("label", "")).contains("{rival")
			if choice.has("fight_rival") and choice.has("enemy"):
				errors.append("Encounter '%s' choice '%s' cannot fight both an enemy and the rival" % [e["id"], choice.get("label", "")])
		if uses_rival and not e.has("rival"):
			errors.append("Encounter '%s' involves the rival but has no rival condition" % e["id"])
		if e.has("fight_rival") and e.has("enemy"):
			errors.append("Encounter '%s' cannot fight both an enemy and the rival" % e["id"])
	return errors


## GUIDE-037: ", in <region>" when the rival is somewhere other than `region_id`; an empty `region_id` means
## "unknown", so the region is named. "" when the rival's region is unknown or is the player's.
static func where_text(npc: CharacterData, data: GameData, region_id: String) -> String:
	var rival_region := Npcs.region_of(npc, data)
	if rival_region == "" or rival_region == region_id:
		return ""
	return ", in " + Exploration.region_name(data, rival_region)
