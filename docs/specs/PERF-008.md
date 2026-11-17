# PERF-008: How long does a region take to load?

**Role:** systems (tooling + one fix). **Reference:** none (Steam Deck readiness).

## Why
Since GFX-130 the ground, paths, streams, scree, marsh life, hedges and lanes are generated as Images on the CPU when a
region is built (src/world/ground_tiles.gd `ground_texture`, `path_texture`, world.gd decor passes). Nobody has measured
how long a region change takes now. On a Steam Deck a travel that stalls for a second or more feels broken.

## Build
1. `tests/sim/region_load_times.gd` (extends SceneTree, headless works, no saves written): for every region in
   data/regions.json and for seasons Summer and Winter, clear `GroundTiles._cache` (add a `static func clear_cache()` if
   none), build the region the way `screenshot_first_hour.gd --region=` does, and time with `Time.get_ticks_usec()`:
   total build, `ground_texture`, `path_texture`, and the decor pass (wrap the calls in the script; do not add timing code
   to the game). Run each 3 times, print a table: region, season, median total ms, the three parts. A second table with
   the cache warm (the season unchanged, as when you re-enter).
2. Put the cold-cache table in the commit message. Budget: 250 ms cold per region on this container.
3. If any region is over budget, fix the single worst cost in that region (likely a per-pixel `get_pixel`/`set_pixel`
   loop over the whole map: switch it to `Image.get_data()`/PackedByteArray work, or compute it at half resolution and
   scale) as long as the fix is under ~150 lines and the image is pixel-identical or visually the same (render the
   region before/after at 1280x800 and open both). Report before/after numbers. Bigger fixes go under `Follow-ups:`.
4. Unit test only for a pure helper you add or change (e.g. a pixel-identical check on a small 64x64 texture before/after
   the optimisation).

## Acceptance
The script runs headless in under ~3 minutes, prints both tables, and tools/test.sh passes. No visual change.
