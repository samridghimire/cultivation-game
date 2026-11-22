# SECT-032: Reporting at the hall (systems)

**Reference:** Tale of Immortal's new-disciple issue (a newly accepted disciple reports to the sect and receives their first
supplies). Mechanics only: never its names, text or layout.

**Why:** WU-602's join card ends with "First step: Walk to Azure Peak (10d) and report at the hall", but reporting is not a
thing: nothing happens when the new disciple arrives. The walk needs a payoff and the sect needs a first moment at home.

## Data (data/sects.json)
- New optional field per sect: `"welcome": {"line": String, "items": {item_id: count}}`.
  - `line`: the steward's words to a new disciple, <= 160 chars, in the sect's voice (`{player}` allowed, replaced by the
    player's name). Righteous Azure Cloud: orderly and warm; demonic Blood Lotus: cold, a test; Myriad Treasure Pavilion:
    a merchant's ledger tone.
  - `items`: 1-2 item kinds, 1-5 each, every id in data/items.json, total shop value (items' `price` x count) <= 60 stones.
    Suggested: Azure Cloud 2 `qi_gathering_pill`; Blood Lotus 1 `qi_gathering_pill` + one cheap item that fits it;
    Pavilion 1 `qi_gathering_pill` + a few spirit stones' worth of a trade good. Pick from existing items only.
- Document `welcome` in the file's `_doc`; validate in `GameData._validate()` (unknown item id, count outside 1-5, more than
  2 kinds, line over 160 chars or empty, value cap). Add a test that a bad item id is reported.

## Core (src/core/systems/sects.gd)
- `Sects.join` sets `"reported": false` in the new `c.sect` dict.
- `static func needs_report(c: CharacterData) -> bool`: not rogue and `c.sect.get("reported", true) == false`.
  **A missing key means already reported** so older saves and NPC members never get nagged (no SAVE_VERSION bump; `c.sect`
  is already saved whole: confirm in `CharacterData.to_dict`).
- `static func report(c: CharacterData, data: GameData, region_id: String) -> Dictionary`:
  `{"ok": bool, "reason": String, "items": Dictionary, "line": String}`. Fails with a reason when not needed
  ("You have already reported to the hall.") or `region_id != home_region(data, sect_id)`
  ("Report at the <hall name> in <home region>."). On success adds the items (`c.add_item`), sets `reported = true`,
  returns the formatted line. A sect with no `welcome` still succeeds with no items and a generic line
  ("The steward records your name in the disciple roll.").
- `Sects.leave` already clears the dict, so leave + rejoin asks for a new report (fine: rejoining is costly anyway).

## GameState (src/autoload/game_state.gd)
- `func report_to_sect() -> void`: `EventBus.topic = "sect"`, `_can_act()`, call `Sects.report(player, data, current_region)`.
  On success post the line (category "dialogue" or "progress", whichever the hall uses) and "Received: 2 Qi Gathering Pill"
  (one post, items joined by ", "), emit the new `EventBus.sect_reported(sect_id: String, items: Dictionary)` signal (declare
  it in EventBus next to `sect_joined`), then `player_changed`. On failure post the reason as "warning". Takes no days.

## World (src/world/interactables/sect_hall.gd)
- In `get_options()`, for a member whose own hall this is (`Sects.hall_serves`) and `Sects.needs_report(player)`, insert
  **first** `{"label": "Report as a new disciple", "action": GameState.report_to_sect}`. Nothing else changes.

## Guidance (src/core/systems/guidance.gd)
- A hint while `needs_report`: in the home region "Report at the <hall name>: new disciples get their issue there.";
  elsewhere "Report at the <hall name> in <home region> (<N>d): new disciples get their issue there." (use `route_days`;
  when unreachable keep the "Find the road to" wording `sect_welcome` already uses). Place it with the other early sect hints
  and give it the priority of the newcomer goal lines so it is the top "Next steps" line for a fresh disciple.
- If the hints-player sim (`_act_on_hint`, see SIM-025/026) can map it cheaply (walk home if <= the 3-day rule or always,
  your call, then call `report_to_sect`), add a 'report' branch; otherwise list it under `Follow-ups:`.

## Tests (new tests/unit/test_sect_report.gd)
1. Join sets reported false and `needs_report` is true; a dict without the key -> false.
2. `report` away from home fails with the home reason; at home grants exactly the data's items once; a second call fails.
3. Leave then rejoin -> `needs_report` true again.
4. GameState integration: `report_to_sect` at home posts the line, emits `sect_reported` once with the items, no days pass.
5. The hint shows after joining (both in and out of the home region) and is gone after reporting.
6. GameData rejects a `welcome` with an unknown item.

## Acceptance
- tools/test.sh prints ALL CHECKS PASSED. The welcome gives at most 60 stones of items once per membership, so it barely moves
  balance; still run `tools/balance.sh --check` only if a sim player actually reports (the hints player branch), and refresh
  the sections it explains.
- WU-604 consumes `sect_reported` for a card; do not build UI here beyond the hall option.
