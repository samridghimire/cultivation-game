extends SceneTree
## Readiness truth (QA-081): does Guidance.tribulation_note's "would not survive" verdict
## agree with Tribulation.endure? Foundation Establishment Peak attempters, by gear, Stone
## Skin, a readied shield talisman and alignment; 200 seeded tribulations each.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/readiness_truth.gd -- [samples]

const Balance := preload("res://tests/sim/combat_balance.gd")
const Trib := preload("res://tests/sim/tribulation_balance.gd")


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


static func build(data: GameData, from: int, gear: bool, stone_skin: bool, shield: bool, alignment: int) -> CharacterData:
	var stage := data.realms[from].stage_count() - 1
	var c := Balance.typical_player(data, from, stage) if gear else Balance.bare_player(data, from, stage)
	if not gear and stone_skin and data.techniques.has("stone_skin"):
		c.techniques["stone_skin"] = {"level": Balance.tech_level(data, from), "xp": 0.0}
	if gear and not stone_skin:
		c.techniques.erase("stone_skin")
	if shield:
		var ward := Trib.best_ward(data, from)
		if ward != "":
			c.add_item(ward, 1)
			c.readied_talismans.append(ward)
	c.alignment = alignment
	return c


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var samples := int(args[0]) if args.size() > 0 else 200
	var data := GameData.load_from_dir()
	var from := 1
	for i in data.realms.size():
		if data.realms[i].id == "foundation_establishment":
			from = i
	print("Readiness truth, %s Peak -> %s, %d tribulations per row." % [data.realms[from].name, data.realms[from + 1].name, samples])
	print("%-34s %-5s %-14s %s" % ["profile", "note", "survive", "mismatch"])
	for gear in [false, true]:
		for stone_skin in [false, true]:
			for shield in [false, true]:
				for alignment in [0, -500]:
					var c := build(data, from, gear, stone_skin, shield, alignment)
					var note := Guidance.tribulation_note(c, data)
					var text := String(note.get("text", ""))
					var verdict := "NO" if text.contains("would not survive") else ("close" if text.contains("be close") else "ok")
					var says_no := verdict == "NO"
					var rng := RandomNumberGenerator.new()
					rng.seed = 1
					var ok := 0
					for n in samples:
						if Tribulation.endure(build(data, from, gear, stone_skin, shield, alignment), data, from + 1, rng)["survived"]:
							ok += 1
					var rate := float(ok) / samples
					var mismatch := ""
					if says_no and rate > 0.6:
						mismatch = "SAYS NO, survives >60%"
					elif verdict == "ok" and rate < 0.6:
						mismatch = "SAYS OK, survives <60%"
					elif verdict == "close" and (rate < 0.4 or rate > 0.8):
						mismatch = "SAYS CLOSE, survives %d%%" % roundi(rate * 100)
					print("%-34s %-5s %5d%%         %s" % ["%s skin=%s shield=%s al=%d" % ["gear" if gear else "bare", stone_skin, shield, alignment], verdict, roundi(rate * 100), mismatch])
	quit()
