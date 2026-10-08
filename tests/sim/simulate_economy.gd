extends SceneTree
## Economy sim (QA-006): runs N lives per profession with a cultivator who
## works their profession one month in every `work_every` months and
## cultivates the rest. Spirit stones come from Professions.work; they are
## spent on artifact lives (CreationArtifact.recharge after violent deaths,
## rolled at `deaths_per_century`) and on the breakthrough pill for the next
## major realm (BREAKTHROUGH_PILLS) when the cultivator reaches a bottleneck.
## Reports per profession: realm reached, stones earned, pills bought vs
## bottlenecks faced without one, lives bought and the dearest recharge, and
## lives that ended for good (artifact empty) or of old age.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_economy.gd -- [lives] [work_every] [deaths_per_century] [seed]

const START_AGE_YEARS := 16
const STEP_DAYS := 30
## Next realm id -> the pill a sensible cultivator buys before breaking into it.
const BREAKTHROUGH_PILLS := {
	"foundation_establishment": "foundation_establishment_pill",
	"core_formation": "core_forming_pill",
	"nascent_soul": "nascent_soul_pill",
	"soul_formation": "soul_formation_pill",
}


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var lives := int(args[0]) if args.size() > 0 else 50
	var work_every := int(args[1]) if args.size() > 1 else 4
	var deaths_per_century := float(args[2]) if args.size() > 2 else 3.0
	var seed_value := int(args[3]) if args.size() > 3 else 1
	var data := GameData.load_from_dir()
	print("Economy sim: %d lives per profession, work 1 month in %d, %.1f violent deaths per century, seed %d" % [lives, work_every, deaths_per_century, seed_value])
	for pill_realm: String in BREAKTHROUGH_PILLS:
		var pill: String = BREAKTHROUGH_PILLS[pill_realm]
		print("  %s costs %d spirit stones" % [data.items[pill]["name"], int(data.items[pill]["price"])])
	for prof_id: String in data.professions:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var totals := {}
		for n in lives:
			_add(totals, _simulate_life(data, prof_id, work_every, deaths_per_century, rng))
		_report(data, prof_id, totals, lives)
	quit()


## One life; returns counters (see _report).
func _simulate_life(data: GameData, prof_id: String, work_every: int, deaths_per_century: float, rng: RandomNumberGenerator) -> Dictionary:
	var c := CharacterFactory.create("Sim", data, rng)
	c.age_days = START_AGE_YEARS * Calendar.DAYS_PER_YEAR
	CreationArtifact.ensure(c, data)
	var stats := {"earned": 0, "pills": 0, "no_pill": 0, "recharges": 0, "max_recharge": 0, "final_deaths": 0, "final_age": 0, "old_age": 0, "realm": 0, "rank": 0, "stones_left": 0}
	for pill_realm: String in BREAKTHROUGH_PILLS:
		stats["faced_" + pill_realm] = 0
		stats["first_pill_" + pill_realm] = 0
	var death_chance := deaths_per_century / 100.0 / (Calendar.DAYS_PER_YEAR / float(STEP_DAYS))
	var month := 0
	while true:
		if Cultivation.years_left(c, data) <= 0:
			stats["old_age"] = 1
			break
		if Cultivation.can_attempt_breakthrough(c, data):
			_buy_pill(c, data, stats)
			Cultivation.attempt_breakthrough(c, data, rng)
		elif c.realm_index >= data.realms.size() - 1 and Cultivation.is_at_bottleneck(c, data):
			break
		elif month % work_every == 0:
			stats["earned"] += int(Professions.work(c, data, prof_id, STEP_DAYS)["income"])
		else:
			Cultivation.cultivate(c, data, STEP_DAYS)
		month += 1
		c.age_days += STEP_DAYS
		Injuries.pass_days(c, STEP_DAYS)
		if rng.randf() < death_chance:
			if not CreationArtifact.can_respawn(c):
				stats["final_deaths"] = 1
				stats["final_age"] = c.age_years()
				break
			CreationArtifact.respawn(c, data)
		_recharge(c, data, stats)
	stats["realm"] = c.realm_index
	stats["rank"] = Professions.rank_of(c, prof_id)
	stats["stones_left"] = c.item_count("spirit_stone")
	return stats


## Buys and swallows the pill for the next realm if there is one and it is
## affordable; otherwise counts a bottleneck faced without it.
func _buy_pill(c: CharacterData, data: GameData, stats: Dictionary) -> void:
	var next_id: String = data.realms[c.realm_index + 1].id
	var pill: String = BREAKTHROUGH_PILLS.get(next_id, "")
	if pill == "" or c.breakthrough_bonus > 0.0:
		return
	var first: bool = stats["faced_" + next_id] == 0
	if first:
		stats["faced_" + next_id] = 1
	if Items.buy(c, data, pill)["ok"] and Items.use(c, data, pill, {})["ok"]:
		stats["pills"] += 1
		if first:
			stats["first_pill_" + next_id] = 1
	else:
		stats["no_pill"] += 1


## An empty artifact is refilled first; spare stones (beyond the next pill's
## price) top it back up to the starting lives.
func _recharge(c: CharacterData, data: GameData, stats: Dictionary) -> void:
	var starting := int(data.artifact.get("starting_lives", 3))
	while c.artifact_lives < starting:
		var cost := CreationArtifact.recharge_cost(c, data)
		var reserve := 0 if c.artifact_lives == 0 else _next_pill_price(c, data)
		if c.item_count("spirit_stone") < cost + reserve or not CreationArtifact.recharge(c, data)["ok"]:
			return
		stats["recharges"] += 1
		stats["max_recharge"] = maxi(stats["max_recharge"], cost)


func _next_pill_price(c: CharacterData, data: GameData) -> int:
	for i in range(c.realm_index + 1, data.realms.size()):
		var pill: String = BREAKTHROUGH_PILLS.get(data.realms[i].id, "")
		if pill != "":
			return int(data.items[pill]["price"])
	return 0


func _add(totals: Dictionary, stats: Dictionary) -> void:
	for key: String in stats:
		if key == "max_recharge":
			totals[key] = maxi(int(totals.get(key, 0)), int(stats[key]))
		else:
			totals[key] = int(totals.get(key, 0)) + int(stats[key])


func _report(data: GameData, prof_id: String, totals: Dictionary, lives: int) -> void:
	var avg := func(key: String) -> float: return float(totals[key]) / lives
	var realm_name: String = data.realms[roundi(avg.call("realm"))].name
	var final_age := float(totals["final_age"]) / maxi(totals["final_deaths"], 1)
	print("%s (rank %.1f at the end): avg final realm %.2f (~%s); earned %d, left %d stones" % [
		data.professions[prof_id].name, avg.call("rank"), avg.call("realm"), realm_name,
		roundi(avg.call("earned")), roundi(avg.call("stones_left"))])
	for pill_realm: String in BREAKTHROUGH_PILLS:
		print("    %s: %d/%d lives reached the bottleneck, %d could afford the pill on the first attempt" % [
			data.realms[data.realm_index_of(pill_realm)].name, totals["faced_" + pill_realm], lives, totals["first_pill_" + pill_realm]])
	print("    pills %d, attempts without a pill %d; lives bought %d (dearest %d); ended for good %d (avg age %d), old age %d" % [
		totals["pills"], totals["no_pill"], totals["recharges"], totals["max_recharge"],
		totals["final_deaths"], roundi(final_age), totals["old_age"]])
