#!/usr/bin/env bash
set -euo pipefail
PLAN_FILE="${1:-.solplan-plan.md}"
command -v codex >/dev/null 2>&1 || { echo "Codex CLI not found in PATH." >&2; exit 1; }
[[ -f "$PLAN_FILE" ]] || { echo "Plan file not found: $PLAN_FILE" >&2; exit 1; }
PLAN="$(cat "$PLAN_FILE")"
PROMPT=$(cat <<EOF
You are the implementation stage of SolPlan.
A GPT-5.6 Sol planner already analyzed the task. Implement the plan below in the CURRENT repository.

Rules:
- Do the implementation; do not spend time rewriting the plan.
- Inspect only files needed for the listed steps.
- Make minimal, coherent edits.
- Run relevant tests/build checks.
- Fix routine errors yourself.
- Do not ask for confirmation unless blocked by missing information that cannot be inferred safely.
- At the end, summarize changed files, tests, and any unresolved issue.

PLAN:
$PLAN
EOF
)
codex exec -m gpt-5.6-luna -c 'model_reasoning_effort="medium"' --full-auto "$PROMPT"
