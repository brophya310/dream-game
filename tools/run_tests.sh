#!/bin/sh
# Runs every test scene in tests/ headless and reports which passed.
# Usage: GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run_tests.sh [test_name ...]
# Exits non-zero if any test fails or times out.

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
TIME_LIMIT="${TIME_LIMIT:-150}"
cd "$(dirname "$0")/.." || exit 1

if [ ! -x "$GODOT" ]; then
	echo "Godot not found at $GODOT (set GODOT=/path/to/Godot)"
	exit 1
fi

# Refresh imports and the class list so new scripts are found.
"$GODOT" --headless --path . --import >/dev/null 2>&1

if [ $# -gt 0 ]; then
	tests="$*"
else
	tests=$(ls tests/*.tscn | xargs -n1 basename | sed 's/\.tscn$//')
fi

failed=0
for test in $tests; do
	log=$(mktemp)
	"$GODOT" --headless --path . --fixed-fps 60 "res://tests/$test.tscn" >"$log" 2>&1 &
	pid=$!
	waited=0
	while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$TIME_LIMIT" ]; do
		sleep 1
		waited=$((waited + 1))
	done
	if kill -0 "$pid" 2>/dev/null; then
		kill "$pid"
		echo "TIMEOUT $test"
		failed=1
	else
		wait "$pid"
		code=$?
		grep -v "^Godot Engine" "$log" | grep -v "^$"
		if [ "$code" -ne 0 ]; then
			failed=1
		fi
	fi
	rm -f "$log"
done

if [ "$failed" -ne 0 ]; then
	echo "SOME TESTS FAILED"
	exit 1
fi
echo "ALL TESTS PASSED"
