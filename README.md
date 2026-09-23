# SolPlan for Codex

Two-stage Codex workflow inspired by Claude Code's planning workflows:

1. **GPT-5.6 Sol + high reasoning** analyzes the task and produces a compact implementation plan.
2. **GPT-5.6 Luna** executes that plan and edits/tests the project.
3. Sol is kept out of the long implementation loop to reduce expensive-model usage.

## Install marketplace

```powershell
codex plugin marketplace add bebehd056-glitch/dlygpt --ref main
```

Then install/enable **solplan** from the Codex/ChatGPT Plugins Directory and invoke:

```
$solplan <your task>
```

## Direct Windows runner

If you want strict model routing from a terminal (Sol High -> Luna), clone the repo and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\plugins\solplan\scripts\solplan.ps1 "your task"
```

The runner uses your existing `codex` CLI authentication. No API key is required.

## Important

The plugin workflow can orchestrate Codex, but actual subscription/rate-limit accounting is controlled by OpenAI. This project does not bypass limits. It aims to reduce Sol usage by moving the implementation phase to Luna.
