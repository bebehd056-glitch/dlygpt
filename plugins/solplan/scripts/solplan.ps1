param(
  [Parameter(Mandatory=$true, Position=0)]
  [string]$Task
)

$ErrorActionPreference = "Stop"
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
  throw "Codex CLI not found in PATH."
}

$planPath = Join-Path (Get-Location) ".solplan-plan.md"
$plannerPrompt = @"
Analyze the CURRENT repository for this task, but DO NOT edit source files.

TASK:
$Task

Create a concise implementation plan. Include:
- goal/constraints
- exact files/components likely to change
- ordered implementation steps
- tests/acceptance checks
- only important edge cases

Output ONLY the plan markdown. Do not implement.
"@

Write-Host "[SolPlan] GPT-5.6 Sol High: planning..."
& codex exec -m gpt-5.6-sol -c 'model_reasoning_effort="high"' --sandbox read-only -o $planPath $plannerPrompt
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[SolPlan] GPT-5.6 Luna: implementation..."
$runner = Join-Path $PSScriptRoot "run-luna.ps1"
& powershell -ExecutionPolicy Bypass -File $runner $planPath
exit $LASTEXITCODE
