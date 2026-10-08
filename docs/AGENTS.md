# The agent team

How the 24/7 cloud agents (claude.ai routines) build this game. Manage them at https://claude.ai/code/routines.

## Roles

| Role | Model | Schedule (UTC) | Does |
|---|---|---|---|
| **Planner** (orchestrator) | Opus 5.5 | every 2h at :10 | Owns `docs/BACKLOG.md`, `docs/CHANGELOG.md`, `docs/DESIGN.md` "Current systems". Marks tasks done from `[ID]` commits on main, writes detailed specs for the next tasks, keeps every role stocked, orders work so the game becomes playable end to end. |
| **Reviewer** | Opus 5.5 | every 2h at :40 (odd hours) | Reviews every commit that landed on main since `docs/REVIEW.md`'s last reviewed commit. Fixes red builds immediately (small fix or `git revert`), files P0 fix tasks for real problems, and records what it reviewed. |
| Systems worker A / B | Sonnet 5.5 | hourly at :05 / :35 | Game rules in `src/core`, with tests. |
| World & UI worker A / B | Sonnet 5.5 | hourly at :15 / :45 | Scenes, screens, gamepad UX. |
| Content worker | Sonnet 5.5 | hourly at :25 | `data/*.json` content. |
| QA worker | Sonnet 5.5 | hourly at :55 | Bugs, missing tests, balance sims. |

## Flow
1. The planner writes or updates a task in BACKLOG.md with status `todo`, plus `spec` when it has a detailed implementation spec.
2. A worker claims it by pushing a branch `claude/<task-id>-<slug>` with an empty "claim" commit, builds it, runs
   `tools/test.sh`, rebases on main, re-tests and pushes straight to `main`. There are no PRs. The cloud can't delete branches,
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
