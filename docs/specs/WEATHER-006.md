# WEATHER-006: After the storm

Role: systems. Follow-ups of C-278 and WEATHER-005. Reference: Tale of Immortal's weather encounters, whose choices
leave a lasting mark for a while; the genre's lightning-scarred cultivator.

## Problems
1. `village_storm_stranded_peddler` (data/encounters.json) promises "his best price at the herb stall for a month" and
   sets world flag `storm_peddler_discount`, but nothing reads it, and a plain flag never expires.
2. `folk_greetings` has no weather form, so C-278 put its storm lines into `folk_tips`.
3. WEATHER-005's lightning has no way to hurt: there is no "scorched" injury (C-282 adds the data; this task makes sure
   the code path works with it).

## Changes
1. **Timed flags** (core, pure): `Effects` gains an optional effect key `flag_days: int` (>= 1, validated where
   `set_flag` is validated, documented in encounters.json `_doc`). When present, every flag in `set_flag` is stored as
   `{"until": today + flag_days}` instead of `true`. Add `static func flag_active(flags: Dictionary, key: String, today: int) -> bool`
   (in Effects or a tiny `WorldFlags` helper): true for any truthy non-Dictionary value, and for a Dictionary with
   `until` only while `today < until`. Grep every place that reads world flags with a plain truthiness check that could
   see such a value (`hidden_by_flag`, encounter `requires.flags`/`forbid_flags`, region `qi_flags`) and route them
   through `flag_active` (a Dictionary is truthy in GDScript, so an expired timed flag would otherwise count as set).
   Effects.apply needs today's day: pass it the way other day-dependent effects get it (check the signature; add a
   `today: int = -1` parameter if needed, -1 = store `true`).
2. **The peddler's discount**: data/encounters.json: add `"flag_days": 30` to the choice that sets
   `storm_peddler_discount`. Merchants: a merchant place may carry `discount_flag: {flag, buy_mult (0.5..1), tags (item
   tags it applies to)}` (regions.json `_doc` + `GameData._validate`). Qingshi's Village Herb Seller gets
   `{"flag": "storm_peddler_discount", "buy_mult": 0.8, "tags": ["herb"]}`. The price function the shop uses (where
   renown `buy_mult` and seasonal prices are applied) multiplies by it while `flag_active`. The shop's detail line says
   "Storm-day friend's price" (one string, the UI shows whatever the price function returns with a reason if that exists;
   if no reason field exists, skip the line).
3. **Greetings by weather**: `folk_greetings` may have a `weather` object `{kind: [lines]}` (family.json `_doc` + validate).
   `Folk.greeting` (WORLD-003) picks from today's weather list with the same day-hash selection when one exists for
   today's weather and the villager is warm (favor >= the warm threshold), else falls back to today's behaviour. Move
   C-278's three storm lines from `folk_tips` into `folk_greetings.weather.storm` only if they read as greetings; if
   they read as tips, leave them and write three short storm greetings instead.
4. **Lightning can sting**: no code change beyond making sure `Weather.storm_explore`'s optional `injury` path is
   covered by a test that uses a temporary injury id from the test's own data (C-282 adds the real one).

## Tests (tests/unit/test_weather_006.gd + a GameState integration test)
- `flag_active`: true, int 1, {"until": 10} at day 9 -> true; at day 10 -> false; missing -> false.
- Choosing the peddler choice on day 100 stores until 130; herb prices at the Herb Seller are x0.8 on day 129, normal on 130,
  non-herb items unaffected.
- An expired timed flag does not satisfy `hidden_by_flag` or an encounter `requires` flag.
- `Folk.greeting` on a storm day with a warm villager returns a storm line; on a clear day the old pool.
- storm_explore with a test injury id applies the injury on a lightning draw for an unrooted player.
- Old saves: world flags stay plain `true` values and still count.

No balance run (the discount only exists after a rare storm encounter; greetings are wording).
