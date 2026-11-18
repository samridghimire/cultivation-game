extends TestCase
## PERF-009: the raw-byte ground passes keep the output pixel-identical to the per-pixel versions they replaced.
## Scree (both seasons) and the shade grid / paved stone layout are pixel-identical to the old code (hashes recorded from it);
## (Hashes re-recorded against main after GFX-191/193: scree and paved equal main's per-pixel output.) Grass worn-ground noise and the paved earth / winter slush noise moved to integer hashes, so those hashes are regression
## values of the new layout (the paved layout was checked equal to the old one with the old string hashes swapped back in).

const RECORD := false
const SMALL := Vector2i(192, 128)


func _hash(img: Image) -> String:
	return img.get_data().hex_encode().sha256_text()


func _grass(season: String) -> Image:
	GroundTiles.clear_cache()
	var life := {"avoid": [Rect2(100, 70, 40, 30)], "worn": [Rect2(20, 20, 80, 50), Rect2(150, 90, 60, 40)], "path_color": Color("8a7350")}
	return GroundTiles.ground_texture(Color("4d6b3c"), "qingshi_village", SMALL, true, season, "grass", [], 1.0, life).get_image()


func _scree(season: String) -> Image:
	GroundTiles.clear_cache()
	return GroundTiles.ground_texture(Color("6f6f78"), "myriad_peaks_ridge", SMALL, false, season, "scree", [], 1.0, {}).get_image()


func _paved(season: String) -> Image:
	GroundTiles.clear_cache()
	return GroundTiles.ground_texture(Color("8b8272"), "fallen_star_market", SMALL, false, season, "paved", [Rect2(10, 10, 120, 80)], 1.0, {}).get_image()


func _check(name: String, img: Image, expected: String) -> void:
	if RECORD:
		print("RECORD %s %s" % [name, _hash(img)])
	else:
		assert_eq(_hash(img), expected, name)


func test_grass_summer_identical() -> void:
	_check("grass_summer", _grass("Summer"), "415a3319a7741e6cdfbe6081f28bcc516ad3806690c9f94b112b2b30948a5045")


func test_grass_winter_identical() -> void:
	_check("grass_winter", _grass("Winter"), "6beb058160d9c68c19ce60954ac0b69e9f6e98a0cf1b2130f886ff2becaab0b7")


func test_scree_winter_identical() -> void:
	_check("scree_winter", _scree("Winter"), "c0d6c0b489509a929ade2ea98d9b0294f3b138a89d76e7e6f331baa8ab314d1a")


func test_scree_summer_identical() -> void:
	_check("scree_summer", _scree("Summer"), "9057bca1f77fb1978d64ae37a5e85901113780087d7760528a36a2625810df59")


func test_paved_winter_identical() -> void:
	_check("paved_winter", _paved("Winter"), "983083006336d1268b9513ebc9a8ee4c2286236948609ca832a1a7e791d6c0b5")


func test_paved_summer_identical() -> void:
	_check("paved_summer", _paved("Summer"), "a079db12f944e345acb6bd21b13c4a2ee10cd79b95aa759eaa11e3c99eb0c03b")


func test_profiling_off_by_default() -> void:
	assert_false(GroundTiles.profiling)


func test_ihash_is_deterministic_and_spread() -> void:
	assert_eq(GroundTiles._ihash(5, 3, 4), GroundTiles._ihash(5, 3, 4))
	var seen := {}
	for y in 20:
		seen[GroundTiles._ihash(7, 1, y) % 100] = true
	assert_gt(seen.size(), 10, "neighbouring rows must not hash alike")
