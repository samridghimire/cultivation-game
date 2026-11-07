# COOK-001: Dishes friends teach

Role: systems. Reference: Stardew Valley's recipes that friends send you once you are close (mechanics only: a dish is
locked until someone teaches it, then it shows up at the stove). Also fixes the review note on `shorten_injury`.

## Why
C-321 wanted Xiao Ling to teach a dish, but every home meal is known from day one (`learn_recipe` only reads alchemy
recipes), so she hands out bowls instead. The workshop's Cook list also shows all 13 meals to a newcomer, most of them
greyed out. A dish you learn from a friend is a small, warm reward and keeps the Cook list short at the start.

## Data (data/recipes.json `home_meals`)
- New optional field `taught: bool` (default false). A taught meal is hidden from the Cook lists and cannot be cooked until
  the player knows it. Document it in the `home_meals` part of recipes.json `_doc`.
- Mark these taught: `honey_egg_cake`, `egg_custard`, `boar_roast`, `frostbell_tea` (C-325 hands them to teachers; until
  then a test grants them). Leave the other 9 known, so nothing a new player could cook before disappears except these 4.
  If a balance sim cooks one of them (grep tests/sim for the ids), give the sim the dish through `learn_dish` first.

## Core
- `CharacterData.known_dishes: Array[String]` (default []), in to_dict/from_dict (missing key = []). No SAVE_VERSION bump
  needed (defaulted field); if you bump anyway, add the fixture per CLAUDE.md rule 5.
- `Cooking.is_known(c, data, meal_id) -> bool`: true when the meal is not `taught` or its id is in `known_dishes`.
- `Cooking.check`: an unknown taught meal returns "You have not learned to cook that." (before the ingredient check).
- `Cooking.learn(c, data, meal_id) -> bool`: false if the meal does not exist, is not taught, or is already known.
- `Cooking.known_meals(c, data) -> Array[Dictionary]`: home_meals filtered by is_known, in data order.
- New Effects key `learn_dish: String` (a home_meals id that has `taught: true`):
  - document it in effects.gd's key list, add it to the allowed keys list (~line 241), validate the id (exists and is
    taught) in the effects validator;
  - `Effects.check`: "You already know how to cook <name>." when known;
  - apply: `Cooking.learn` then note "Learned to cook <name>".
  - Allow it in npcs.json `lessons` effects (the FOLK-020 allowed list in Folk/GameData validation and npcs.json `_doc`).
- Every list of meals the player sees uses `Cooking.known_meals`: `Workshop.cook_options` (workshop.gd ~37, also used by the
  Family Home), the Guidance lines that loop `data.home_meals` (guidance.gd ~4417, ~4451, ~5222) so hints never name a
  dish you cannot cook. `milestones.gd:79` keeps counting all meals (a milestone about dishes cooked is fine).

## Review fix in the same task
`Effects.apply` posts "injuries ease by N days" even when the eater has no injury (Clear Well Tea drunk while healthy).
Only add that note when `Injuries.has_any(c)` was true before shortening. Test it.

## Tests (tests/unit/test_cooking.gd, extend or create)
- a taught meal is hidden from `known_meals` and `check` refuses it; after `learn` it is listed and cooks;
- `learn` twice returns false the second time; `learn` of an untaught or unknown id returns false;
- `known_dishes` round-trips through to_dict/from_dict, and a dict without the key loads as [];
- effects: `learn_dish` applies with the note, `check` refuses a known dish, validation rejects an unknown or non-taught id;
- `Workshop.cook_options` (static) omits an unknown taught meal;
- shorten_injury on a healthy character posts no "injuries ease" note;
- GameState integration: a lesson with `learn_dish` taught through the FOLK-020 path adds the dish (tests/unit/test_game_session.gd
  style, or the existing lesson test file).

## Acceptance
- A new character's workshop Cook list has 9 entries, not 13; after learning Honey Egg Cake it has 10.
- `tools/test.sh` prints ALL CHECKS PASSED. No balance run needed unless a sim cooks one of the 4 dishes.
- Follow-ups for C-325 in the commit message.
