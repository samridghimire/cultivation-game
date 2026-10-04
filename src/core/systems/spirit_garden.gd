class_name SpiritGarden
extends RefCounted
## The Spirit Garden in the artifact's inner world (ART-004): plant a carried
## herb in a free plot; it grows for its `days` of inner time (world days times
## the inner world's dilation) and is then harvested for `yield` copies.
## Plots live on CharacterData.garden as [{item, days_left}] (inner days).
## Tuned by the "spirit_garden" function in data/artifact.json.

const FUNCTION := "spirit_garden"


static func def(data: GameData) -> Dictionary:
	return ArtifactFunctions.get_def(data, FUNCTION)


static func plots(data: GameData) -> int:
	return int(def(data).get("plots", 0))


static func plant_def(data: GameData, item_id: String) -> Dictionary:
	return def(data).get("plants", {}).get(item_id, {})


## Herb ids that can be planted, in data order.
static func plantable(data: GameData) -> Array[String]:
	var out: Array[String] = []
	for item_id in def(data).get("plants", {}):
		out.append(String(item_id))
	return out


## Why `c` cannot plant `item_id` now, or "".
static func check_plant(c: CharacterData, data: GameData, item_id: String) -> String:
	if not ArtifactFunctions.is_unlocked(c, FUNCTION):
		return "The spirit garden is still sealed."
	if plant_def(data, item_id).is_empty():
		return "That will not take root in the spirit garden."
	if c.item_count(item_id) < 1:
		return "You have no %s to plant." % data.items.get(item_id, {}).get("name", item_id)
	if c.garden.size() >= plots(data):
		return "Every plot is planted (%d)." % plots(data)
	return ""


## Plants one `item_id` from the inventory. Returns {ok, reason}.
static func plant(c: CharacterData, data: GameData, item_id: String) -> Dictionary:
	var reason := check_plant(c, data, item_id)
	if reason != "":
		return {"ok": false, "reason": reason}
	c.add_item(item_id, -1)
	c.garden.append({"item": item_id, "days_left": int(plant_def(data, item_id).get("days", 1))})
	return {"ok": true, "reason": ""}


## Lets `world_days` pass outside: plots grow by the inner days.
## Returns the item ids that just became ready.
static func advance(c: CharacterData, data: GameData, world_days: int) -> Array[String]:
	var ready: Array[String] = []
	var inner := InnerWorld.inner_days(data, world_days)
	for plot: Dictionary in c.garden:
		if int(plot["days_left"]) <= 0:
			continue
		plot["days_left"] = maxi(0, int(plot["days_left"]) - inner)
		if int(plot["days_left"]) == 0:
			ready.append(String(plot["item"]))
	return ready


## Harvests every ready plot. Returns {item_id: quantity}.
static func harvest(c: CharacterData, data: GameData, rng: RandomNumberGenerator) -> Dictionary:
	var gained := {}
	var keep: Array = []
	for plot: Dictionary in c.garden:
		if int(plot["days_left"]) > 0:
			keep.append(plot)
			continue
		var item_id := String(plot["item"])
		var yields: Array = plant_def(data, item_id).get("yield", [1, 1])
		var amount := rng.randi_range(int(yields[0]), int(yields[1]))
		c.add_item(item_id, amount)
		gained[item_id] = int(gained.get(item_id, 0)) + amount
	c.garden = keep
	return gained


## "Flame Lotus: ready" / "Flame Lotus: 40 days" per plot, then free plots.
static func describe(c: CharacterData, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = []
	for plot: Dictionary in c.garden:
		var item_name := String(data.items.get(String(plot["item"]), {}).get("name", plot["item"]))
		var left := int(plot["days_left"])
		var world_left := ceili(float(left) / float(InnerWorld.inner_days(data, 1)))
		lines.append("%s: %s" % [item_name, "ready to harvest" if left <= 0 else "ready in %s" % Calendar.format_duration(world_left)])
	for i in maxi(0, plots(data) - c.garden.size()):
		lines.append("(empty plot)")
	return lines


## Load errors for the spirit_garden function.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var d := def(data)
	if d.is_empty():
		return errors
	if int(d.get("plots", 0)) < 1:
		errors.append("artifact.json spirit_garden needs plots >= 1")
	for item_id in d.get("plants", {}):
		var plant: Dictionary = d["plants"][item_id]
		if not data.items.has(item_id):
			errors.append("artifact.json spirit_garden plants unknown item '%s'" % item_id)
		var yields: Array = plant.get("yield", [])
		if int(plant.get("days", 0)) < 1 or yields.size() != 2 or int(yields[0]) < 1 or int(yields[1]) < int(yields[0]):
			errors.append("artifact.json spirit_garden plant '%s' needs days >= 1 and yield [min >= 1, max >= min]" % item_id)
	return errors
