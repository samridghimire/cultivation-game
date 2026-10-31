class_name DayDigest
extends RefCounted
## "While you were away" (DAY-001): folds the many log lines a multi-day action posts into a few short lines.

const MIN_DAYS := 5
const MAX_LINES := 5
## Kinds in priority order; the first whose keyword occurs in the text (or whose category matches) wins.
const KINDS: Array[String] = ["realm", "crop", "visit", "quarrel", "event", "weather"]


static func kind_of(text: String, category: String) -> String:
	var t := text.to_lower()
	if t.contains("breakthrough") or t.contains("reach the") or t.contains("stage") or t.contains("realm"):
		return "realm"
	if t.contains("ready to harvest") or t.contains("ripen"):
		return "crop"
	if t.contains("visit") or t.contains("drops by") or t.contains("celebrat") or t.contains("wedding") or t.contains("birth"):
		return "visit"
	if t.contains("quarrel") or t.contains("argu") or t.contains("feud"):
		return "quarrel"
	if t.contains("festival") or t.contains("begins") or t.contains("event"):
		return "event"
	if t.contains("storm") or t.contains("rain") or t.contains("snow") or t.contains("weather"):
		return "weather"
	return ""


## entries: [{text, category}] posted during the action. Returns at most MAX_LINES lines, most important first.
static func summarize(entries: Array[Dictionary], days: int) -> PackedStringArray:
	var out := PackedStringArray()
	if days < MIN_DAYS or entries.is_empty():
		return out
	var groups: Dictionary = {}
	var rest := 0
	for e in entries:
		var text := String(e.get("text", ""))
		var k := kind_of(text, String(e.get("category", "info")))
		if k == "":
			rest += 1
		else:
			if not groups.has(k):
				groups[k] = []
			(groups[k] as Array).append(text)
	var kinds_present: Array[String] = []
	for k in KINDS:
		if groups.has(k):
			kinds_present.append(k)
	var budget := MAX_LINES - (1 if (rest > 0 or kinds_present.size() > MAX_LINES) else 0)
	for k in kinds_present:
		var texts: Array = groups[k]
		if out.size() >= budget:
			rest += texts.size()
			continue
		if texts.size() == 1:
			out.append(String(texts[0]))
		else:
			out.append("%s ...and %d more like it" % [String(texts[0]), texts.size() - 1])
	if rest > 0:
		out.append("...and %d more in the log" % rest)
	return out
