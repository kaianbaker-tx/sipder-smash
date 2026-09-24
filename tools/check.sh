#!/bin/bash
# Parse-check every GDScript file. Usage: tools/check.sh
cd "$(dirname "$0")/.."
timeout 300 godot --headless --import >/dev/null 2>&1
fail=0
for f in $(find scripts tools -name '*.gd'); do
  out=$(timeout 60 godot --headless --check-only --script "res://$f" 2>&1 | grep -E 'SCRIPT ERROR|Parse Error|ERROR: .*res://' | grep -v 'Failed to load script' | grep -vE 'Identifier not found: (Game|Fx|Sfx)$|Failed to compile depended scripts' | head -5)
  if [ -n "$out" ]; then echo "== $f"; echo "$out"; fail=1; fi
done
exit $fail
