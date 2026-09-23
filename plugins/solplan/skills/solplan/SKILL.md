---
name: solplan
description: Use GPT-5.6 Sol for a short high-quality implementation plan, then delegate the long coding/editing/testing phase to GPT-5.6 Luna. Use when the user invokes $solplan or asks to save premium-model limits on a coding task.
---

# SolPlan

Goal: minimize time/tokens spent on the expensive planning model while keeping planning quality high.

## Workflow

1. Inspect only the files needed to understand the task. Do not implement yet.
2. Produce a compact implementation plan containing:
   - goal and constraints;
   - exact files/components likely to change;
   - ordered implementation steps;
   - acceptance checks/tests;
   - important edge cases only.
3. Keep the plan concise. Do not duplicate source code into the plan.
4. Save the plan to `.solplan-plan.md` in the repository root.
5. Delegate implementation to GPT-5.6 Luna by running the bundled runner:
   - Windows PowerShell: `powershell -ExecutionPolicy Bypass -File "<plugin-root>/scripts/run-luna.ps1" ".solplan-plan.md"`
   - macOS/Linux: `bash "<plugin-root>/scripts/run-luna.sh" ".solplan-plan.md"`
6. Luna owns implementation, edits, tests, and routine debugging. Do not redo Luna's work with Sol.
7. After Luna exits, inspect only a compact `git diff --stat`, relevant test result, and unresolved errors. Avoid rereading unchanged files.
8. If Luna succeeded, report the result. If it failed because the plan is ambiguous, revise only the necessary plan section and run Luna once more.
9. Never use Sol for repetitive implementation merely because Luna's first attempt was imperfect.

## Token-saving rules

- Prefer targeted reads/searches over whole-repository scans.
- Reuse the plan instead of restating project context.
- Pass Luna the plan file and repository state, not a huge transcript.
- Keep Sol review bounded to diff/test failures.
- Do not generate new code if a small edit or reuse solves the task.
- Ask a clarification only when the missing answer materially changes implementation.
