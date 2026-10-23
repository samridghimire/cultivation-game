# GUIDE-122: Injury, gather and armor hints lead with the action

Same reason as docs/specs/GUIDE-121.md: the HUD shows only the first 120 characters of a hint (WU-305). The 04:10 trace
(seed 53) cuts these lines before the part the player acts on:

```
Treat your injuries (Internal Injury (heals in 3 months, 3 days)): they slow your cultivation to x0.7. Left alone they c… (J)   (222 chars; price lost)
Gather 788 more qi to reach the next stage (about 3 months, 2 days of meditation here). At Cloud-Sea Cliff (2x qi) in Az… (J)   (172; the faster spot lost)
Armor would keep you standing in fights. The Heavenforge Smithy in Fallen Star Market (10 days) sells Boar Hide Jerkin f… (J)   (133; the price lost)
```

Can run in parallel with GUIDE-121 (different functions); rebase on it if it lands first. Use `Guidance.HEADLINE_CHARS`
if GUIDE-121 added it, else add it (`const HEADLINE_CHARS := 120`).

## Changes (src/core/systems/guidance.gd)
1. **Injury line** (`hints()`, ~line 37-45). New order: what to do, then why.
   `"Treat your injuries: %s. %s slow%s your cultivation to x%s.%s"`:
   - first `%s` is `heal_source(...)` as today ("the Village Clinic treats it for 39 stones", "use your Healing Salve", ...),
     or "use a healing item or see a doctor" when it is "";
   - then `", ".join(Injuries.describe(c, data))` ("Internal Injury (heals in 3 months, 3 days)") with "slows" for one
     injury, "slow" for several;
   - then the existing " Left alone they cost about ..." clause unchanged.
   Example: `Treat your injuries: the Village Clinic treats it for 39 stones. Internal Injury (heals in 3 months, 3 days) slows
   your cultivation to x0.7. Left alone they cost about 28 days of cultivation and weaken you in fights.`
   Keep the line starting with "Treat your injuries" (tests and GUIDE-099 match it).
2. **Gather line with a faster spot** (`_merge_better_qi`, ~line 1565): instead of appending
   `" At <place> in <where> it would take about <T>."`, rebuild the line so the faster place comes first:
   find `idx := out[gather].find(" (about ")`; when found, the line becomes
   `out[gather].substr(0, idx) + ": about <T> at <place> in <where>, <T_here> here."` where `<T_here>` is
   `Calendar.format_duration(days_here)`. When " (about " is missing, keep today's append. Keep the start
   "Gather N more qi to reach ..." (the merge finder and the sim use it).
   Example: `Gather 788 more qi to reach the next stage: about 19 days at Cloud-Sea Cliff (2x qi) in Azure Peak (10 days
   away), 3 months, 2 days here.`
3. **Armor lines** (`armor_hint`, `_loot_armor_hint`): change the lead "Armor would keep you standing in fights" to
   "Armor keeps you standing" in all four returns (same punctuation after it). The 04:10 trace's far line becomes
   118 characters. Update help or tests only where they match the old lead (grep the repo, including data/help.json).

## Tests (tests/unit/test_guidance.gd)
- `test_injury_line_leads_with_treatment`: QR 3rd layer in qingshi_village with internal_injury -> the line starts with
  "Treat your injuries: the Village Clinic treats it for " and the price ("stones.") occurs before `HEADLINE_CHARS`;
  with two injuries it says "slow your cultivation".
- `test_gather_line_faster_spot_first`: GUIDE-113's existing setup -> the Gather line contains ": about " and the far
  place's name occurs before `HEADLINE_CHARS`, and it ends with " here.".
- `test_armor_line_fits_headline`: GUIDE-072's far-armor setup -> the line starts with "Armor keeps you standing" and the
  price ("stones.") is within `HEADLINE_CHARS`.
- Update existing assertions that matched the old wording (grep "Armor would keep", "it would take about", "Treat your
  injuries (").

## Acceptance
- `tools/test.sh` prints ALL CHECKS PASSED.
- The seed-53 trace (`-- 1 12 --curious --trace --seed=53`) shows the three new forms; paste one of each in the commit
  message. The sim must still heal and still parse its needles (tests/sim/first_hour.gd does not match these lines today;
  check with `grep -n 'Treat\|Armor\|Gather' tests/sim/*.gd`).
- tests/sim/screenshot_screens.gd (`--hint-shot`) matches "Armor would keep" and "it would take about" as needles: update
  them to the new text, and run `xvfb-run -a tools/godot.sh --path . -s res://tests/sim/screenshot_screens.gd -- --hint-shot`
  to confirm every case still passes (pngs are not committed).
