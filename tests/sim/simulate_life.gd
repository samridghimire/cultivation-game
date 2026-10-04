extends SceneTree
## Balance sim: runs N random lives headless and reports the average age at
## which each realm is reached and how many lives ended of old age.
## Profiles:
## - basic: meditates non-stop at a fixed `density` and breaks through whenever possible.
## - real (F-005c): plays like a sensible player. Meditates at the best spot its
##   realm can reach (Spirit Spring as a mortal, Cloud-Sea Cliff on Azure Peak
##   from Qi Refining), joins the Azure Cloud Sect as soon as it may (sect
##   cultivation bonus), works as an alchemist WORK_MONTHS_PER_YEAR and buys the
##   best breakthrough pill it can afford before a major breakthrough.
##   `density` is ignored.
## Heavenly-root lives are also reported separately.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_life.gd -- [lives] [density] [seed] [basic|real]

const START_AGE_YEARS := 16
const STEP_DAYS := 10
## "real" profile tuning (mirrors data/regions.json and data/sects.json; update if they change).
const MORTAL_DENSITY := 1.0 * 2.0  # qingshi_village x Spirit Spring
const CULTIVATOR_DENSITY := 2.5 * 2.0  # azure_peak x Cloud-Sea Cliff (route needs Qi Refining)
const SECT := "azure_cloud_sect"
const PROFESSION := "alchemist"
const WORK_MONTHS_PER_YEAR := 1
## Breakthrough pills a sensible player buys, best first, per target realm id.
const PILLS := {
	"foundation_establishment": ["flawless_foundation_establishment_pill", "foundation_establishment_pill"],
	"core_formation": ["core_forming_pill"],
}
const HEAVENLY_ELEMENTS := 1


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var lives := int(args[0]) if args.size() > 0 else 200
	var density := float(args[1]) if args.size() > 1 else 1.0
	var seed_value := int(args[2]) if args.size() > 2 else 1
	var profile := String(args[3]) if args.size() > 3 else "basic"
	var data := GameData.load_from_dir()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var all := _new_stats(data)
	var heavenly := _new_stats(data)
	for n in lives:
		var c := CharacterFactory.create("Sim%d" % n, data, rng)
		c.age_days = START_AGE_YEARS * Calendar.DAYS_PER_YEAR
		var life := _live(c, data, rng, profile, density)
		_add(all, data, life)
		if c.spiritual_roots.size() == HEAVENLY_ELEMENTS:
			_add(heavenly, data, life)
	print("Profile %s, density %s, seed %d." % [profile, "best reachable" if profile == "real" else "%.1f" % density, seed_value])
	_print(all, data, "All lives")
	_print(heavenly, data, "Heavenly Root lives")
	quit()


## Plays one life to its end. Returns {ages: realm index -> age reached,
## final_realm, old_age, pills}.
func _live(c: CharacterData, data: GameData, rng: RandomNumberGenerator, profile: String, density: float) -> Dictionary:
	var reached := {c.realm_index: c.age_years()}
	var pills := 0
	var real := profile == "real"
	var last_work_year := -1
	while true:
		if Cultivation.years_left(c, data) <= 0:
			return {"ages": reached, "final_realm": c.realm_index, "old_age": true, "pills": pills}
		if real:
			if c.is_rogue() and Sects.check_join(c, data, SECT)["ok"]:
				Sects.join(c, data, SECT)
			if c.age_years() != last_work_year:
				last_work_year = c.age_years()
				var work_days := WORK_MONTHS_PER_YEAR * Calendar.DAYS_PER_MONTH
				Professions.work(c, data, PROFESSION, work_days)
				_pass(c, work_days)
				continue
		if Cultivation.can_attempt_breakthrough(c, data):
			if real and c.breakthrough_bonus <= 0.0 and _buy_pill(c, data):
				pills += 1
			# No techniques or gear are modelled here, so tribulations strike
			# at the NPC strength tuned for such cultivators (QA-010).
			if Cultivation.attempt_breakthrough(c, data, rng, true)["success"]:
				reached[c.realm_index] = c.age_years()
		elif c.realm_index >= data.realms.size() - 1 and Cultivation.is_at_bottleneck(c, data):
			return {"ages": reached, "final_realm": c.realm_index, "old_age": false, "pills": pills}
		else:
			var d := density
			if real:
				d = (MORTAL_DENSITY if c.realm_index == 0 else CULTIVATOR_DENSITY) * Sects.cultivation_bonus(c, data)
			Cultivation.cultivate(c, data, STEP_DAYS, d)
		_pass(c, STEP_DAYS)
	return {}


func _pass(c: CharacterData, days: int) -> void:
	c.age_days += days
	Injuries.pass_days(c, days)


## Buys and takes the best affordable pill for the next major breakthrough.
func _buy_pill(c: CharacterData, data: GameData) -> bool:
	var target: String = data.realms[c.realm_index + 1].id
	for item_id: String in PILLS.get(target, []):
		if Items.buy(c, data, item_id)["ok"]:
			Items.use(c, data, item_id, {})
			return true
	return false


func _new_stats(data: GameData) -> Dictionary:
	var ages: Array = []
	var deaths: Array = []
	for i in data.realms.size():
		ages.append([])
		deaths.append(0)
	return {"lives": 0, "ages": ages, "deaths_in": deaths, "old_age": 0, "final_total": 0, "pills": 0}


func _add(stats: Dictionary, data: GameData, life: Dictionary) -> void:
	stats["lives"] += 1
	for realm_index: int in life["ages"]:
		stats["ages"][realm_index].append(life["ages"][realm_index])
	if life["old_age"]:
		stats["old_age"] += 1
		stats["deaths_in"][life["final_realm"]] += 1
	stats["final_total"] += life["final_realm"]
	stats["pills"] += life["pills"]


func _print(stats: Dictionary, data: GameData, title: String) -> void:
	var lives: int = stats["lives"]
	if lives == 0:
		print("%s: none." % title)
		return
	print("%s: %d. Died of old age: %d. Avg final realm index: %.2f. Breakthrough pills taken: %d" % [title, lives, stats["old_age"], float(stats["final_total"]) / lives, stats["pills"]])
	for i in data.realms.size():
		var list: Array = stats["ages"][i]
		if list.is_empty():
			print("  %-28s reached by 0/%d" % [data.realms[i].name, lives])
			continue
		var sum := 0
		for a: int in list:
			sum += a
		print("  %-28s reached by %3d/%d, avg age %d, lifespan %d, old-age deaths here %d" % [data.realms[i].name, list.size(), lives, sum / list.size(), data.realms[i].lifespan_years, stats["deaths_in"][i]])
