class_name Trophies
extends RefCounted
## WILD-022: great-beast trophies hung on the wall of your home (the Family Home or a claimed abode).
## Up to MAX_HUNG hang at once (CharacterData.hung_trophies); each gives RENOWN_PER_MONTH renown a month in the
## home's region, and a visitor's first chat there each month may remark on one (family.json `trophy_comment`).

const MAX_HUNG := 3
const RENOWN_PER_MONTH := 1


## Whether `region_id` holds a home of `c`: a claimed abode or a Family Home.
static func has_home(c: CharacterData, people: Dictionary, data: GameData, region_id: String) -> bool:
	return Abodes.owns_in_region(c, data, region_id) or FamilyHome.has_home(c, people, data, region_id)


## The region that earns the monthly renown: the abode's, else the first Family Home region; "" without a home.
static func home_region(c: CharacterData, people: Dictionary, data: GameData) -> String:
	if c.abode != "":
		var region := String(Abodes.get_def(data, c.abode).get("region", ""))
		if region != "":
			return region
	var homes := FamilyHome.regions(c, people, data)
	for r in homes:
		if data.regions.get(r, {}).has("family_home"):
			return r
	return ""


## Why `item_id` cannot be hung in `region_id`, or "".
static func check_hang(c: CharacterData, people: Dictionary, data: GameData, region_id: String, item_id: String) -> String:
	if not has_home(c, people, data, region_id):
		return "You have no home here to hang a trophy in."
	if not data.items.get(item_id, {}).get("tags", []).has("trophy"):
		return "That is not a trophy."
	if c.hung_trophies.has(item_id):
		return "That trophy already hangs on your wall."
	if c.hung_trophies.size() >= MAX_HUNG:
		return "Your wall holds only %d trophies. Take one down first." % MAX_HUNG
	if c.item_count(item_id) < 1:
		return "You are not carrying that trophy."
	return ""


## Hangs one `item_id` from the pack. Returns {ok, reason}.
static func hang(c: CharacterData, people: Dictionary, data: GameData, region_id: String, item_id: String) -> Dictionary:
	var reason := check_hang(c, people, data, region_id, item_id)
	if reason != "":
		return {"ok": false, "reason": reason}
	c.add_item(item_id, -1)
	c.hung_trophies.append(item_id)
	return {"ok": true, "reason": ""}


## Takes a hung trophy down and returns it to the pack. Returns {ok, reason}.
static func take_down(c: CharacterData, people: Dictionary, data: GameData, region_id: String, item_id: String) -> Dictionary:
	if not has_home(c, people, data, region_id):
		return {"ok": false, "reason": "You have no home here."}
	if not c.hung_trophies.has(item_id):
		return {"ok": false, "reason": "That trophy is not on your wall."}
	c.hung_trophies.erase(item_id)
	c.add_item(item_id, 1)
	return {"ok": true, "reason": ""}


## Renown a month of `months` months earns for the hung trophies (0 without a home).
static func monthly_renown(c: CharacterData, people: Dictionary, data: GameData, months: int) -> int:
	if c.hung_trophies.is_empty() or home_region(c, people, data) == "":
		return 0
	return c.hung_trophies.size() * RENOWN_PER_MONTH * maxi(months, 0)


## The monthly-comment line for a chat on `day` in `region_id` ("" when none). Marks the month in `flags`, so only the
## first chat in a home that month can comment.
static func comment(c: CharacterData, people: Dictionary, data: GameData, flags: Dictionary, region_id: String, day: int) -> String:
	var lines: Array = data.family.get("trophy_comment", [])
	if lines.is_empty() or c.hung_trophies.is_empty() or not has_home(c, people, data, region_id):
		return ""
	var month := day / Calendar.DAYS_PER_MONTH
	if int(flags.get("trophy_comment_month", -1)) == month:
		return ""
	flags["trophy_comment_month"] = month
	var id: String = c.hung_trophies[day % c.hung_trophies.size()]
	var name := String(data.items.get(id, {}).get("name", id))
	return String(lines[day % lines.size()]).replace("{trophy}", name)


## Load errors for family.json `trophy_comment`.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var lines: Variant = data.family.get("trophy_comment", [])
	if not (lines is Array):
		return PackedStringArray(["family.json trophy_comment must be a list"])
	for line: Variant in lines:
		if not (line is String) or String(line) == "" or String(line).length() > 160:
			errors.append("family.json trophy_comment lines must be non-empty strings of at most 160 characters")
	return errors
