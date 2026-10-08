# GUIDE-003: Journal "Opportunities" and errands

**Why:** secret realms, inheritance grounds and C-011's favor errands are built but invisible until the player stumbles
on them. The journal (Guidance.journal, J) is the "what can I do now?" screen; it lists breakthrough, sect, deeds,
world events, commissions and milestones, but nothing about realms, inheritances or errands.

## Core: src/core/systems/guidance.gd
Add two sections to `journal()` (after "World events", before "Milestones"), each built by its own static helper:

1. `_opportunity_entries(out, c, data, flags, today)` -> section **"Opportunities"**:
   - For every secret realm in data.secret_realms that `SecretRealms.admits(c, data, def)`: if `SecretRealms.is_open(def, today)`
     add "<realm name> (<region name>) is open: <N> days left, <floors_cleared>/<floor count> floors cleared"
     (warning tone when N <= 7); else if `days_until_open <= 60` add "<realm name> (<region name>) opens in N days" (dim).
     Find the region with `SecretRealms.in_region` over data.regions (or the def's region field, whichever exists).
     Skip realms the player can never enter again (inherited / lost; reuse `status_text`'s rules).
   - For every inheritance in data.inheritances that is not `Inheritances.is_claimed` / `is_lost` and has appeared
     (`today >= _appears_day`; make a public `appears_day` if needed): "<name> (<region name>): <stages_cleared>/<stage
     count> trials passed" in normal tone, or dim with the reason from `check_attempt` when that reason is a realm or
     attribute requirement (call it with the inheritance's own region id so the "you are not there" reason never shows).
2. `_errand_entries(out, c, data, flags)` -> section **"Errands"**:
   - New data: an optional top-level `"errands"` array in **data/npcs.json** (document it in `_doc`): `{"npc": <named npc
     id>, "asked_flag": "errand_lan_asked", "done_flag": "errand_lan_done", "text": "Herbalist Lan asked for 5 Qi Condensing
     Grass (Misty Forest)."}`. Add the five C-011 errands (read the flags and items from data/dialogue/*.json; grep
     `errand_`). Load it in GameData as `var errands: Array = []`; validate that `npc` is a known named NPC and both flags
     are non-empty.
   - Show `text` for each errand whose asked flag is set and done flag is not.

Empty sections are not added (the journal screen already skips empty sections; check). Keep all lines free of `%`, `{`
and `<null>` (QA-026's test covers the journal for three characters; it must stay green).

## Tests (tests/unit/test_journal.gd)
- A Foundation character on a day an admitting secret realm is open gets an "Opportunities" line naming it; a mortal
  whom the realm does not admit gets none.
- A claimed inheritance (flag set) is not listed.
- With `errand_lan_asked` set the Errands section lists Lan's text; with `errand_lan_done` also set it is gone.
- GameData validation: an errand with an unknown npc is a load error.

## Acceptance
`tools/test.sh` ALL CHECKS PASSED. Commit lists the five errand texts.
