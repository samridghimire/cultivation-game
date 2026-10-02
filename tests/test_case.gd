class_name TestCase
extends RefCounted
## Base class for unit tests. Methods named test_* are run by tests/run_tests.gd.
## Use the assert_* helpers; a test fails if any assertion fails or if the
## engine logs an error while it runs.

var failures: PackedStringArray = []
var _data: GameData


## Fresh copy of the real game data (cached per test file).
func data() -> GameData:
	if _data == null:
		_data = GameData.load_from_dir()
	return _data


func seeded_rng(seed_value: int = 12345) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func new_character(seed_value: int = 12345) -> CharacterData:
	return CharacterFactory.create("Tester", data(), seeded_rng(seed_value))


func assert_true(value: bool, message: String = "") -> void:
	if not value:
		_fail("expected true. " + message)


func assert_false(value: bool, message: String = "") -> void:
	if value:
		_fail("expected false. " + message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_number(actual) and _is_number(expected)):
		_fail("expected %s (%s), got %s (%s). %s" % [expected, type_string(typeof(expected)), actual, type_string(typeof(actual)), message])
	elif actual != expected:
		_fail("expected %s, got %s. %s" % [expected, actual, message])


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("expected %f (+/- %f), got %f. %s" % [expected, tolerance, actual, message])


func assert_gt(actual: Variant, threshold: Variant, message: String = "") -> void:
	if not actual > threshold:
		_fail("expected %s > %s. %s" % [actual, threshold, message])


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func _fail(message: String) -> void:
	failures.append(message)
