#!/usr/bin/env bash
# Stop hook that triggers the maintain-docs skill after every turn.
#
# Mechanism: returns a "block" decision with a reason instructing Claude to
# invoke the maintain-docs skill silently. Loop is prevented via the
# stop_hook_active flag — on the re-entry stop after the skill finishes,
# we exit 0 silently and let Claude actually stop.
#
# JSON parsing uses grep (no jq dependency — Git Bash on Windows lacks it).

set -eu

input=$(cat)

if printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

cat <<'JSON'
{"decision":"block","reason":"Invoke the maintain-docs skill now and run it silently. Review this turn for findings / new or altered code worth capturing in .claude/docs/, then apply the consolidated doc edits if any. Emit output to the main thread ONLY if documentation was actually updated (use the Step 6 report format). If nothing is worth documenting, end silently — do NOT emit a start message and do NOT emit a no-change message."}
JSON
