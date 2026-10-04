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
