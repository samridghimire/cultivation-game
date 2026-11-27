# SIM-037: the first season as a list of firsts

Hints policy, Qingshi start, 6 seeds, 6 months. Days are counted from day 0; `never` means the sim did not reach it.

| first | seed 1 | seed 2 | seed 3 | seed 4 | seed 5 | seed 6 | median |
|---|---|---|---|---|---|---|---|
| talk to Elder Mo | 3 | 3 | 3 | 3 | 3 | 3 | 3 |
| first chore paid | 3 | 3 | 3 | 3 | 3 | 3 | 3 |
| first fight won | 6 | 6 | 6 | 6 | 6 | 6 | 6 |
| first technique | never | never | never | never | never | never | never |
| first Acquaintance | 127 | 101 | 126 | 107 | 112 | 40 | 112 |
| first Friend | 162 | 136 | 161 | 142 | 140 | 80 | 142 |
| first stage up | 45 | 18 | 44 | 18 | 37 | 130 | 44 |
| sect joined | 48 | 21 | 47 | 21 | 40 | 133 | 47 |
| first lecture | never | never | never | never | never | never | never |
| first congratulation | never | never | never | never | never | never | never |
| first shared meditation | never | never | never | never | never | never | never |
| first season task done | never | never | never | never | never | never | never |

## Dead stretches (14+ days with no first and no stage change)

| seed | days | length | top action kinds |
|---|---|---|---|
| 4 | 21-85 | 64 | missions 28d, meditation 23d, travel 7d |
| 6 | 80-130 | 50 | meditation 37d, other:attempt_breakthrough 7d, other:call_on 6d |
| 6 | 40-80 | 40 | meditation 27d, other:attempt_breakthrough 7d, other:lend_a_hand 6d |
| 1 | 87-127 | 40 | meditation 24d, missions 10d, other:lend_a_hand 5d |
| 3 | 86-125 | 39 | meditation 24d, missions 10d, other:lend_a_hand 4d |
| 3 | 47-86 | 39 | missions 19d, meditation 10d, travel 7d |
| 1 | 48-87 | 39 | missions 19d, meditation 10d, travel 7d |
| 1 | 6-45 | 39 | meditation 16d, other:attempt_breakthrough 14d, other:lend_a_hand 8d |
| 3 | 6-44 | 38 | meditation 15d, other:attempt_breakthrough 14d, other:lend_a_hand 8d |
| 2 | 21-56 | 35 | missions 19d, travel 7d, meditation 5d |
| 6 | 6-40 | 34 | meditation 18d, other:lend_a_hand 8d, other:attempt_breakthrough 7d |
| 5 | 40-74 | 34 | missions 19d, travel 7d, meditation 5d |
| 3 | 126-160 | 34 | meditation 30d, other:lend_a_hand 4d |
| 6 | 133-165 | 32 | missions 17d, travel 7d, meditation 5d |
| 5 | 6-37 | 31 | other:attempt_breakthrough 14d, other:lend_a_hand 8d, meditation 8d |
| 2 | 56-86 | 30 | meditation 17d, missions 10d, other:lend_a_hand 2d |
| 5 | 74-104 | 30 | meditation 17d, missions 10d, other:lend_a_hand 2d |
| 1 | 133-162 | 29 | meditation 24d, other:lend_a_hand 5d |
| 4 | 142-169 | 27 | meditation 24d, other:call_on 3d |
| 2 | 101-128 | 27 | meditation 24d, other:lend_a_hand 3d |
| 4 | 85-107 | 22 | meditation 18d, other:lend_a_hand 4d |
| 5 | 118-140 | 22 | meditation 18d, other:lend_a_hand 4d |
| 4 | 107-127 | 20 | meditation 18d, other:lend_a_hand 2d |
| 2 | 136-156 | 20 | meditation 18d, other:call_on 2d |
| 4 | 127-142 | 15 | meditation 12d, other:lend_a_hand 3d |
| 5 | 146-160 | 14 | meditation 12d, other:call_on 2d |
| 2 | 156-170 | 14 | meditation 12d, other:call_on 2d |
| 2 | 86-100 | 14 | meditation 12d, other:lend_a_hand 2d |

