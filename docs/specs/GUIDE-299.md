# GUIDE-299: Word from home

Role: systems. Reference: Stardew Valley's letters that pull you back to town for a friend or a festival; Tale of Immortal's
home village that keeps living while you are at the sect (mechanics only, never names, story or art).

## Why
SIM-038 (docs/specs/SIM-037-result.md, "After GUIDE-295..297"): the hints player joins a sect around day 35 and never goes
back to Qingshi. First congratulation, first shared meditation and first finished season task are 0/6 seeds in 12 months,
although all three exist in the game. Nothing in the game tells a sect disciple that home has something for them:
`Guidance.congratulate_hint` and `Guidance.season_task_hint` only fire while standing in that region.

## What to build (smallest version)
1. **`Guidance.home_call_hint(c, data, people, favor, flags, region_id, today) -> String`** (pure, src/core/systems/guidance.gd,
   next to `congratulate_hint`). Fires only when all hold:
   - `region_id != SeasonTasks.REGION` (Qingshi) and `region_id != ""`, `today >= 0`;
   - `route_days(c, data, region_id, SeasonTasks.REGION)` is between 1 and `home_call.max_route_days` (data, default 8);
   - at least one reason exists:
     a. a Friend whose home region is Qingshi `FolkNews.can_congratulate(...)` with at least `route_days + 2` days left
        (use `FolkNews.journal_rows`, which already gives `days_left` and `region`);
     b. a season task in Qingshi is open (`SeasonTasks.has_open` for catch or gather) and the season has
        `<= home_call.season_days_left` days left (default 21; add `SeasonTasks.days_left_in_season(day) -> int` if
        none exists, with a unit test at a season start, middle and last day);
     c. an open Letters visit invite (`Letters.visit_flag(npc_id)` set in flags) from a Qingshi villager.
   Text, one line, at most two reasons joined by "; ", reason (a) first:
   `"Home to Qingshi (5 days): congratulate Xiao Ling on Qi Refining; 1 spring task left (14 days)"`.
   Use the same names/realm wording as `congratulate_hint`. Return "" otherwise.
2. **Rank it** in `Guidance.hints` right after the sect duty / lecture lines (it must never push the monthly duty or GUIDE-297's
   lecture line out of the first 2) and before generic cultivation lines. At most once per 7 days of being shown is NOT needed:
   it is pure and disappears when the reason does.
3. **A letter that says it** (one per reason, never more than one a month): in `Letters.monthly` (or a new
   `Letters.home_news(...)` called from the same monthly tick in GameState), when the player is outside Qingshi and reason (a)
   holds for a friend who has not written about it yet, the friend writes a `home_news` letter:
   text from data/family.json `letters.home_news_text` (default
   `"{name} writes from {region}: \"{news} Come by when the sect lets you go.\""`, `{news}` = the FolkNews line already used
   for congratulations, or "I have news I would rather tell you in person." when none). Mark it with a world flag
   `home_news_<npc_id>_<day of the news>` so it is written once per piece of news. It goes through the existing letter path
   (EventBus.letter_arrived, journal letters list). No item effects.
4. **Data**: `data/family.json` new block `"home_call": {"max_route_days": 8, "season_days_left": 21}` and
   `letters.home_news_text`; document both in that file's `_doc` and validate in `GameData._validate()` (ints >= 1,
   text contains `{name}`).
5. **Sim**: in tests/sim/first_hour.gd, with `weekly_extras` on, a sect member whose monthly duty is met for the month and who
   sees a line starting with "Home to Qingshi" travels home, acts on the Qingshi lines it then sees (congratulate,
   season task, meditate beside a friend) for up to 7 days, then travels back to the hall. Keep it in the existing
   weekly-extras style (look at how GUIDE-297 added the lecture extra).

## Tests (tests/unit/test_guidance_home_call.gd, new)
- No line in Qingshi itself; no line with no reason; no line beyond `max_route_days`.
- Reason (a): a Friend in Qingshi with fresh news -> line names them and the route days; news with fewer than
  `route_days + 2` days left -> no line.
- Reason (b): open gather task with 10 days left in the season -> "1 spring task left (10 days)"; 40 days left -> no line.
- Both reasons -> one line, congratulation first.
- Letter: one `home_news` letter for one piece of news over two monthly ticks; none while in Qingshi.
- GameState integration test in tests/unit/test_game_session.gd: a member in the hall region with a Qingshi friend's news
  sees the line in `GameState.hints()` and after travelling to Qingshi the congratulate line replaces it.
- Validation: a negative `max_route_days` is reported.

## Acceptance
- `tools/test.sh` prints ALL CHECKS PASSED.
- Run `--firsts 6 12` and paste before/after rows for first congratulation, first shared meditation and first season task
  done into the commit. Target: first congratulation reached in >= 3/6 seeds within 12 months. If missed, say why under
  `Follow-ups:` (do not tune other systems).
- No balance check needed (a hint, a letter and sim policy; no balance values change).
- Under ~400 changed lines. If the sim part grows too large, land 1-4 with tests and put 5 under `Follow-ups:`.
