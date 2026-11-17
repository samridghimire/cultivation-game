# PERF-009: A region that loads before the fade ends

Role: systems. Reference: none (Steam Deck readiness, performance). Follows PERF-008 (8289fec).

## Problem
PERF-008's `tests/sim/region_load_times.gd` shows every region over the 250 ms cold budget, and ~90% of it is
`GroundTiles.ground_texture` (src/world/ground_tiles.gd ~97): 500-1200 ms per region on an 800x500-ish image
(cold, median of 3: azure_peak 1217/1217, fallen_star_market 727/1668, misty_forest 622/642,
myriad_peaks_ridge 1001/1117, qingshi_village 707/731, withered_bone_marsh 590/673, Summer/Winter).
The cost is per-pixel `Image.get_pixel`/`set_pixel` (39 call sites) and string `hash()` per pixel in
`make_variant`, `_apply_patches`, `_apply_worn`, `_apply_style`, `_tint_image`, `_apply_season`/`_vary_snow`, and the
scree passes (`_scree_slopes`, `_alpine_life`; scree is the worst at ~1.2 s). Every travel hitches for a second.

## Do
1. Measure first. Add a `--passes` flag to `region_load_times.gd` that times each pass inside `ground_texture` for one
   region (a static `GroundTiles.profile: Dictionary` of pass name -> usec, filled only when a static
   `GroundTiles.profiling := false` flag is true; zero cost otherwise). Paste the per-pass table (before) in the commit.
2. Rewrite the three worst passes to work on the raw bytes: `var data := img.get_data()` (PackedByteArray, RGBA8,
   index `(y * w + x) * 4`), edit the bytes, then `img.set_data(w, h, false, Image.FORMAT_RGBA8, data)` once.
   Changing only memory access must keep the output **pixel-identical**. Replacing a per-pixel string `hash()` with an
   integer mix (a small static `_ihash(a: int, b: int, c: int) -> int`, like PERF-008's per-cell lattice) is allowed but
   changes the noise layout: then the look must stay statistically the same (same density of specks/patches; compare a
   Qingshi and an Azure Peak shot before/after and say so in the commit).
   Precompute per-region string seeds once (`hash(rid + "|xyz")`) outside the pixel loops.
3. Same treatment for `_tint_image` (a whole-image lerp: one byte loop) and the winter snow passes if they are in the top 4.
4. Leave `make_variant` alone if it is < 10% (it makes four 32-px tiles).

## Acceptance
- `region_load_times.gd` (cold, median of 3): every region's ground under 400 ms Summer and Winter on the container,
  and the worst region at least 2x faster than the PERF-008 numbers above. Paste the before/after table in the commit.
  If one region stays over 400 ms, say which pass and put it under `Follow-ups:`.
- A unit test `tests/unit/test_ground_perf.gd` (or extend the PERF-008 test): for qingshi_village Summer and
  myriad_peaks_ridge Winter at a small size (e.g. 192x128), the bytes of `ground_texture(...)` equal a stored
  sha256/hash of the pre-change output for every pass you kept pixel-identical (record the expected hash by running the old
  code first). For passes whose noise you changed, assert the speck/patch pixel count is within 10% of the old count.
- Render `screenshot_first_hour.gd -- --region=qingshi_village,azure_peak,myriad_peaks_ridge` at 1280x800 (Summer and
  `--season=Winter`) and open them: no visible change beyond noise layout.
- Draw-only: no change to GameState, saves or balance. No `tools/balance.sh` run needed. tools/test.sh.

## Out of scope
Building the ground off-thread or during the travel fade (a later world-ui task if this is not enough); disk caches.