Summary: the two stretches that recur most across 6 seeds (by median length, seeds hit):
- starting around day 60-89: median 39 days in 6 seeds; the sim was doing: meditation 37d, other:attempt_breakthrough 7d, other:call_on 6d / meditation 24d, missions 10d, other:lend_a_hand 5d.
- starting around day 0-29: median 38 days in 6 seeds; the sim was doing: missions 28d, meditation 23d, travel 7d / meditation 16d, other:attempt_breakthrough 14d, other:lend_a_hand 8d.

## Reading it

Days are stamped at the first clock jump that shows them, so the day-0 talk and chores read as day 3. The two longest dead stretches (median 39 and 38 days) are days 0-45, where the sim spends its time on missions and meditation and a breakthrough attempt, and days 60-90, where it meditates almost the whole stretch (24-37 days of meditation, a mission or two, lend-a-hand). Both end only when a stage up or the sect join lands. Five firsts are never reached in 6 months by the hints player: first technique, first lecture, first congratulation, first shared meditation and first season task. The first Acquaintance and Friend come late (median day 112 and 142), which leaves days 90-170 as a meditation-only stretch. GUIDE-295 should look at the sect-lecture and technique firsts, since the sim never takes them.


## After GUIDE-295..297 (SIM-038, 2026-11-27)

`--firsts 6 6` and `--firsts 6 12` on main (hints policy, Qingshi start, 6 seeds). Medians; the run itself is unchanged by this task.

| first | median day | note |
|---|---|---|
| talk to Elder Mo / first chore / first fight | 3 / 3 / 6 | all seeds |
| first technique | 15 | all seeds (was never in 6 months) |
| first Acquaintance | 16 | seed 1 day 27, others 16 (was 112 in SIM-037) |
| first stage up | 32 | 25-45 |
| sect joined | 35 | 28-48 |
| first lecture | 48 | 44-57, i.e. 13-16 days after joining (target 45 met) |
| first season task (seen) | 24 | 18-28 |
| first Friend | never | seed 5 day 45; seed 6 day 322 (12 months) |
| first congratulation | never | 0/6 even in 12 months |
| first shared meditation | never | 0/6 |
| first season task done | never | 0/6 |

Five longest dead stretches (12 months):

| seed | days | length | sim did |
|---|---|---|---|
| 4 | 69-199 | 130 | practice_technique 84d, meditation 35d, missions 10d |
| 6 | 76-199 | 123 | practice_technique 35d, meditation 35d, missions 20d |
| 1 | 68-180 | 112 | practice_technique 70d, meditation 31d, missions 10d |
| 3 | 66-171 | 105 | practice_technique 70d, meditation 24d, missions 10d |
| 2 | 68-157 | 89 | practice_technique 63d, meditation 13d, missions 12d |

Reading: GUIDE-295 and GUIDE-297 worked (first technique day 15, first lecture within about two weeks of joining), and the first Acquaintance is now day 16, not 112: GUIDE-282's 41-50 was measured before the sect move, but here the Acquaintance comes before the sect (day 28-48), so joining and leaving Qingshi is not what delayed it; the earlier 112 was the old policy. The new hole is days ~68-200 in five of six seeds: after the sect lecture the sim spends 35-84 days in practice_technique, which gives none of the tracked firsts. Practising looks like a policy loop (the technique keeps being chosen after mastery or cap), not a game gap. The three firsts that still never happen (congratulation, shared meditation, season task done) all need a Friend or a Qingshi return, and the sim has left Qingshi by day 35.

Follow-ups: GUIDE-298 should target the days 68-200 stretch: first check why `practice_technique` is picked for 35-84 days (cap reached? no better action ranked?) and fix in `_run_firsts` or the hint ranking. Then the sim should go back to Qingshi for the season task / Friend firsts after joining.
