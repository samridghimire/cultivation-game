#!/usr/bin/env bash
# Balance baseline (QA-024). Runs the first-hour, combat and economy sims with fixed
# seeds and writes docs/balance_baseline.txt. Not part of test.sh.
#   tools/balance.sh          rewrite the baseline (commit it with your tuning change)
#   tools/balance.sh --check  diff a fresh run against the baseline; exit 1 on a change
set -euo pipefail
cd "$(dirname "$0")/.."
BASELINE=docs/balance_baseline.txt
run() {
	echo "## $1"
	shift
	tools/godot.sh --headless --path . -s "$@" 2>&1 | grep -v -E "^(Godot Engine|WARNING|   at:|ERROR: .*ObjectDB)" || true
	echo
}
fresh() {
	run "first hour (seeds 1-10)" res://tests/sim/simulate_first_hour.gd -- 10
	run "first hour, curious player (seeds 1-10)" res://tests/sim/simulate_first_hour.gd -- 10 --curious
	run "combat (200 fights per cell)" res://tests/sim/simulate_combat.gd -- 200
	run "economy (seed defaults)" res://tests/sim/simulate_economy.gd
	run "first Foundation Establishment year (seeds 1-10)" res://tests/sim/simulate_foundation_year.gd -- 10 2
}
if [[ "${1:-}" == "--check" ]]; then
	tmp=$(mktemp)
	fresh > "$tmp"
	if diff -u "$BASELINE" "$tmp"; then
		echo "Balance matches $BASELINE"
	else
		echo "Balance changed: if intended, run tools/balance.sh and commit $BASELINE" >&2
		rm -f "$tmp"
		exit 1
	fi
	rm -f "$tmp"
else
	fresh > "$BASELINE"
	echo "Wrote $BASELINE"
fi
