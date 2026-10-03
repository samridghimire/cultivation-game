class_name Names
extends RefCounted
## Character names and genders from data/names.json. Chinese order: the
## surname comes first ("Han Li" = surname Han, given name Li).


## Valid gender ids (the keys of names.json "given_names").
static func genders(data: GameData) -> Array[String]:
	var out: Array[String] = []
	for g in data.names.get("given_names", {}):
		out.append(String(g))
	return out


static func is_gender(data: GameData, gender: String) -> bool:
	return data.names.get("given_names", {}).has(gender)


static func roll_gender(data: GameData, rng: RandomNumberGenerator) -> String:
	var all := genders(data)
	return all[rng.randi_range(0, all.size() - 1)]


static func roll_surname(data: GameData, rng: RandomNumberGenerator) -> String:
	var pool: Array = data.names.get("surnames", [])
	return String(pool[rng.randi_range(0, pool.size() - 1)])


static func roll_given_name(data: GameData, gender: String, rng: RandomNumberGenerator) -> String:
	var pool: Array = data.names.get("given_names", {}).get(gender, [])
	if pool.is_empty():
		return ""
	return String(pool[rng.randi_range(0, pool.size() - 1)])


static func full_name(surname: String, given_name: String) -> String:
	return ("%s %s" % [surname, given_name]).strip_edges()


## Sets surname, given name and the display name together.
static func apply(c: CharacterData, surname: String, given_name: String) -> void:
	c.surname = surname.strip_edges()
	c.given_name = given_name.strip_edges()
	c.name = full_name(c.surname, c.given_name)


## Why `c` can't pick `gender` ("" = allowed). Only characters whose gender is
## still unknown (old saves) may pick, and only once.
static func check_choose_gender(c: CharacterData, data: GameData, gender: String) -> String:
	if c.gender != "":
		return "Your gender is already set."
	if not is_gender(data, gender):
		return "Unknown gender: %s." % gender
	return ""
