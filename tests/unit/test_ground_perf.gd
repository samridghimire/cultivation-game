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


func _bog(season: String) -> Image:
	GroundTiles.clear_cache()
	var life := {"avoid": [Rect2(100, 70, 40, 30)], "worn": [Rect2(20, 20, 80, 50)], "path_color": Color("5a4f3a")}
	return GroundTiles.ground_texture(Color("3f4f3a"), "withered_bone_marsh", SMALL, true, season, "bog", [], 1.0, life).get_image()


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
	_check("scree_winter", _scree("Winter"), "a23035103ae523277bf8388c2574426093c683b760e5a928dfffbc7d8b8a1b43")


func test_scree_summer_identical() -> void:
	_check("scree_summer", _scree("Summer"), "fd6c2f3fec467187372d1f70785453c251268e270f615a9908c7ea37ee474afb")


func test_paved_winter_identical() -> void:
	_check("paved_winter", _paved("Winter"), "7d499aff4d27d3733d676a8714f01f46ea47ee5fcd7c3f4dfd3698a8f6e5a14c")


func test_paved_summer_identical() -> void:
	_check("paved_summer", _paved("Summer"), "5b91670d541a6fbbc16cc469c35a77a156a07fb8d726411c5637af3013a78073")


func test_profiling_off_by_default() -> void:
	assert_false(GroundTiles.profiling)


func test_ihash_is_deterministic_and_spread() -> void:
	assert_eq(GroundTiles._ihash(5, 3, 4), GroundTiles._ihash(5, 3, 4))
	var seen := {}
	for y in 20:
		seen[GroundTiles._ihash(7, 1, y) % 100] = true
	assert_gt(seen.size(), 10, "neighbouring rows must not hash alike")


func test_bog_winter_identical() -> void:  ## PERF-010: shade_grid_for rebuilt per lattice row, same doubles
	_check("bog_winter", _bog("Winter"), "7f0e8b3a3aabd917731408b7adcd1ec1411fb17cd0da24ed4679f0168d289c4e")


## GFX-198: no 8x8-periodic dotted grid on the ridge's Spring scree (luminance autocorrelation at lag 8 vs lag 7).
func _lag_corr(img: Image, lag: int) -> float:
	var n := 128
	var vals := PackedFloat32Array()
	var mean := 0.0
	for y in n:
		for x in n:
			var v := img.get_pixel(x, y).get_luminance()
			vals.append(v)
			mean += v
	mean /= float(n * n)
	var s := 0.0
	for y in n:
		for x in n - lag:
			s += (vals[y * n + x] - mean) * (vals[y * n + x + lag] - mean)
	return s


func test_scree_spring_has_no_tile_lattice() -> void:
	GroundTiles.clear_cache()
	var img := GroundTiles.ground_texture(Color("4d5568"), "myriad_peaks_ridge", Vector2i(400, 300), false, "Spring", "scree", [], 0.4, {"speckle": 0.33}).get_image()
	var c7 := _lag_corr(img, 7)
	var c8 := _lag_corr(img, 8)
	var c16 := _lag_corr(img, 16)
	assert_true(c8 <= c7 * 1.1, "lag 8 not stronger than lag 7")
	assert_true(c16 <= c7 * 1.1, "lag 16 not stronger than lag 7")


func test_alpine_blobs_stay_off_the_edge() -> void:
	var size := Vector2i(1600, 1000)
	for kind in ["snow", "tuft", "bloom", "hollow"]:
		for b in GroundTiles.alpine_blobs("myriad_peaks_ridge", kind, 400, size):
			assert_true(b.x >= 24.0 and b.y >= 24.0 and b.x <= 1576.0 and b.y <= 976.0, "%s blob inside" % kind)


func test_winter_paving_edge_mixes_snow_and_stone() -> void:
	GroundTiles.clear_cache()
	var zone := Rect2(40, 40, 120, 80)
	var img := GroundTiles.ground_texture(Color("8b8272"), "fallen_star_market", Vector2i(200, 160), false, "Winter", "paved", [zone], 1.0, {}).get_image()
	var lums := {}
	for x in range(41, 160):  # top kerb band rows (y 40..43 minus jitter): count distinct luminance levels in the band
		lums[snappedf(img.get_pixel(x, 42).get_luminance(), 0.03)] = true
	assert_true(lums.size() > 4, "kerb band is not one flat strip")
