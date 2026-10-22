#!/usr/bin/env bash
# Balance baseline (QA-024). Runs the first-hour, combat and economy sims with fixed
# seeds and writes docs/balance_baseline.txt. Not part of test.sh.
#   tools/balance.sh          rewrite the baseline (commit it with your tuning change)
#   tools/balance.sh --check  diff a fresh run against the baseline; exit 1 on a change
#   tools/balance.sh --section "<name prefix>" [--check]
#       run only the sections whose "## " title starts with the prefix (case-insensitive); with
#       no --check the matching sections of the baseline are replaced and the others are kept
#       byte for byte. Example: tools/balance.sh --section "economy"
# Each section's wall time is printed to stderr. (QA-049: economy was ~8 min until its
# gather loop stopped rescanning every recipe per sale; sections should stay under ~3 min.)
set -euo pipefail
cd "$(dirname "$0")/.."
BASELINE=docs/balance_baseline.txt
PREFIX=""
run() {
	local title="$1"
	shift
	local lower_title lower_prefix
	lower_title=$(echo "$title" | tr 'A-Z' 'a-z')
	lower_prefix=$(echo "$PREFIX" | tr 'A-Z' 'a-z')
	if [[ -n "$PREFIX" && "$lower_title" != "$lower_prefix"* ]]; then
		return
	fi
	local started=$SECONDS
	echo "## $title"
	tools/godot.sh --headless --path . -s "$@" 2>&1 | grep -v -E "^(Godot Engine|WARNING|   at:|ERROR: .*ObjectDB)" || true
	echo
	echo "balance.sh: '$title' took $((SECONDS - started)) s" >&2
}
fresh() {
	run "first hour (seeds 1-10)" res://tests/sim/simulate_first_hour.gd -- 10
	run "first hour, curious player (seeds 1-10)" res://tests/sim/simulate_first_hour.gd -- 10 --curious
	run "log noise (seeds 1-5, 12 months)" res://tests/sim/log_noise.gd -- 5 12
	run "three curious years (seeds 1-10, 36 months)" res://tests/sim/simulate_curious_years.gd -- 10 36
	run "pill wait (curious, seeds 1-10, 36 months, wait up to 120 days)" res://tests/sim/simulate_curious_years.gd -- 10 36 --wait-for-pill=120
	run "early inheritances (curious, seeds 1-10, 36 months)" res://tests/sim/early_inheritances.gd -- 10 36
	run "fair fights (curious, seeds 1-10, 12 months)" res://tests/sim/fair_fights.gd -- 10 12
	run "first fights, rated vs real (starter character, Qi Refining layers 1-3)" res://tests/sim/first_fights_truth.gd -- 200
	run "rival story (seeds 1-10, 36 months)" res://tests/sim/rival_story.gd -- 10 36
	run "combat (200 fights per cell)" res://tests/sim/simulate_combat.gd -- 200
	run "late gates (200 fights per row)" res://tests/sim/late_gates.gd -- 200
	run "peak curve (100 fights per foe)" res://tests/sim/peak_curve.gd -- 100
	run "economy (seed defaults)" res://tests/sim/simulate_economy.gd
	run "economy, bounty hunter (seeds 1-10, 12 months)" res://tests/sim/simulate_bounty.gd -- 10 12
	run "profession income (Qi Refining, seeds 1-5, 24 months)" res://tests/sim/profession_income.gd -- 5 24
	run "crafter start (new Alchemist, seeds 1-10, 180 days)" res://tests/sim/crafter_start.gd -- 10 180
	run "crafter crafts: blacksmith (seed 1, 365 days)" res://tests/sim/crafter_start.gd -- 1 365 --prof=blacksmith
	run "crafter crafts: talisman_master (seed 1, 365 days)" res://tests/sim/crafter_start.gd -- 1 365 --prof=talisman_master
	run "crafter crafts: array_master (seed 1, 365 days)" res://tests/sim/crafter_start.gd -- 1 365 --prof=array_master
	run "crafter crafts: beast_tamer (seed 1, 365 days)" res://tests/sim/crafter_start.gd -- 1 365 --prof=beast_tamer
	run "quiet stretches (seeds 1-10, 365 days)" res://tests/sim/quiet_stretches.gd -- 10 365
	run "first Foundation Establishment year (seeds 1-10)" res://tests/sim/simulate_foundation_year.gd -- 10 2
}
CHECK=0
while [[ $# -gt 0 ]]; do
	case "$1" in
		--check) CHECK=1 ;;
		--section) shift; PREFIX="${1:?--section needs a name prefix}" ;;
		*) echo "usage: tools/balance.sh [--section \"<name prefix>\"] [--check]" >&2; exit 2 ;;
	esac
	shift
done
tmp=$(mktemp)
fresh > "$tmp"
if [[ -n "$PREFIX" && ! -s "$tmp" ]]; then
	echo "No section starts with '$PREFIX'" >&2
	rm -f "$tmp"
	exit 2
fi
# Baseline with the matching sections swapped for the fresh ones (everything else untouched).
merged=$(mktemp)
if [[ -z "$PREFIX" ]]; then
	cp "$tmp" "$merged"
else
	python3 - "$BASELINE" "$tmp" "$PREFIX" > "$merged" <<'PY'
import sys
def sections(text):
    out, cur = [], None
    for line in text.splitlines(keepends=True):
        if line.startswith("## "):
            cur = [line]
            out.append(cur)
        elif cur is not None:
            cur.append(line)
    return ["".join(x) for x in out]
base = sections(open(sys.argv[1]).read())
fresh = {s.split("\n", 1)[0]: s for s in sections(open(sys.argv[2]).read())}
done = set()
res = []
for s in base:
    t = s.split("\n", 1)[0]
    if t in fresh:
        res.append(fresh[t])
        done.add(t)
    else:
        res.append(s)
res += [s for t, s in fresh.items() if t not in done]
sys.stdout.write("".join(res))
PY
fi
if [[ $CHECK -eq 1 ]]; then
	if diff -u "$BASELINE" "$merged"; then
		echo "Balance matches $BASELINE"
		rc=0
	else
		echo "Balance changed: if intended, run tools/balance.sh and commit $BASELINE" >&2
		rc=1
	fi
else
	cp "$merged" "$BASELINE"
	echo "Wrote $BASELINE"
	rc=0
fi
rm -f "$tmp" "$merged"
exit $rc
