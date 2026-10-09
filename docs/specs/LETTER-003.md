# LETTER-003: Letters that ask for something, answered in person

Role: systems. Size: ~250 lines. Follow-up of C-053 (the `pill_request` letter sets `letter_asked_for_pills`, which nothing reads).
WU-099 adds the NPC-menu entry afterwards; this task only needs the core, GameState and journal line.

## Data (data/family.json `letters`)
- A letter kind may carry `"request": {"item": <items.json id>, "count": int >= 1, "days": int >= 1, "favor": int >= 0, "effects": {Effects keys, optional}}`.
  Document it in the file's `_doc` (append one sentence about `letters.kinds[].request`).
- Change the `pill_request` kind: remove `"effects": {"set_flag": "letter_asked_for_pills"}`, add
  `"request": {"item": "qi_gathering_pill", "count": 1, "days": 90, "favor": 10, "effects": {"alignment": 3}}`.
  grep for `letter_asked_for_pills` first; if anything reads it, keep the flag as well.

## CharacterData (src/core/character_data.gd)
- `var letter_requests: Array[Dictionary] = []`, each `{"npc_id": String, "item": String, "count": int, "until": int, "favor": int, "effects": Dictionary}`.
- to_dict / from_dict with default `[]` (old saves load with no requests; no SAVE_VERSION bump needed).

## Letters (src/core/systems/letters.gd)
- `monthly(...)`: when the rolled kind has `request` and `c.letter_requests` has no open request from that npc, append one with
  `until = today + days`. `monthly` has no `today` today: add a trailing `today: int = -1` parameter (GameState passes
  `GameClock.total_days`; when -1 use `c.age_days`, just be consistent with `expire_requests`). If the npc already has an open
  request, roll the kind anyway but skip adding (no duplicate). Return dict gets `"request": true/false`.
- `static func open_request(c: CharacterData, npc_id: String, today: int) -> Dictionary` — the open, unexpired request from `npc_id`, or {}.
- `static func check_answer(c: CharacterData, data: GameData, npc_id: String, today: int) -> String` — "" or the reason:
  "No letter from them is waiting for an answer." / "They asked for 1 Qi Gathering Pill; you have 0."
- `static func answer(c: CharacterData, data: GameData, npc_id: String, today: int, flags: Dictionary) -> Dictionary` —
  `{ok, reason, favor, notes}`: removes the items, removes the request, applies `effects` via `Effects.apply`, returns `favor`
  (GameState applies it to `npc_favor`, clamped 0..100 like `give_gift` does at game_state.gd ~1282; no festival/taste scaling).
- `static func expire_requests(c: CharacterData, today: int) -> Array[String]` — removes requests with `until < today` and returns their npc ids. No penalty.
- `static func request_lines(c: CharacterData, data: GameData, npcs: Dictionary, today: int) -> Array[String]` —
  "<Name> asked for 1 Qi Gathering Pill in a letter (N days left; give it in person in <Region>)." (region via `Npcs.region_of`).
- `validate`: a kind's `request.item` must exist in data.items, `count >= 1`, `days >= 1`, `favor >= 0`.

## GameState (src/autoload/game_state.gd)
- In the monthly letter loop (~2834) pass `GameClock.total_days`; when `letter["request"]`, append " They hope you will bring it when you pass." to the posted line.
- On the same month tick call `Letters.expire_requests` and post "<Name> no longer waits for your answer." (topic family) per id still alive in `npcs`.
- `func letter_request(npc_id: String) -> Dictionary` (thin: `Letters.open_request`), `func check_letter_request(npc_id: String) -> String`,
  `func answer_letter_request(npc_id: String) -> void`: `_can_act()`, answer, apply favor, post
  "You give <Name> the <Item> they asked for. (<Family.favor_progress>, notes...)", `player_changed`. Takes no time.
- Dead NPCs: `check_letter_request` refuses ("They are gone.") and the month tick drops requests from dead NPCs silently.

## Journal (src/core/systems/guidance.gd)
- The Errands section (GUIDE-003; grep `Errands`) lists `Letters.request_lines(...)` first.

## Tests
- tests/unit/test_letters.gd: a forced `pill_request` creates one request with the right `until`; a second forced one from the same
  npc does not duplicate; `check_answer` reasons (none / not enough items); `answer` removes items and the request, applies effects,
  returns favor 10; `expire_requests` drops past-due ones only; validation errors for an unknown item and count 0;
  `to_dict`/`from_dict` round-trip; an old dict without `letter_requests` loads with [].
- tests/unit/test_game_session.gd: GameState.answer_letter_request raises `npc_favor` and removes the pill; the journal shows the line before and not after.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED; no `letter_asked_for_pills` reader is left dangling.
