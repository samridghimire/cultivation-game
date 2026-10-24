# GUIDE-175: the rogue join line says what membership gives

**Why.** QA-158: a rogue reaches Foundation by month 36 in 3/10 seeds against 10/10 for a sect member, and the only
sect hint a rogue sees is "As a rogue cultivator you could join Azure Cloud Sect or Myriad Treasure Pavilion at the
Sect Recruitment Hall here." It never says why joining is worth it (faster qi, the monthly lecture, the Foundation pill
for contribution). Rogue stays a valid choice (DESIGN pillar 1); the line only has to make it an informed one.

## Core (src/core/systems/sects.gd)
Add, near `check_join`:

```gdscript
## GUIDE-175: what joining `sect_id` would give `c`, as verb phrases for "Members ...":
## ["gather qi x1.5", "hear Elder Feng's sword lecture each month",
##  "can claim a Foundation Establishment Pill for 250 contribution"]. Empty for an unknown sect.
static func membership_perks(c: CharacterData, data: GameData, sect_id: String) -> PackedStringArray

## "Members gather qi x1.5, hear Elder Feng's sword lecture each month and can claim a Foundation
## Establishment Pill for 250 contribution." ("" when membership_perks is empty).
static func membership_line(c: CharacterData, data: GameData, sect_id: String) -> String
```

Rules for `membership_perks`, in this order:
1. `cultivation_bonus > 1.0`: `"gather qi x%s" % String.num(bonus, 1)` (1.5 -> "x1.5", 1.2 -> "x1.2").
2. `sect.lecture` not empty: `"hear %s each month" % lecture["name"]`.
3. The best breakthrough pill for `c`'s **next** realm in the sect's `shop` (highest `breakthrough_bonus`, then
   cheapest; same choice as `Guidance.sect_pill_entry`, but reading `sect.shop` directly because `c` is a rogue and
   `Sects.shop_items` returns nothing for rogues): `"can claim %s for %d contribution" % [Text.a(name), cost]`.
   Skip it when `c` is at the final realm, or when the entry's rank (`sect.ranks[min_rank]`) has a `min_realm`
   above `c.realm_index` (GUIDE-170's rule: never promise something gated behind the breakthrough itself).
   To avoid duplicating the pick, you may extract the loop of `Guidance.sect_pill_entry` into a static helper in
   Sects that takes the shop array (`Sects.best_breakthrough_entry(data, shop, next_realm_id) -> Dictionary`) and
   call it from both; keep `sect_pill_entry`'s output identical.

`membership_line` = `"Members " + Text.join_and(perks) + "."`.

## Guidance (src/core/systems/guidance.gd, `_sect_hint`, ~1672)
In the rogue branch, after building `open` and for `c.realm_index > 0` (mortals keep `_mortal_sect_hint`):
- pick the open sect with the highest `cultivation_bonus` (ties: first in `data.sects` order);
- return today's sentence plus `" %s %s" % [sect.name, membership_line(...).trim_prefix("Members ")...]`, i.e.
  `"As a rogue cultivator you could join Azure Cloud Sect or Myriad Treasure Pavilion at the Sect Recruitment Hall here. Azure Cloud Sect members gather qi x1.5, hear Elder Feng's sword lecture each month and can claim a Foundation Establishment Pill for 250 contribution."`
  (write "<Sect name> members " + joined perks + "."; build it from `membership_perks` so the wording matches).
- When `membership_perks` is empty, keep today's line unchanged.
The opening stays first, so the HUD's 120-char cap still keeps "join Azure Cloud Sect".

Grep tests for "As a rogue cultivator you could join" first (test_guidance.gd, tests/sim/screenshot_*.gd) and update
assertions that compare the whole line (`begins_with` checks keep passing).

## Tests
tests/unit/test_sects.gd (or wherever check_join is tested):
- rogue QR8 -> `membership_perks(c, d, "azure_cloud_sect")` == the three phrases above (read the expected lecture
  name and pill cost from data rather than hard-coding where practical).
- rogue Foundation Early -> no Foundation pill phrase; Core Forming Pill only if its rank has no realm gate above
  Foundation (assert whatever data says; Elder needs Core Formation, so expect no pill phrase if that is the rank).
- Myriad Treasure Pavilion -> "gather qi x1.2" first.
- unknown sect id -> empty.
tests/unit/test_guidance.gd:
- rogue QR8 in qingshi_village -> the sect hint contains "Azure Cloud Sect members gather qi x1.5" and still begins
  "As a rogue cultivator you could join".
- a member -> no "members gather" text.
- a mortal -> `_mortal_sect_hint` text unchanged.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. Paste the QR8 rogue line from the test in the commit body.
Follow-ups for the planner: WU-362 (sect hall prompt) and C-248 (help) use `membership_line`.
