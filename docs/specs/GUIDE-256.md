# GUIDE-256: Every teacher's errand reads right in the hint

Role: systems. Reference: Stardew Valley's quest log lines (mechanics only: short, specific, actionable).
C-386 gave five more teachers a once-only favor errand. `Guidance._errand_clause` (src/core/systems/guidance.gd ~3977)
was written for the only favor deed then (Hunter Ma's "Help Hunter Ma check his snare line" -> "help with his snare line
(2 days, +12 favor)", reviewer note 2026-11-17: the rewrite only reads well for "check ..." names). With the new deeds:
- "Help Xiao Ling on her water rounds" -> "help with on her water rounds (1 day, +10 favor)"  (broken)
- "Bail out Peddler Hei's leaking skiff" -> "help with bail out his leaking skiff (...)"  (awkward)
- "Sweep the fallen leaves from Bai's terraces" -> "help with sweep the fallen leaves from bai's terraces" (lower-cased
  name, verb after "help with"); "Turn the herbs on Ye's drying racks"; "Count Qian's stock in the market storehouse".

## Change
1. Optional deed field `hint` (string <= 40 chars, imperative, lower-case first word, e.g. "bail out his leaking skiff"):
   when present `_errand_clause` uses it verbatim: "<hint> (N day(s), +F favor)". Document it in data/deeds.json `_doc` and
   validate in `GameData._validate()` (string, 1..40 chars, only on deeds that have `favor`).
2. Without `hint`, build the clause from the name by lower-casing only the first letter of the deed's *verb* and keeping it
   as a verb phrase: drop a leading "Help <Name> " / "Help <Name> with " and use the rest as-is if it starts with a verb
   ("check his snare line"); otherwise use the whole name ("sweep the fallen leaves from Bai's terraces"). Never output
   "help with <verb>". Replace the NPC's own name/possessive with the pronoun as today. Proper nouns keep their capitals
   (only the first character is lower-cased).
3. Keep the 46-char fallback ("an errand for him, +12 favor").
4. Add `hint` to the five C-386 deeds and Hunter Ma's (content edit in this task; each <= 40 chars, true to the deed):
   e.g. ma_snare_line "check his snare line", ling_water_rounds "carry water on her rounds", hei_bail_skiff "bail out his
   leaking skiff", bai_sweep_terraces "sweep her terraces", ye_tend_drying_rack "turn the herbs on her racks"
   (Bai Qingwu and Ye Zhuoran are female, Peddler Hei and Broker Qian male: data/npcs.json), qian_count_stock "count his storehouse stock".
5. While here (same file): `Guidance` ~410 builds "the Lantern riddles is open" (journal Today, festival line): use
   "are open" when the contest name ends in "s" and is not a single-noun title, or rephrase to "the Lantern riddles have
   begun"/"<name>: open today". Pick the smallest change that reads right for every festival contest name in
   data (list them in the commit).

## Tests (tests/unit/test_guidance*.gd, real data)
- For each of the six teachers (npc ids from the deeds' `favor` keys), a newcomer with the errand open gets a no-style /
  teacher hint whose errand clause contains the deed's `hint` text, contains no "help with " followed by a verb from the
  set [check, bail, sweep, turn, count, carry, on], and no doubled spaces.
- A deed without `hint` named "Help X check his traps" still yields "check his traps".
- GameData validation rejects a 41-char hint and a hint on a deed without `favor`.
- The festival line for every contest in data reads without "riddles is".

## Acceptance
tools/test.sh. Wording only: no `tools/balance.sh --check`. Render `screenshot_first_hour.gd -- --region=withered_bone_marsh`
(Peddler Hei's errand in the Next-steps card if it shows) and open it.
