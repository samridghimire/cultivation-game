# The agent team

How the cloud agents (claude.ai routines) build this game. Manage them at https://claude.ai/code/routines.

## Roles

| Role | Model | Schedule (UTC) | Does |
|---|---|---|---|
| **Planner** (orchestrator) | Opus 5.5 | every 6h at :10 (00, 06, 12, 18) | Owns `docs/BACKLOG.md`, `docs/CHANGELOG.md`, `docs/DESIGN.md` "Current systems". Marks tasks done from `[ID]` commits on main, writes detailed specs for the next tasks, keeps every role stocked, orders work so the game becomes playable end to end. |
| **Reviewer** | Opus 5.5 | every 6h at :40 (03, 09, 15, 21) | Reviews every commit that landed on main since `docs/REVIEW.md`'s last reviewed commit. Fixes red builds immediately (small fix or `git revert`), files P0 fix tasks for real problems, and records what it reviewed. |
| Systems worker A / B | Sonnet 5.5 | A every 2h at :05 (00, 02, ...) / B every 3h at :20 (01, 04, ...) | Game rules in `src/core`, with tests. |
| World & UI worker A / B | Sonnet 5.5 | A every 2h at :35 (00, 02, ...) / B every 3h at :50 (01, 04, ...) | Scenes, screens, gamepad UX, pixel art (GFX). |
| Content worker | Sonnet 5.5 | every 4h at :25 (02, 06, ...) | `data/*.json` content. |
| QA worker | Sonnet 5.5 | every 4h at :55 (03, 07, ...) | Bugs, missing tests, balance sims. |

## Usage budget (owner request, 2026-10-28)
At the old pace (6 workers every hour, planner and reviewer every 2h: about 168 runs a day) the plan's usage ran out after about
3 days and the agents sat idle for the rest of the week. The schedule above is about 52 runs a day (roughly a third of the cost),
so the budget lasts the whole week with a little margin. If usage still runs out early, slow the B workers first; if a lot is
left at the end of the week, speed them up. Every agent spends usage only on work that lands:
- No task for your role (all done, claimed or blocked)? Stop right away: no test run, no exploring, no "small extra" work.
- Read only the parts of BACKLOG/DESIGN/HANDOFF you need (grep for your task id), not whole files.
- Run `tools/balance.sh --check` (about 25 min) only when the change alters numbers the sim measures (balance values in data,
  formulas in `src/core`). Hint and wording changes don't need it.
- Planner: write fewer, larger tasks (one meaningful player-facing change each) instead of many one-line hint tweaks.
  Workers get fewer runs now, so each run should count.

## Flow
1. The planner writes or updates a task in BACKLOG.md with status `todo`, plus `spec` when it has a detailed implementation spec.
2. A worker claims it by pushing a branch `claude/<task-id>-<slug>` with an empty "claim" commit, builds it, runs
   `tools/test.sh`, rebases on main (`git rebase --no-keep-empty --force-rebase origin/main`, which drops the empty claim commit
   even when main hasn't moved), re-tests and pushes straight to `main`. There are no PRs. The cloud can't delete branches,
   so the hourly `cleanup-claims` GitHub Action removes claims whose task landed or that are 4h+ old.
3. The reviewer reviews what landed and fixes or reverts anything bad.
4. The planner sees `[<task-id>]` on main, marks it done, and adds the CHANGELOG line and any `Follow-ups:` from the commit message.

## Why this design (2026-10-07)
The first design had 6 agents open PRs and one integrator merge them. Every PR edited BACKLOG.md and CHANGELOG.md, so nearly all
of them conflicted. The integrator couldn't keep up, ~200 PRs piled up, and the owner had to merge them by hand. Now workers never
touch the shared docs and land their own work after testing against the latest main.

## Cloud git quirks (learned 2026-10-08)
- `git push origin HEAD:main` often prints `HTTP 403` / "remote end hung up" **even though the push landed**. Verify with
  `git fetch origin main && git log origin/main -3` before retrying or falling back.
- Deleting remote branches really is refused (403), hence the cleanup Action.

## Rules for every agent
- Never create scheduled tasks, reminders or check-ins (earlier runs created dozens of useless "safety-net check-in" routines).
- Never leave work half-landed: either `main` gets a green commit or the claim branch is deleted.
- `tools/test.sh` must print `ALL CHECKS PASSED` before anything lands on main.
