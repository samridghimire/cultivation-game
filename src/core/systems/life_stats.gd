class_name LifeStats
extends RefCounted
## Life record (STAT-001): a per-character tally of what the player has done,
## kept in CharacterData.life_stats (key -> int) for the character sheet and
## the end-of-life summary.

const KEYS: Array[String] = ["fights_won", "fights_lost", "threats_fled", "breakthroughs", "breakthroughs_failed",
	"tribulations_survived", "respawns", "items_crafted", "missions_done", "deeds_done", "encounters", "days_in_seclusion", "commissions_done", "tournaments_won", "incursions_repelled", "realm_floors_cleared", "inheritances_claimed"]

const LABELS := {
	"fights_won": "Fights won",
	"fights_lost": "Fights lost",
	"threats_fled": "Threats fled",
	"breakthroughs": "Breakthroughs",
	"breakthroughs_failed": "Breakthroughs failed",
	"tribulations_survived": "Tribulations survived",
	"respawns": "Times pulled back by the artifact",
	"items_crafted": "Items crafted",
	"commissions_done": "Commissions filled",
	"missions_done": "Sect missions done",
	"tournaments_won": "Tournaments won",
	"incursions_repelled": "Incursions repelled",
	"realm_floors_cleared": "Secret realm floors cleared",
	"inheritances_claimed": "Inheritances claimed",
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


## Epilogue for the final-death screen (EPI-001): who they were, then up to
## `max_stats` of their life-record lines.
static func epilogue(c: CharacterData, data: GameData, clan: ClanData = null, max_stats: int = 8) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("%s, fallen at age %d" % [c.name, c.age_years()])
	out.append("Realm: %s" % Cultivation.realm_label(c, data))
	out.append("Path: %s" % Alignment.tier_name(c.alignment, data))
	out.append("A rogue cultivator" if c.is_rogue() else "Sect: %s" % Sects.describe(c, data))
	if clan != null and clan.name != "":
		out.append("Clan: %s, %d members" % [clan.name, clan.members.size()])
	if not c.children.is_empty():
		out.append("Children: %d" % c.children.size())
	var stats := lines(c)
	for i in mini(stats.size(), max_stats):
		out.append(stats[i])
	return out
