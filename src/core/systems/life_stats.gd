class_name LifeStats
extends RefCounted
## Life record (STAT-001): a per-character tally of what the player has done,
## kept in CharacterData.life_stats (key -> int) for the character sheet and
## the end-of-life summary.

const KEYS: Array[String] = ["fights_won", "fights_lost", "threats_fled", "breakthroughs", "breakthroughs_failed",
	"tribulations_survived", "respawns", "items_crafted", "missions_done", "deeds_done", "encounters", "days_in_seclusion"]

const LABELS := {
	"fights_won": "Fights won",
	"fights_lost": "Fights lost",
	"threats_fled": "Threats fled",
	"breakthroughs": "Breakthroughs",
	"breakthroughs_failed": "Breakthroughs failed",
	"tribulations_survived": "Tribulations survived",
	"respawns": "Times pulled back by the artifact",
	"items_crafted": "Items crafted",
	"missions_done": "Sect missions done",
	"deeds_done": "Deeds done",
	"encounters": "Encounters",
	"days_in_seclusion": "Days in seclusion",
}


static func add(c: CharacterData, key: String, amount: int = 1) -> void:
	if not KEYS.has(key):
		push_error("Unknown life stat '%s'" % key)
		return
	if amount <= 0:
		return
	c.life_stats[key] = get_stat(c, key) + amount


static func get_stat(c: CharacterData, key: String) -> int:
	return int(c.life_stats.get(key, 0))


## "Fights won: 12" for every non-zero stat, in KEYS order.
static func lines(c: CharacterData) -> PackedStringArray:
	var result := PackedStringArray()
	for key in KEYS:
		var n := get_stat(c, key)
		if n > 0:
			result.append("%s: %d" % [LABELS[key], n])
	return result
