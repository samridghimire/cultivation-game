extends TestCase
## REL-009: the Platform layer is safe without Steam and forwards milestones and presence with it.


class FakeSteam extends RefCounted:
	var calls: Array = []

	func setAchievement(id: String) -> void:
		calls.append(["ach", id])

	func storeStats() -> void:
		calls.append(["store"])

	func setRichPresence(key: String, value: String) -> void:
		calls.append([key, value])


func _start() -> CharacterData:
	var c := CharacterFactory.create("Platform", GameState.data, seeded_rng(77))
	c.spiritual_roots = {"fire": 80}
	GameState.start_session(c)
	return c


func test_calls_are_safe_without_steam() -> void:
	var old: Object = Platform.backend
	Platform.backend = null
	assert_false(Platform.is_steam())
	Platform.unlock_achievement("first_fight")
	Platform.set_rich_presence("hello")
	assert_eq(Platform.presence, "hello")
	Platform.backend = old


func test_milestone_unlocks_achievement() -> void:
	var old: Object = Platform.backend
	var fake := FakeSteam.new()
	Platform.backend = fake
	assert_true(Platform.is_steam())
	var c := _start()
	LifeStats.add(c, "fights_won")
	EventBus.player_changed.emit()
	assert_true(fake.calls.has(["ach", "first_fight"]))
	Platform.backend = old
	GameState.end_session()


func test_presence_follows_realm_and_region() -> void:
	var old: Object = Platform.backend
	var fake := FakeSteam.new()
	Platform.backend = fake
	Platform.presence = ""
	_start()
	var expected := "%s in %s" % [Cultivation.realm_label(GameState.player, GameState.data), Exploration.region_name(GameState.data, GameState.current_region)]
	assert_eq(Platform.presence_text(), expected)
	EventBus.region_changed.emit(GameState.current_region)
	assert_eq(Platform.presence, expected)
	assert_true(fake.calls.has(["status", expected]))
	Platform.backend = old
	GameState.end_session()


func test_end_session_clears_presence() -> void:
	var old: Object = Platform.backend
	var fake := FakeSteam.new()
	Platform.backend = fake
	_start()
	EventBus.region_changed.emit(GameState.current_region)
	assert_true(Platform.presence != "")
	GameState.end_session()
	assert_eq(Platform.presence, "")
	assert_true(fake.calls.has(["status", ""]))
	Platform.backend = old
