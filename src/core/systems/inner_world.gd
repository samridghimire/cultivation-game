class_name InnerWorld
extends RefCounted
## The Creation Artifact's Inner World (ART-003b): a pocket realm the player
## enters to cultivate at the function's qi_density while time runs `dilation`
## times faster than outside. The body ages by the inner days. Tuned by the
## "inner_world" function in data/artifact.json.

const FUNCTION := "inner_world"


static func def(data: GameData) -> Dictionary:
	return ArtifactFunctions.get_def(data, FUNCTION)


static func max_days(data: GameData) -> int:
	return int(def(data).get("max_days", 30))


## Inner days that pass for `world_days` outside.
static func inner_days(data: GameData, world_days: int) -> int:
	return world_days * maxi(1, int(def(data).get("dilation", 1)))


## Why `c` cannot spend `world_days` in the Inner World now, or "".
static func check_enter(c: CharacterData, data: GameData, world_days: int) -> String:
	if def(data).is_empty():
		return "The artifact holds no inner world."
	if not ArtifactFunctions.is_unlocked(c, FUNCTION):
		return "The artifact's inner world is still sealed."
	if world_days < 1 or world_days > max_days(data):
		return "You can stay in the inner world 1 to %d days at a time." % max_days(data)
	if SpiritualRoots.cultivation_multiplier(c.spiritual_roots, data) <= 0.0:
		return "Without a spiritual root, even the inner world's qi slips through you."
	if Cultivation.is_at_bottleneck(c, data):
		return "You are at a bottleneck; the inner world's qi cannot help until you break through."
	var inner := inner_days(data, world_days)
	if inner - world_days >= Cultivation.years_left(c, data) * Calendar.DAYS_PER_YEAR:
		return "The inner world's quickened time would spend the last of your life."
	return ""


## Cultivates inside for `world_days` (`density_mult` = sect bonus etc.).
## The extra inner days age `c`; the caller passes the world days.
## Returns {ok, reason, inner_days, qi_gained, stages_gained, at_bottleneck}.
static func cultivate(c: CharacterData, data: GameData, world_days: int, density_mult: float = 1.0) -> Dictionary:
	var reason := check_enter(c, data, world_days)
	if reason != "":
		return {"ok": false, "reason": reason, "inner_days": 0, "qi_gained": 0.0, "stages_gained": 0, "at_bottleneck": false}
	var inner := inner_days(data, world_days)
	var result := Cultivation.cultivate(c, data, inner, float(def(data).get("qi_density", 1.0)) * density_mult)
	c.age_days += inner - world_days
	return {"ok": true, "reason": "", "inner_days": inner, "qi_gained": float(result["qi_gained"]), "stages_gained": int(result["stages_gained"]), "at_bottleneck": bool(result["at_bottleneck"])}


## Load errors for the inner_world function.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var d := def(data)
	if d.is_empty():
		return errors
	if float(d.get("qi_density", 0.0)) <= 0.0:
		errors.append("artifact.json inner_world needs qi_density > 0")
	if int(d.get("dilation", 0)) < 1:
		errors.append("artifact.json inner_world needs dilation >= 1")
	if int(d.get("max_days", 0)) < 1:
		errors.append("artifact.json inner_world needs max_days >= 1")
	return errors
