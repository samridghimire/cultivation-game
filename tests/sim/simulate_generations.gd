extends SceneTree
## Generational sim (FAM-013): runs the off-screen NPC world (Npcs.simulate,
## which includes NpcFamilies marriages and births) for many years headless,
## the way GameState does (named NPCs + courtship candidates, refilled after
## off-screen marriages), with no player. Reports, every `report_every` years:
## living / total NPCs, married couples, births and deaths so far, the deepest
## generation alive, the save size of the NPC table, and the realm spread of
## living first-generation NPCs vs. those born in the sim.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_generations.gd -- [years] [seed] [report_every]


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var years := int(args[0]) if args.size() > 0 else 300
	var seed_value := int(args[1]) if args.size() > 1 else 1
	var report_every := int(args[2]) if args.size() > 2 else 25
	var data := GameData.load_from_dir()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var npcs := {}
	Npcs.ensure_all(npcs, data, rng)
	Npcs.ensure_eligible(npcs, data, rng)
	var founders := {}
	for npc_id in npcs:
		founders[npc_id] = true
	var births := 0
	var marriages := 0
	var started := Time.get_ticks_msec()
	print("Generational sim: %d years, seed %d, %d starting NPCs, population_cap %d" % [years, seed_value, npcs.size(), int(NpcFamilies.rules(data).get("population_cap", 0))])
	print("  year  alive  total  couples  births  marriages  oldest-gen  save-kB  founders(alive: avg realm)  born(alive: avg realm, best)")
	for year in range(1, years + 1):
		var married_off := false
		for event in Npcs.simulate(npcs, data, Calendar.DAYS_PER_YEAR, rng):
			match String(event.get("kind", "")):
				"birth":
					births += 1
				"marriage":
					marriages += 1
					married_off = true
		if married_off:
			Npcs.ensure_eligible(npcs, data, rng)  # as GameState._on_days_advanced does
		if year % report_every == 0 or year == years:
			_report(year, npcs, data, founders, births, marriages)
	print("Done in %.1f s." % ((Time.get_ticks_msec() - started) / 1000.0))
	quit()


func _report(year: int, npcs: Dictionary, data: GameData, founders: Dictionary, births: int, marriages: int) -> void:
	var alive := 0
	var couples := 0
	var founder_alive := 0
	var founder_realms := 0
	var born_alive := 0
	var born_realms := 0
	var born_best := 0
	var deepest := 0
	var generation := {}
	for c: CharacterData in npcs.values():
		var gen := _generation(c, npcs, generation)
		if not c.alive:
			continue
		alive += 1
		deepest = maxi(deepest, gen)
		for spouse_id in Family.living_spouses(c, npcs):
			if c.id < spouse_id:
				couples += 1
		if founders.has(c.id):
			founder_alive += 1
			founder_realms += c.realm_index
		else:
			born_alive += 1
			born_realms += c.realm_index
			born_best = maxi(born_best, c.realm_index)
	var save_kb := JSON.stringify(Npcs.to_dict(npcs)).length() / 1024.0
	var founder_avg := float(founder_realms) / founder_alive if founder_alive > 0 else 0.0
	var born_avg := float(born_realms) / born_alive if born_alive > 0 else 0.0
	print("  %4d  %5d  %5d  %7d  %6d  %9d  %10d  %7.0f  %4d: %.2f                   %4d: %.2f, %s" % [year, alive, npcs.size(), couples, births, marriages, deepest, save_kb, founder_alive, founder_avg, born_alive, born_avg, data.realms[born_best].name])


## Generation number: 0 for NPCs with no parents in `npcs`, else 1 + the
## deepest parent's. Memoized in `memo`.
func _generation(c: CharacterData, npcs: Dictionary, memo: Dictionary) -> int:
	if memo.has(c.id):
		return memo[c.id]
	var gen := 0
	for parent_id in c.parents:
		var parent: CharacterData = npcs.get(parent_id)
		if parent != null:
			gen = maxi(gen, _generation(parent, npcs, memo) + 1)
	memo[c.id] = gen
	return gen
