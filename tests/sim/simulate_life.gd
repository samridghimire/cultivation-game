extends SceneTree
## Balance sim: runs N random lives headless with a "sensible" cultivator who
## meditates non-stop and breaks through whenever possible. Reports the average
## age at which each realm is reached and how many lives ended of old age.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_life.gd -- [lives] [density] [seed]

const START_AGE_YEARS := 16
const STEP_DAYS := 10


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var lives := int(args[0]) if args.size() > 0 else 200
	var density := float(args[1]) if args.size() > 1 else 1.0
	var seed_value := int(args[2]) if args.size() > 2 else 1
	var data := GameData.load_from_dir()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ages: Array = []  # per realm: array of ages reached
	for i in data.realms.size():
		ages.append([])
	var old_age_deaths := 0
	var deaths_in: Array = []  # per realm: lives that died of old age while in it
	deaths_in.resize(data.realms.size())
	deaths_in.fill(0)
	var final_realm_total := 0
	for n in lives:
		var c := CharacterFactory.create("Sim%d" % n, data, rng)
		c.age_days = START_AGE_YEARS * Calendar.DAYS_PER_YEAR
		ages[c.realm_index].append(c.age_years())
		while true:
			if Cultivation.years_left(c, data) <= 0:
				old_age_deaths += 1
				deaths_in[c.realm_index] += 1
				break
			if Cultivation.can_attempt_breakthrough(c, data):
				if Cultivation.attempt_breakthrough(c, data, rng)["success"]:
					ages[c.realm_index].append(c.age_years())
			elif c.realm_index >= data.realms.size() - 1 and Cultivation.is_at_bottleneck(c, data):
				break
			else:
				Cultivation.cultivate(c, data, STEP_DAYS, density)
			c.age_days += STEP_DAYS
			Injuries.pass_days(c, STEP_DAYS)
		final_realm_total += c.realm_index
	print("Lives: %d, density %.1f, seed %d. Died of old age: %d. Avg final realm index: %.2f" % [lives, density, seed_value, old_age_deaths, float(final_realm_total) / lives])
	for i in data.realms.size():
		var list: Array = ages[i]
		if list.is_empty():
			print("  %-28s reached by 0/%d" % [data.realms[i].name, lives])
			continue
		var sum := 0
		for a: int in list:
			sum += a
		print("  %-28s reached by %3d/%d, avg age %d, lifespan %d, old-age deaths here %d" % [data.realms[i].name, list.size(), lives, sum / list.size(), data.realms[i].lifespan_years, deaths_in[i]])
	quit()
