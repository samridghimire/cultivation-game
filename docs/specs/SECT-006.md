# SECT-006: Chores at your own sect hall

Role: systems (with a little data). Reference: Tale of Immortal's sect daily tasks (mechanics only: small, safe, repeatable
jobs inside the sect that pay contribution, next to the bigger mission board). Size: one run (~250 lines with tests).
Depends on GUIDE-235 (`Sects.contribution_value`) for the Earning-card value; if GUIDE-235 is not on main yet, do steps
1-4 and 6 and leave step 5 under `Follow-ups:`.

## Why
- A new Outer Disciple's only sect work is the mission board: 3-15 day trips, many with a fight. There is nothing small and
  safe to do at the hall, so the sect home (Azure Peak just got its mountain look in GFX-113) has no daily life.
- Contribution earned by any means already counts toward the monthly duty (`Sects.add_contribution` adds to
  `month_earned`), so chores give a disciple a gentle way to meet the duty without travelling.

## Build
1. **`requires.sect` on deeds** (src/core/systems/deeds.gd `check` ~34 and the validation loop ~79):
   - New optional key `sect`: a sects.json id, or `"any"` (any sect member). `check` returns
     `"Only disciples of the <Sect Name> may do this."` (or `"Only sect disciples may do this."` for "any") when the
     player is rogue or in another sect. Use `c.is_rogue()` and `c.sect["id"]`.
   - Validation: add `"sect"` to the known requirement keys; an unknown sect id is an error. Document it in the
     deeds.json `_doc` sentence that lists `requires` keys.
2. **A steward at each sect home** (data/regions.json): one `deed_giver` place per sect hall that belongs to a sect,
   placed inside or beside the hall court (look at the hall's pos/size and keep 40+ px from other places; there are
   place-overlap tests, run them):
   - Azure Peak, near Azure Cloud Hall (980, 730): "Hall Steward Qiu", `deed_context: "azure_steward"`, look like other
     robed NPCs with the sect's robe colour (sects.json `robe_color`).
   - Withered Bone Marsh, near Blood Lotus Reed Hall (450, 230): "Reed Hall Overseer", `deed_context: "lotus_steward"`.
   - Fallen Star Market, near the Sect Envoy Hall (1200, 750): "Pavilion Clerk", `deed_context: "pavilion_steward"` (the
     Myriad Treasure Pavilion's home region; the envoy hall itself serves every sect, the clerk serves only Pavilion
     members).
3. **Two chores per steward** (data/deeds.json), all with `requires.sect` set to that sect, no `enemy`, `alignment >= 0`
   (Blood Lotus chores use alignment 0: GUIDE-230 hides alignment-cost work from the Earning card), `witnessed: true`:
   - a 1-day chore: `cooldown_days: 3`, effects `{"contribution": 5, "items": {"spirit_stone": 1}}`
   - a 2-day chore: `cooldown_days: 7`, effects `{"contribution": 12, "items": {"spirit_stone": 2}}`
   Names in the sect's voice, <= 60 chars, e.g. Azure: "Sweep the cloud-stair and trim the lanterns", "Tend the
   Cloud-Sea Orchid Terraces"; Blood Lotus: "Skim the blood-lotus pools", "Walk the reed paths at night"; Pavilion:
   "Copy the ledgers for the night market", "Inventory the Pavilion's storerooms". Optional `text` if deeds have one.
   That is at most ~98 contribution a month if a player does nothing else: well below the mission board (gather_dew_grass
   pays ~8 a day) and the Inner Disciple threshold (400-600), so promotion pace barely moves.
4. **Hint**: Guidance's sect duty reminder (guidance.gd ~3120, `Sects.duty_reminder`): when the duty is unmet and the
   player stands in their sect's home region and a steward chore passes `Deeds.check`, the reminder may name it:
   "Duty: 12 more contribution this month. Hall Steward Qiu has chores (5 contribution a day)." Keep the existing text
   otherwise.
5. **Earning card**: `Earnings.earning_options` (earnings.gd ~20) skips deeds with no stones; let a chore count when it
   pays stones OR contribution, valuing contribution with GUIDE-235's `Sects.contribution_value(data, sect_id)` (rogue:
   not offered anyway, `Deeds.check` fails). The row keeps kind "chore" and gains `"contribution": n`; `Earnings.lines`
   appends ", +N contribution" for it, like the mission row.
6. No save change: cooldowns use the existing `c.deed_days`.

## Tests
- tests/unit/test_deeds.gd (or the file that tests `Deeds.check`): `requires.sect` refuses a rogue and a member of another
  sect with the right reason, accepts a member; `"any"` accepts any member; validation rejects an unknown sect id.
- tests/unit/test_earnings.gd: an Azure Outer Disciple in azure_peak gets a chore row naming the steward with
  `contribution > 0`; a rogue there gets none; after doing the 1-day chore the row moves to the 2-day chore or disappears
  for 3 days.
- tests/unit/test_game_session.gd: a GameState integration test: an Azure disciple performs the steward chore through the
  same call the deed menu uses; contribution and `Sects.duty_progress` rise by 5, one day passes.
- Every region's place-overlap / label keep-out tests still pass.

## Acceptance
- `tools/test.sh` prints ALL CHECKS PASSED.
- Render `--region=azure_peak` at 1280x720 and open it: the steward stands at the hall court without covering the stairs
  or another label.
- Commit `[SECT-006] Chores at your own sect hall`. Balance: chores are opt-in and the sims do not take them, so no
  `tools/balance.sh --check` is needed; say so in the commit.
