extends TestCase
## QA-010: tribulation balance guards (tests/sim/tribulation_balance.gd). Every
## tribulation is a real but survivable risk for a typical cultivator at the
## previous realm's peak (~85% target), a readied ward helps without making it
## safe (TRIB-001d), and deep
## demonic cultivators pay for the heart demon without it being a death sentence.
## Full report: tests/sim/simulate_tribulation.gd.

const Trib := preload("res://tests/sim/tribulation_balance.gd")
const SAMPLES := 150


func test_attempter_is_at_previous_realm_peak() -> void:
	var core := data().realm_index_of("core_formation")
	var c := Trib.attempter(data(), core, "prepared", -500)
	assert_eq(c.realm_index, core - 1)
	assert_eq(c.stage, data().realms[core - 1].stage_count() - 1)
	assert_eq(c.alignment, -500)
	assert_false(c.readied_talismans.is_empty(), "prepared attempters ready a shield")
	assert_true(Trib.attempter(data(), core, "bare").techniques.is_empty())


func test_typical_cultivator_faces_real_but_survivable_risk() -> void:
	for realm in Trib.tribulation_realms(data()):
		var name := data().realms[realm].id
		var typical: float = Trib.odds(data(), realm, "typical", 0, SAMPLES)["survive"]
		assert_true(typical >= 0.7 and typical <= 0.97, "%s typical survival %.2f outside 0.70..0.97" % [name, typical])
		var prepared: float = Trib.odds(data(), realm, "prepared", 0, SAMPLES)["survive"]
		assert_true(prepared >= typical, "%s: a readied shield never lowers survival" % name)
		# TRIB-001d / QA-010b: the best buyable ward matters at every realm but never trivializes it.
		assert_true(Trib.best_ward(data(), realm - 1) != "", "%s: a ward is for sale" % name)
		assert_true(prepared >= typical + 0.03, "%s: a ward should matter (%.2f vs %.2f)" % [name, prepared, typical])
		assert_true(prepared <= 0.98, "%s: a ward should not make the tribulation safe (%.2f)" % [name, prepared])


func test_heart_demon_is_costly_not_hopeless() -> void:
	for realm in Trib.tribulation_realms(data()):
		var name := data().realms[realm].id
		var neutral: float = Trib.odds(data(), realm, "typical", 0, SAMPLES)["survive"]
		var demonic: float = Trib.odds(data(), realm, "typical", -1000, SAMPLES)["survive"]
		assert_true(demonic < neutral - 0.1, "%s: the heart demon should matter (%.2f vs %.2f)" % [name, demonic, neutral])
		assert_true(demonic >= 0.35, "%s: deep demonic survival %.2f below 0.35" % [name, demonic])


func test_npcs_survive_like_typical_players() -> void:
	for realm in Trib.tribulation_realms(data()):
		var name := data().realms[realm].id
		var npc: float = Trib.odds(data(), realm, "npc", 0, SAMPLES)["survive"]
		assert_true(npc >= 0.7 and npc <= 0.97, "%s NPC survival %.2f outside 0.70..0.97" % [name, npc])
		var bare: float = Trib.odds(data(), realm, "bare", 0, SAMPLES)["survive"]
		assert_true(npc > bare, "%s: npc_strength softens lightning for NPCs" % name)
