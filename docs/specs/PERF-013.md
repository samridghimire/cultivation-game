# PERF-013: Regions that load from a cache

**Role:** systems. **Reference:** none (Steam Deck readiness; the usual "bake once, load many" approach of tile games).

## Why
PERF-008 set a 250 ms cold budget per region build. After PERF-009/010 the worst cold builds are still Winter:
fallen_star_market ~459 ms (paved `_apply_style` ~213 ms + `_winter_streets` ~207 ms), qingshi_village and
withered_bone_marsh Winter ~250-300 ms (`_apply_worn` ~100, `_apply_patches` ~80, `_vary_snow` ~50). PERF-010's worker
concluded more byte-twiddling will not get there. The ground texture is a pure function of its inputs, so bake it once.

## What to build
1. `src/world/ground_cache.gd` (`class_name GroundCache`, RefCounted, static funcs, `##` doc comment):
   - `const VERSION := 1` (bump whenever any ground pass changes its output; say so in a comment at the top of
     ground_tiles.gd).
   - `static func key(parts: Array) -> String`, a stable key: `str(parts).sha256_text().substr(0, 24)`
     with `VERSION` and the Godot image format in `parts`.
   - `static func load_image(k: String) -> Image` (null on a miss, a size mismatch or a decode error; never throws)
     and `static func save_image(k: String, img: Image) -> void` writing `user://cache/ground/<k>.png`
     (`DirAccess.make_dir_recursive_absolute`). Wrap errors: a failed write just logs nothing and returns.
   - `static func prune(keep: int = 48) -> void`: delete the oldest files beyond `keep` (by modified time).
   - `static var enabled := true` so tests and the profiler can force cold builds.
2. In `GroundTiles.ground_texture` (ground_tiles.gd ~107) build the key from **every** input that changes the output
   (base color html, rid, size, flowers, season, style, zones, worn rects, scree/speckle/meadow values, path color...),
   try the cache before running the passes, and save after a cold build. Do the same in `path_texture` (~1059) if its
   cold cost is > 20 ms. The in-memory cache (`cached`, `clear_cache`) stays as it is in front of the disk cache.
3. `tests/sim/region_load_times.gd`: add `--no-disk-cache` (sets `GroundCache.enabled = false`) and print, per region and
   season, cold (no disk cache), first visit (writes the cache) and second visit (reads it) ms. Paste the table in the
   commit message. Target: every second visit < 120 ms, and no first visit slower than today by more than 15 ms.
4. Tests `tests/unit/test_ground_cache.gd`: a cached load is byte-identical to a cold build (`get_data()` equal) for
   qingshi_village Summer and fallen_star_market Winter; changing one input (season, or one zone) changes the key;
   a corrupt file (write 10 junk bytes to the path) falls back to a cold build and rewrites the file; `enabled = false`
   never touches `user://cache`. Tests must clean up `user://cache/ground` afterwards (QA-216: tests leave no trace;
   better: point the cache dir at a test dir via a `static var dir := "user://cache/ground"` you override in the test).
5. Settings/saves are untouched; nothing in SaveManager changes. Document the cache in docs/HANDOFF.md (one paragraph).

## Edge cases
- Deterministic inputs only: if any pass reads a value not in the key (e.g. the current weather), the cache would show
  stale ground. Grep every pass for inputs and list them in the key's comment.
- Rain puddles, decor and props draw on top in other nodes and are not part of the ground texture: unaffected.
- Never cache in exported builds' `res://`; only `user://`.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED; the commit pastes the load-time table; a first-hour shot of Qingshi and
fallen_star_market `--season=Winter` rendered twice (cold, then cached) looks identical (open both).
