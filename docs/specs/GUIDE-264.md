# GUIDE-264: Roads you can walk

Role: systems. Reference: Tale of Immortal's map gating (mechanics only: a locked road says what opens it).
Source: SIM-011 Follow-up: the top unactable Next-steps line is the sect-home line (x430 in 10 hint-player seeds):
"walk fails for mortals: route needs Qi Refining".

## What is wrong
The Blood Lotus Sect takes mortals (`data/sects.json` blood_lotus_sect `min_realm: mortal`), and recruits at Qingshi's
Sect Recruitment Hall. Its home, Withered Bone Marsh, is behind `{"to": "withered_bone_marsh", "days": 6, "min_realm":
"qi_refining"}` from Qingshi (and Misty Forest's route too). `Guidance.sect_home_hint` (guidance.gd ~3486) still says "Your
sect's home is Blood Lotus Reed Hall in Withered Bone Marsh: ..." every day; `route_days` returns -1 so it just drops the
"(N days by road)" part. The player clicks Travel and gets "The way to Withered Bone Marsh is too perilous before Qi Refining."
Any other hint that names a region behind a realm-gated road has the same problem (goal lines "Walk to X", far-qi/travel
hints, `_away_explore_fights`, mission/bounty lines in another region).

## Change
1. New `Guidance.route_gate(c, data, from_id, to_id) -> Dictionary`: `{}` when `route_days(...) >= 0` or both ignore-gates and
   normal are -1; else `{"realm_index": i, "realm_name": name, "days": d}` where `i` is the lowest realm index at which
   `route_days` becomes >= 0 (probe with `_with_probe(c, "realm_index", i, ...)`, i from c.realm_index+1 up) and `d` that route's days.
2. `sect_home_hint`: when gated, return "Your sect's home is %s in %s; the road opens at %s." and nothing about missions.
   It must not be among the HUD's top Next steps then: put it after every actionable line in `Guidance.hints`
   (the list at ~889 that appends `home_hint`), so the journal still shows it but the HUD's 3 lines don't (check how the HUD
   picks lines; if it takes the first N, ordering is enough).
3. Audit every hint builder that names another region and calls `route_days`/`first_hop`/`hinted_region` without
   `ignore_realm_gates`: when the target is gated for `c`, the line is dropped (if a reachable alternative exists the builder
   already picks it) or says "the road opens at <realm>". List what you changed in the commit body. Do not change travel rules.
4. A goal line that sends the player somewhere gated (e.g. "Walk to Withered Bone Marsh") gets the same "(opens at Qi Refining)"
   tail instead of "· Nd".

## Tests (tests/unit/test_guidance.gd; add a GameState integration check in test_game_session.gd only if a GameState wrapper changes)
- A mortal Blood Lotus member in Qingshi: sect_home_hint says "the road opens at Qi Refining"; it is not in the first 3 lines
  the HUD shows; at Qi Refining 1st layer it is the old line with "(6 days by road)" (or whatever route_days returns).
- route_gate: {} for an open road; realm_index of Qi Refining for qingshi -> withered_bone_marsh at mortal; {} for unknown ids.
- A goal/hint pointing at a gated region never ends in a "· Nd" days tail.

## Acceptance
- `tests/sim/first_hour.gd --hints` (SIM-011's tally): the sect-home line is no longer the top unactable line (paste before/after tally
  top 5 into the commit body).
- Wording-only change for balance purposes: `tools/balance.sh --check` not required unless a sim number moves; if the
  first-hour section changes, refresh it and say why. `tools/test.sh` green. < ~300 lines.
