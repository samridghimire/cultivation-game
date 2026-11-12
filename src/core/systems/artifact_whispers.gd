class_name ArtifactWhispers
extends RefCounted
## ART-010: the Creation Artifact speaks at a few moments of a life (data/artifact.json "whispers").
## Each moment speaks once per life; `c.artifact_spoke` records which.

const MOMENTS: Array[String] = ["first_breakthrough", "first_respawn", "first_secret_realm", "first_great_beast",
		"first_demonic_act", "first_righteous_deed", "low_lives", "ready_to_unseal"]
const MAX_LENGTH := 140


## One whisper for `moment` (picked with `rng`), or "" if it has none or already spoke this life.
static func speak(c: CharacterData, data: GameData, moment: String, rng: RandomNumberGenerator) -> String:
	if c.artifact_spoke.has(moment):
		return ""
	var lines: Array = (data.artifact.get("whispers", {}) as Dictionary).get(moment, [])
	if lines.is_empty():
		return ""
	c.artifact_spoke[moment] = true
	return String(lines[rng.randi_range(0, lines.size() - 1)])


## Load errors for the optional `whispers` block.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var whispers: Variant = data.artifact.get("whispers", {})
	if not whispers is Dictionary:
		errors.append("artifact.json whispers must be an object")
		return errors
	for moment: String in whispers:
		if not MOMENTS.has(moment):
			errors.append("artifact.json whispers has unknown moment '%s'" % moment)
			continue
		var lines: Variant = whispers[moment]
		if not lines is Array or lines.size() < 1 or lines.size() > 3:
			errors.append("artifact.json whispers '%s' needs 1-3 lines" % moment)
			continue
		for line: Variant in lines:
			if not line is String or String(line) == "" or String(line).length() > MAX_LENGTH:
				errors.append("artifact.json whispers '%s' lines must be text of at most %d characters" % [moment, MAX_LENGTH])
	return errors
