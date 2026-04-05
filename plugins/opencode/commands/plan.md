---
description: Delegate implementation planning to OpenCode — Claude directs, OpenCode drafts
argument-hint: '<what to plan>'
allowed-tools: Read, Glob, Grep, Bash, AskUserQuestion
---

<!-- Made by Alejandro Apodaca Cordova (apoapps.com) -->

Delegate architecture and implementation planning to OpenCode (auto-detected model, no hardcoded models).

Raw slash-command arguments:
`$ARGUMENTS`

Core constraint:
- This command produces a draft plan using a cheaper model.
- Claude then validates, refines, and presents the plan — adding its own expertise where MiniMax falls short.
- This is the most token-efficient way to do planning: MiniMax drafts, Claude edits.

Before delegating:
- Read the project structure (key files, directory layout) to provide context.
- If the user references specific features or files, read those first.
- Include relevant file paths and current architecture in the prompt.

Execution flow:
1. Gather context: Read 2-5 relevant files, get directory structure.
2. Compose enriched prompt using `opencode-prompting` plan template.
3. Run via bridge (auto-selects model, opens tmux window):
```bash
BRIDGE="${CLAUDE_PLUGIN_ROOT:-/Volumes/SandiskSSD/Documents/Local/dev/apoapps/cc-skills/opencode-plugin-cc/plugins/opencode}/scripts/opencode-bridge.sh"
bash "$BRIDGE" --type plan "<enriched prompt with context>"
```
4. Validate the plan:
   - Are referenced files/paths real?
   - Are suggested dependencies appropriate?
   - Are there missing steps or unrealistic assumptions?
5. Present the plan with Claude's refinements:
   - Keep MiniMax's structure.
   - Add corrections inline with `[Claude: ...]` notes.
   - If the plan is fundamentally wrong, discard and note why.

System prompt injected to OpenCode (from claude-code-sourcemap ArchitectTool):
> You are an expert software architect. Your role is to analyze technical requirements and produce clear, actionable implementation plans. These plans will be carried out by a software engineer so be specific and detailed. Do not write code. Break implementation into concrete, actionable steps.

Token economy:
- OpenCode draft: ~0 Claude tokens
- Claude validation: ~200-400 tokens
- Savings: 70-80% vs Claude planning from scratch
- Model: auto-detected via `/opencode:setup`, no hardcoded names
