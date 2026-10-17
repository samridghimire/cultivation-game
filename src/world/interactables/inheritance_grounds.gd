extends Interactable
## Inheritance grounds (W-006b, data/inheritances.json): lists each discovered
## inheritance in the current region with its status and, while it can still
## be claimed, "Attempt the <trial>" (GameState.attempt_inheritance) with what
## the trial tests, the danger of a fight trial and the refusal reason.


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var c := GameState.player
	var data := GameState.data
	var today: int = GameClock.total_days
	for id in Inheritances.in_region(data, GameState.current_region):
		var def := Inheritances.inheritance(data, id)
		if today < int(def.get("appears_years", 0)) * Calendar.DAYS_PER_YEAR:
			continue  # undiscovered grounds stay hidden
		options.append({"label": "%s: %s" % [def["name"], Inheritances.status_text(c, data, id, today, GameState.world_flags)], "action": func(): pass, "disabled": true})
		var attempt := attempt_option(c, data, id, today)
		if not attempt.is_empty():
			options.append(attempt)
	if options.is_empty():
		options.append({"label": "Weathered stones and silence. Nothing here calls to you yet.", "action": func(): pass, "disabled": true})
	return options


## "Attempt the <trial> (<test>, <days>)" for an inheritance that can still be
## claimed; {} once it is claimed or lost.
static func attempt_option(c: CharacterData, data: GameData, id: String, today: int) -> Dictionary:
	var def := Inheritances.inheritance(data, id)
	if Inheritances.is_claimed(id, GameState.world_flags) or Inheritances.is_lost(def, today, GameState.world_flags):
		return {}
	var stage := Inheritances.next_stage(c, def)
	if stage.is_empty():
		return {}
	var notes: PackedStringArray = [trial_note(c, data, id), Calendar.format_duration(int(stage.get("days", 1)))]
	var label := "Attempt the %s (%s)" % [Inheritances.stage_title(String(stage.get("name", ""))), ", ".join(notes)]
	var reason := Inheritances.check_attempt(c, data, id, GameState.current_region, today, GameState.world_flags)
	return {"label": label, "action": GameState.attempt_inheritance.bind(id), "disabled": reason != "", "reason": reason, "keep_open": true}


## What the next trial of `id` asks, e.g. "Grave Guardian Ape: Dangerous",
## "needs Constitution 11, yours 9" or "needs Qi Refining, 5th Layer" ("" when no trial is left).
static func trial_note(c: CharacterData, data: GameData, id: String) -> String:
	var stage := Inheritances.next_stage(c, Inheritances.inheritance(data, id))
	return "" if stage.is_empty() else test_text(c, data, stage)


## What a trial tests, for one stage.
static func test_text(c: CharacterData, data: GameData, stage: Dictionary) -> String:
	match String(stage.get("test", "")):
		"fight":
			var enemy := Inheritances.stage_enemy(data, stage)
			return "%s: %s" % [enemy.get("name", "?"), UIStyle.fight_label(c, data, enemy)] if not enemy.is_empty() else "a fight"
		"realm":
			return "needs %s" % Inheritances.realm_requirement(data, stage)
		"attribute":
			var attr := String(stage.get("attribute", ""))
			return "needs %s %d, yours %d" % [Inheritances._attribute_name(data, attr), int(stage.get("min", 0)), c.attribute(attr)]
		"alignment":
			return "a test of the heart"
	return "a trial"
