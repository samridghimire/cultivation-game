extends TestCase
## QA-081: Guidance.tribulation_note's "would not survive" verdict must not contradict
## Tribulation.endure at Foundation Establishment Peak (sim: tests/sim/readiness_truth.gd).

const Sim := preload("res://tests/sim/readiness_truth.gd")
const SAMPLES := 100


func _survival(from: int, gear: bool, skin: bool, shield: bool, alignment: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok := 0
	for i in SAMPLES:
		if Tribulation.endure(Sim.build(data(), from, gear, skin, shield, alignment), data(), from + 1, rng)["survived"]:
			ok += 1
	return float(ok) / SAMPLES


func test_warning_and_survival_agree() -> void:
	var from := data().realm_index_of("foundation_establishment")
	for gear: bool in [false, true]:
		for skin: bool in [false, true]:
			for shield: bool in [false, true]:
				var c := Sim.build(data(), from, gear, skin, shield, 0)
				var says_no := String(Guidance.tribulation_note(c, data()).get("text", "")).contains("would not survive")
				var rate := _survival(from, gear, skin, shield, 0)
				var label := "gear=%s skin=%s shield=%s" % [gear, skin, shield]
				var close := String(Guidance.tribulation_note(c, data()).get("text", "")).contains("be close")
				if close:
					assert_true(rate >= 0.4 and rate <= 0.8, "%s: note says close but %d%% survive" % [label, roundi(rate * 100)])
				elif says_no:
					assert_true(rate <= 0.6, "%s: note says you would not survive but %d%% do" % [label, roundi(rate * 100)])
				else:
					assert_true(rate >= 0.6, "%s: note says nothing but only %d%% survive" % [label, roundi(rate * 100)])
