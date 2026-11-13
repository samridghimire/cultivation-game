class_name LogFold
extends RefCounted
## LOG-004: folds two back-to-back repeats of the same summary line ("You practice the X for 5 days." twice)
## into one line with the summed span, so a player pressing the same action again reads one row.

const PRACTICE_PREFIX := "You practice the "
const CULTIVATE_PREFIX := "You cultivate for "
const MAX_GAP_DAYS := 1


## The merged line, or "" when `new_text` does not continue `prev_text` (different template/technique, or more than a day apart).
static func fold(prev_text: String, prev_day: int, new_text: String, day: int) -> String:
	if day - prev_day > MAX_GAP_DAYS:
		return ""
	if prev_text.begins_with(PRACTICE_PREFIX) and new_text.begins_with(PRACTICE_PREFIX):
		var a := _split_practice(prev_text)
		var b := _split_practice(new_text)
		if a.is_empty() or b.is_empty() or a[0] != b[0]:
			return ""
		return "%s%s for %s." % [PRACTICE_PREFIX, a[0], Calendar.format_duration(int(a[1]) + int(b[1]))]
	if prev_text.begins_with(CULTIVATE_PREFIX) and new_text.begins_with(CULTIVATE_PREFIX):
		var ca := _split_cultivate(prev_text)
		var cb := _split_cultivate(new_text)
		if ca.is_empty() or cb.is_empty():
			return ""
		# The progress note of the newer line is the current one.
		return "%s%s and gather %d qi (%s)." % [CULTIVATE_PREFIX, Calendar.format_duration(int(ca["days"]) + int(cb["days"])), int(ca["qi"]) + int(cb["qi"]), cb["note"]]
	return ""


## ["<technique>", days] or [] when the line is not a practice summary.
static func _split_practice(text: String) -> Array:
	var rest := text.trim_prefix(PRACTICE_PREFIX).trim_suffix(".")
	var i := rest.rfind(" for ")
	if i < 0:
		return []
	var days := parse_duration(rest.substr(i + 5))
	if days <= 0:
		return []
	return [rest.substr(0, i), days]


static func _split_cultivate(text: String) -> Dictionary:
	var rest := text.trim_prefix(CULTIVATE_PREFIX)
	var i := rest.find(" and gather ")
	var j := rest.find(" qi (")
	if i < 0 or j < 0 or not rest.ends_with(").") or j < i:
		return {}
	var days := parse_duration(rest.substr(0, i))
	if days <= 0:
		return {}
	var qi_text := rest.substr(i + 12, j - i - 12)
	if not qi_text.is_valid_int():
		return {}
	return {"days": days, "qi": int(qi_text), "note": rest.substr(j + 5, rest.length() - j - 7)}


## Inverse of Calendar.format_duration ("5 days", "1 month", "1 month 3 days", ...); 0 when unreadable.
static func parse_duration(text: String) -> int:
	var total := 0
	var words := text.replace(",", " ").replace(" and ", " ").strip_edges().split(" ", false)
	var i := 0
	while i + 1 < words.size():
		if not words[i].is_valid_int():
			return 0
		var n := int(words[i])
		var unit := String(words[i + 1])
		if unit.begins_with("year"):
			total += n * Calendar.DAYS_PER_YEAR
		elif unit.begins_with("month"):
			total += n * Calendar.DAYS_PER_MONTH
		elif unit.begins_with("day"):
			total += n
		else:
			return 0
		i += 2
	return total if i == words.size() else 0
