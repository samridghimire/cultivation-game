class_name CharacterFactory
extends RefCounted
## Creates new characters with rolled attributes and spiritual roots.

const START_AGE_YEARS := 16
const START_SPIRIT_STONES := 10


static func create(character_name: String, data: GameData, rng: RandomNumberGenerator) -> CharacterData:
	var c := CharacterData.new()
	c.name = character_name
	c.age_days = START_AGE_YEARS * Calendar.DAYS_PER_YEAR
	for attr in data.attributes:
		c.attributes[attr["id"]] = rng.randi_range(int(attr["roll_min"]), int(attr["roll_max"]))
	c.spiritual_roots = SpiritualRoots.roll(data, rng)
	c.add_item("spirit_stone", START_SPIRIT_STONES)
	CreationArtifact.ensure(c, data)
	return c
