# HEART-001: Still the heart before a major breakthrough (systems)

**Reference:** Tale of Immortal's breakthrough preparation, where a heart-demon trial with a few choices sways the
attempt (mechanics only: a short inner vision with choices that nudge the odds; never its names, text or UI).

**Why:** the breakthrough is the spine of the game (Pillar 2) but today a major breakthrough is one button and a dice
roll. A short vision gives the moment weight and a choice, without changing average pacing (owner's pacing question
F-005d stays open, so the expected value of a sensible choice must be close to zero net change in odds; see Balance).

## Data: `data/realms.json`
Optional per-realm `heart_vision` on the realm being broken INTO, from `foundation_establishment` upward (Qi Refining
stays a plain roll). Document it in the file's `_doc`.
```json
"heart_vision": {
  "text": "As your qi gathers, the face of {rival_or_parent} rises in your mind, mocking every step you took.",
  "choices": [
    {"label": "Face it and let it pass", "check": {"attribute": "comprehension", "target": 12}, "bonus": 0.06, "fail_bonus": -0.04,
     "text": "The face thins like mist.", "fail_text": "It lingers; your breath trembles."},
    {"label": "Crush it with will", "check": {"attribute": "spirit", "target": 12}, "bonus": 0.06, "fail_bonus": -0.04, "text": "...", "fail_text": "..."},
    {"label": "Ignore it and push on", "bonus": 0.0, "text": "You push past, neither steadier nor shaken."}
  ]
}
```
- `check` is optional; it has the same shape as an encounter choice's check, so call
  `Exploration.check_chance(c, choice)` (exploration.gd:619, clamped 10-90%) on the choice dict; do not copy the math. With no `check`, the choice always gives `bonus`.
- `{rival_or_parent}` may be used in `text`: the rival's name if the player has one, else "a faceless figure" (keep it to this
  one placeholder; fill it in core, not UI).
- Validate in `GameData._validate()`: 2-4 choices, each a non-empty `label`, `bonus`/`fail_bonus` floats in [-0.15, 0.15],
  `check.attribute` an attributes.json id, `check.target` int 1-30, `fail_bonus`/`fail_text` only with `check`.
- Write visions for foundation_establishment, core_formation and nascent_soul (three choices each, genre voice, under
  220 characters of text). Content can add the rest later (note it under Follow-ups).

## Core: `src/core/systems/cultivation.gd` (or a new `HeartVision` class in `src/core/systems/heart_vision.gd`)
- `static func vision(c: CharacterData, data: GameData) -> Dictionary`: the next realm's `heart_vision` when
  `can_attempt_breakthrough(c, data)`, the next realm is a new major realm (stage rollover into realm_index+1) and
  `c.heart_seen_realm != c.realm_index + 1`; else `{}`.
- `static func choose(c: CharacterData, data: GameData, index: int, rng: RandomNumberGenerator) -> Dictionary`:
  rolls the check, sets `c.heart_bonus`, sets `c.heart_seen_realm = c.realm_index + 1`, returns
  `{text, bonus, passed}`. Invalid index -> `{}` and nothing changes.
- `CharacterData`: `heart_bonus: float = 0.0` and `heart_seen_realm: int = -1`, both in `to_dict`/`from_dict` with
  defaults (no SAVE_VERSION bump needed when defaults cover old saves; if you do bump, add the fixture per CLAUDE.md rule 5).
- `chance_breakdown` adds a term `{"label": "Heart steadied" (bonus > 0) / "Heart shaken" (< 0), "value": c.heart_bonus}`
  only when non-zero. `attempt_breakthrough` resets `heart_bonus` to 0 after the roll (like `breakthrough_bonus`);
  `heart_seen_realm` stays, so a failed attempt does not re-offer the vision (one vision per realm per life).
- NPCs never see visions (`npc` attempts skip it).

## GameState
- `func heart_vision() -> Dictionary` (wrapper) and `func face_heart_vision(index: int) -> void`: calls `choose` with
  `rng`, posts the outcome text (category "cultivation") with the change, e.g. "Your heart steadies (+6% to break
  through).", emits `player_changed`. No time passes.
- `attempt_breakthrough()` does **not** block on the vision: if the vision is pending when the player attempts, the
  attempt proceeds as today (the UI, WU-400, offers it first). This keeps sims and old flows unchanged.

## Tests (tests/unit/test_heart_vision.gd + test_game_session.gd)
- vision() is empty for Qi Refining stage-ups and for a mid-realm stage; present at Qi Refining Peak with the qi to break into Foundation.
- choose() with a check: seeded rng pass and fail paths set heart_bonus to bonus / fail_bonus; no-check choice gives bonus.
- chance_breakdown shows the term; attempt resets heart_bonus but keeps heart_seen_realm; vision() is then empty.
- to_dict/from_dict round trip; a dict without the keys loads with defaults.
- GameState integration: face_heart_vision posts one message and changes `Cultivation.breakthrough_chance` by the bonus.
- GameData validation rejects a bonus of 0.3 and a fail_bonus without a check.

## Balance
The sims never call `face_heart_vision`, so `tools/balance.sh --check` should not move; run it anyway (formula touched)
and say so. Do not change base breakthrough chances.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED; balance unchanged. Follow-ups: WU-400 shows the vision in the breakthrough screen.
