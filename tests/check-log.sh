#!/bin/sh
#
#  check-log.sh <logfile> [known-failures-file]
#
#  Turns a v2lin test log into a pass/fail verdict.
#
#  The CHK()/CHK0() macros of lib/v2ldebug.h report a failed check as
#
#      <file>:<line> <function>() ERROR: <expression>
#
#  so the set of failures in a run is the set of <expression>s in the log.
#  That set is compared against the baseline of known, pre-existing failures.
#  Only failures that are NOT in the baseline make this script fail, which
#  keeps real regressions visible without drowning them in historical noise.
#
#  Exit status: 0 = no unexpected failure, 1 = regression (or bad usage).

set -u

log=${1:-}
known=${2:-}

if [ -z "$log" ] || [ ! -f "$log" ]; then
	echo "   FAILED: no log file '$log'"
	exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Failures actually observed, normalised (prefix stripped, trailing blanks
# removed, de-duplicated).
sed -n 's/.*ERROR: //p' "$log" \
	| sed 's/[[:space:]]*$//' \
	| sort -u > "$work/seen"

# Baseline: strip comments and blank lines.
if [ -n "$known" ] && [ -f "$known" ]; then
	sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$known" \
		| grep -v '^$' \
		| sort -u > "$work/known"
else
	: > "$work/known"
fi

comm -23 "$work/seen"  "$work/known" > "$work/unexpected"
comm -13 "$work/seen"  "$work/known" > "$work/fixed"
comm -12 "$work/seen"  "$work/known" > "$work/expected"

n_unexpected=$(wc -l < "$work/unexpected")
n_expected=$(wc -l < "$work/expected")
n_fixed=$(wc -l < "$work/fixed")

[ "$n_expected" -gt 0 ] && echo "   known failures  : $n_expected (see $known)"

if [ "$n_fixed" -gt 0 ]; then
	echo "   no longer failing: $n_fixed - please remove from $known"
	sed 's/^/     + /' "$work/fixed"
fi

if [ "$n_unexpected" -gt 0 ]; then
	echo "   FAILED: $n_unexpected unexpected failure(s) in $log"
	sed 's/^/     - /' "$work/unexpected"
	exit 1
fi

echo "   PASSED"
exit 0
