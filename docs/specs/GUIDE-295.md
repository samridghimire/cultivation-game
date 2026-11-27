# GUIDE-295 / GUIDE-296 / GUIDE-297: the firsts that never happen

Planner 2026-11-27 06:10. Shared method for three parallel systems tasks. Reference game: Stardew Valley's first season
(every early system is met within the first weeks because the game points at it at the right moment), mechanics only.

## The finding
`docs/specs/SIM-037-result.md` (`simulate_first_hour.gd -- --firsts`, hints policy, Qingshi, 6 seeds x 6 months):
first technique, first season task, first lecture, first congratulation and first shared meditation are **never** reached.
The longest dead stretches (median 38-39 days) are days 0-45 and 60-90, mostly meditation.

Before changing the game, find out whether each "never" is real. `_run_firsts` (tests/sim/simulate_first_hour.gd ~651) sets
only `hints_policy`, `start_region = ""` and `sect_report`. Several policy switches that model "the player does what the
Next-steps card says" stay off there: `FirstHour.weekly_extras` (SIM-033: lecture / style-teacher line in the same week as a
1-day kindness), `FirstHour.season_tasks`, and possibly others (see the static vars at the top of tests/sim/first_hour.gd).

## Method (each task does this for its own first)
1. Run `--firsts 6 6` once on clean main and copy the row for your first (the "before").
2. Trace seed 1 week by week (`FirstHour.record_weeks = true` and print `week_trace`, or add a `--firsts-trace=<seed>`
   flag that prints day, acted kind and the top 4 Next-steps lines per week up to your first or day 180).
3. Classify:
   - **Sim gap**: the line for your first is in the top 3 Next-steps lines on some week, but `_act_on_hint`
     (tests/sim/first_hour.gd) does not act on it or a policy switch is off. Fix the sim: turn the switch on in
     `_run_firsts` (only switches that model following a shown line, never an omniscient one) or teach `_act_on_hint` the line.
   - **Game gap**: the line never reaches the top 3 when your first is reachable (or never shows at all). Fix the game in
     `src/core/systems/guidance.gd` (ranking or a missing line), the smallest change that puts the right line in front of a
     player at the right moment, with a unit test in tests/unit/test_guidance*.gd that builds the state and asserts the
     line is among the first 3.
   - Both can be true; fix both.
4. Re-run `--firsts 6 6`. Put the before/after row, the classification and the trace excerpt (<= 10 lines) in the commit.
5. Keep the change under ~200 lines. If the first can't be reached without a design call (e.g. a teacher's favor gate),
   write a question with a proposed default in DESIGN.md "Open design questions" and land only the measurement and sim fix.
Hint-ranking changes count as hint changes: no `tools/balance.sh --check`, but run
`tools/balance.sh --section "first_hour_presses" --check` and `--section "quiet stretches" --check` (the hints-player
sections) and say in the commit what moved and why.

## GUIDE-295: the first technique
Target: median first technique <= day 45 in `--firsts 6 6` (today never).
Facts: Hunter Ma teaches Iron Fist free at favor 15 (C-362, a FOLK-020 lesson via `GameState._teach_lessons`), the
Wandering Merchant sells a <= 15-stone manual (C-409), and `Guidance.style_teacher` / `next_teacher_hint` produce
"<name> can teach you <style> (favor x/15)" and "No fighting style: ..." lines (short forms in guidance.gd ~726-760).
The 0-45 stretch is spent on meditation, missions and breakthrough attempts, so check where the style line ranks
against the mission and breakthrough lines while the player has no style. A newcomer without a fighting style should see
the style line (teacher with favor progress, or the manual if they can afford it) among the first 3 until they learn one.
Test: a fresh Qingshi player at favor 5 with Hunter Ma has the style line in the first 3 Next steps.

## GUIDE-296: the season's tasks
Target: median first season task set done <= day 75 (the first season is 90 days) in `--firsts 6 6`, and at least one
single task done by day 30 in 6/6 seeds (add a "first season task" row for one task if the sim only records the full set:
`EventBus.season_tasks_done` fires only when all three are done; count single-task progress from `c.season_tasks.progress`).
Facts: the journal's Today page lists the three tasks (e.g. land a Peach-Blossom Bream, gather 3 Peach Blossom Petals,
drive off a Wild Boar); the HUD's one-left line (hud.gd ~948, WU-462) shows only when one task is left;
guidance.gd ~547 has a season-task source. In Qingshi, a task the player can do today with what they have (in the region,
no item missing) should appear in the Next steps at least once a week until done, ranked under the main goal and an easy
fight but above meditation filler. Test: day 3 in Qingshi with the spring tasks untouched lists one season-task line in the
first 3 lines; once all three are done the line is gone.

## GUIDE-297: the first lecture
Target: in the seeds that join a sect by day 60, a first lecture within 45 days of joining in 5/6 seeds.
Facts: the hints player joins a sect at a median day 47, `sect_report` walks it to the hall; SECT-039's lecture line
(`_lecture_hint`, guidance.gd ~1162 and ~1260, GUIDE-292 ordering) costs 2 days and pays 6 days of qi; attendance is
counted by `LifeStats "lectures_attended"`. Check whether the lecture line shows in the hall's region during an open
lecture window and whether the hints player is ever in the hall's region on those days (it may report, then walk home to
Qingshi). If the player is away, the line should say where and how far ("Lecture at <hall> in N days' walk; open until
day X") so a player can plan; if the line is right and only the sim walks away, fix the sim.
Test: a member standing in the hall region on an open lecture day sees the lecture line first or second.
