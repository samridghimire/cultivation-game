class_name TimeSkip
extends RefCounted
## Summaries for long actions that skip time (meditation, work, travel,
## missions). GameState snapshots the player before the action and builds the
## summary after the days pass; the HUD's TimeSkipOverlay only displays it.

## Skips shorter than this many days show no overlay (just the message log).
const MIN_DAYS := 3


## The numbers a summary compares: qi, realm/stage and spirit stones.
static func snapshot(c: CharacterData) -> Dictionary:
	return {
		"qi": c.qi,
		"realm_index": c.realm_index,
		"stage": c.stage,
		"stones": c.item_count("spirit_stone"),
	}


## Whether a skip of `days` gets the overlay. `fast` = the "Fast time skips" setting.
static func should_show(days: int, fast: bool) -> bool:
	return days >= MIN_DAYS and not fast


## Overlay content: {title, days, lines}. `realm_label` is the realm after the
## skip (Cultivation.realm_label); `news` counts log lines posted while time passed.
static func summarize(title: String, days: int, before: Dictionary, after: Dictionary, realm_label: String, news: int) -> Dictionary:
	var lines: PackedStringArray = []
	var rose := int(after["realm_index"]) != int(before["realm_index"]) or int(after["stage"]) != int(before["stage"])
	if rose:
		lines.append("Cultivation rose to %s" % realm_label)
	else:
		var qi := int(float(after["qi"]) - float(before["qi"]))
		if qi > 0:
			lines.append("+%d qi" % qi)
	var stones := int(after["stones"]) - int(before["stones"])
	if stones != 0:
		lines.append("%+d spirit stones" % stones)
	if news > 0:
		lines.append("%d %s in the log" % [news, "piece of news" if news == 1 else "pieces of news"])
	if lines.is_empty():
		lines.append("Nothing of note happened.")
	return {"title": title, "days": days, "lines": lines}
