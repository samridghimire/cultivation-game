class_name SectDef
extends RefCounted
## A sect the player may join. Alignment bounds are inclusive.

var id := ""
var name := ""
var description := ""
var alignment_tag := "neutral"
var min_alignment := -1000
var max_alignment := 1000
var min_realm := "mortal"
var cultivation_bonus := 1.0
var favored_professions: PackedStringArray = []
var ranks: Array[Dictionary] = []  # [{name, contribution}], ascending
var robe_color := ""  # hex; "" = the default rogue robe
## Reputation (Reputation system) needed to join.
var reputation_min_join := -1000000
## Witnessed alignment changes move this sect's reputation by delta * deed_scale.
var reputation_deed_scale := 0.0
## Contribution shop (G-008c): [{item_id, contribution, min_rank}].
var shop: Array[Dictionary] = []


static func from_dict(d: Dictionary) -> SectDef:
	var s := SectDef.new()
	s.id = d.get("id", "")
	s.name = d.get("name", s.id)
	s.description = d.get("description", "")
	s.alignment_tag = d.get("alignment", "neutral")
	s.min_alignment = int(d.get("min_alignment", -1000))
	s.max_alignment = int(d.get("max_alignment", 1000))
	s.min_realm = d.get("min_realm", "mortal")
	s.cultivation_bonus = float(d.get("cultivation_bonus", 1))
	s.favored_professions = PackedStringArray(d.get("favored_professions", []))
	s.ranks.assign(d.get("ranks", []))
	s.robe_color = String(d.get("robe_color", ""))
	var rep: Dictionary = d.get("reputation", {})
	s.reputation_min_join = int(rep.get("min_join", s.reputation_min_join))
	s.reputation_deed_scale = float(rep.get("deed_scale", 0))
	s.shop.assign(d.get("shop", []))
	return s


## Highest rank index whose contribution threshold has been reached.
func rank_for_contribution(contribution: int) -> int:
	var result := 0
	for i in ranks.size():
		if contribution >= int(ranks[i].get("contribution", 0)):
			result = i
	return result


func rank_name(rank: int) -> String:
	if rank < 0 or rank >= ranks.size():
		return "Member"
	return ranks[rank].get("name", "Member")
