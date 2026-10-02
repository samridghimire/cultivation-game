class_name CharacterFactory
extends RefCounted
## Creates new characters with rolled attributes and spiritual roots.

const START_AGE_YEARS := 16
const START_SPIRIT_STONES := 10


## `character_name` is "Surname Given" (Chinese order); a single word is a
## given name with no surname. `gender` must be a names.json gender, or it is rolled.
static func create(character_name: String, data: GameData, rng: RandomNumberGenerator, gender: String = "") -> CharacterData:
	var c := CharacterData.new()
	set_name(c, character_name)
	c.age_days = START_AGE_YEARS * Calendar.DAYS_PER_YEAR
	for attr in data.attributes:
		c.attributes[attr["id"]] = rng.randi_range(int(attr["roll_min"]), int(attr["roll_max"]))
	c.spiritual_roots = SpiritualRoots.roll(data, rng)
	c.add_item("spirit_stone", START_SPIRIT_STONES)
	CreationArtifact.ensure(c, data)
	# Rolled last so earlier rolls stay the same for a given seed.
	c.gender = gender if Names.is_gender(data, gender) else Names.roll_gender(data, rng)
	return c


## Splits "Surname Given" into surname and given name and sets the display name.
static func set_name(c: CharacterData, full: String) -> void:
	var parts := full.strip_edges().split(" ", false, 1)
	if parts.size() == 2:
		Names.apply(c, parts[0], parts[1])
	else:
		Names.apply(c, "", full)
