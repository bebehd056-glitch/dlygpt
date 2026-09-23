param(
  [Parameter(Mandatory=$false, Position=0)]
  [string]$PlanFile = ".solplan-plan.md"
)

$ErrorActionPreference = "Stop"
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
  throw "Codex CLI not found in PATH."
}
if (-not (Test-Path $PlanFile)) {
  throw "Plan file not found: $PlanFile"
}

$plan = Get-Content -Raw -Encoding UTF8 $PlanFile
$prompt = @"
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
$plan
"@

& codex exec -m gpt-5.6-luna -c 'model_reasoning_effort="medium"' --full-auto $prompt
exit $LASTEXITCODE
