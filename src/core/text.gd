class_name Text
extends RefCounted
## Small English helpers for messages built from data names.


## `noun` with "a" or "an" in front: "an Alchemist", "a Wild Boar", "an 8th Grade Doctor".
static func a(noun: String) -> String:
	if noun == "":
		return noun
	var first := noun.left(1).to_lower()
	var vowel_sound := "aeiou".contains(first) or noun.begins_with("8") or noun.begins_with("11 ") or noun.begins_with("11th") or noun.begins_with("18")
	return ("an " if vowel_sound else "a ") + noun


## "A", "A and B", "A, B and C".
static func join_and(items: PackedStringArray) -> String:
	if items.size() <= 1:
		return "".join(items)
	return "%s and %s" % [", ".join(items.slice(0, items.size() - 1)), items[items.size() - 1]]


## `noun` for `count` of them: "Spirit Herb" x1 stays, x3 is "Spirit Herbs". Only the last word is inflected.
static func plural(noun: String, count: int) -> String:
	if count == 1 or noun == "":
		return noun
	var lower := noun.to_lower()
	for ending in ["s", "x", "z", "ch", "sh"]:
		if lower.ends_with(ending):
			return noun + "es"
	if lower.ends_with("y") and noun.length() >= 2 and not "aeiou".contains(lower.substr(lower.length() - 2, 1)):
		return noun.left(noun.length() - 1) + "ies"
	return noun + "s"
