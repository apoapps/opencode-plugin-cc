/**
 * Multi-agent orchestrator — decomposes complex tasks using OpenCode,
 * assigns named agents, runs in parallel, streams progress.
 *
 * Key design: OpenCode does the orchestration thinking (cheap),
 * Claude Code only validates the final synthesis (saves tokens).
 *
 * Made by Alejandro Apodaca Cordova (apoapps.com)
 */

import { executeWithRetry } from "./opencode.mjs";
import { pickAgents, agentTag, agentTagPlain, agentProgress } from "./names.mjs";
import { getConfig, upsertJob, generateJobId, writeJobFile } from "./state.mjs";

// stderr colors — never touch stdout (what Claude reads)
const C = {
  reset: '\x1b[0m', bold: '\x1b[1m', dim: '\x1b[2m',
  green: '\x1b[38;5;114m', red: '\x1b[38;5;203m',
  cyan: '\x1b[38;5;87m',   gray: '\x1b[38;5;240m',
  yellow: '\x1b[38;5;220m',
};

// Tells OpenCode it's a subagent inside Claude Code — keep responses concise
const CC_HINT = `[CONTEXT: You are a subagent running inside Claude Code. Claude will read and validate your response. Be maximally concise — no preamble, no filler. Jump to findings. Bullets + file:line refs. 400 words max.]\n\n`;

// ─── Complexity tiers → model mapping ────────────────────────────────

const COMPLEXITY_MODELS = {
  light:  null,   // uses configured default (fastest)
  medium: null,   // uses configured default
  heavy:  null,   // uses first codex/heavy model from available
  critical: null, // uses strongest available
};

/**
 * Spread models across parallel agents.
 * - Respects the user's configured priority list — never grabs random free models.
 * - Rotates through the priority list so parallel agents don't all hit the same model.
 * - Heavy/critical agents get the strongest model from the priority list.
 * @param {object[]} agents - Agent objects (with .complexity)
 * @param {object} config
 * @param {string[]} available
 */
function spreadModels(agents, config, available) {
  const priority = config.modelPriority ?? ["minimax/MiniMax-M2.7"];
  const used = [];

  for (let i = 0; i < agents.length; i++) {
    const tier = agents[i].complexity ?? "medium";
    let model;

    if (tier === "heavy" || tier === "critical") {
      // Prefer a strong/codex model from the priority list first
      const codexInPriority = priority.find(
        (m) => !used.includes(m) && m.includes("codex") && !m.includes("mini")
      );
      const codexFallback = (available ?? []).find(
        (m) => m.includes("codex") && !m.includes("mini") && !m.includes("spark")
      );
      model = codexInPriority ?? codexFallback ?? priority[0] ?? "minimax/MiniMax-M2.7";
    } else {
      // Spread across priority list — pick first unused, else cycle
      const unused = priority.find((m) => !used.includes(m));
      model = unused ?? priority[i % priority.length] ?? priority[0] ?? "minimax/MiniMax-M2.7";
    }

    agents[i].model = model;
    used.push(model);
  }
}

// ─── Task decomposition ──────────────────────────────────────────────

const DECOMPOSE_PROMPT = `You are a task decomposition engine. Break the following task into 2-5 independent sub-tasks that can be executed in parallel by different AI agents.

## Task
{{task}}

## Context
Working directory: {{cwd}}

## Rules
- Each sub-task must be self-contained and independently answerable.
- Assign a complexity: light, medium, heavy, or critical.
- Keep sub-tasks focused — one question per agent.
- If the task is simple enough for 1 agent, return just 1 sub-task.
- Maximum 5 sub-tasks.

## Output Format (strict JSON, no markdown)
[
  {"task": "description of sub-task", "complexity": "light|medium|heavy|critical", "focus": "2-3 word label"},
  ...
]

Return ONLY the JSON array. No explanation, no markdown fences.`;

/**
 * Ask OpenCode to decompose a complex task into sub-tasks.
 * Returns array of {task, complexity, focus}.
 */
export async function decompose(task, cwd, config) {
  const prompt = DECOMPOSE_PROMPT
    .replace("{{task}}", task)
    .replace("{{cwd}}", cwd);

  const priority = config.modelPriority ?? ["minimax/MiniMax-M2.7"];

  const result = await executeWithRetry(prompt, {
    fallbackModels: priority,
    timeout: 60_000,
    cwd,
    onAttempt: () => {},
    onFallback: () => {},
  });

  if (!result.success) {
    // Fallback: single agent does the whole thing
    return [{ task, complexity: "medium", focus: "full analysis" }];
  }

  try {
    // Extract JSON from output (might have extra text around it)
    const jsonMatch = result.output.match(/\[[\s\S]*\]/);
    if (!jsonMatch) {
      return [{ task, complexity: "medium", focus: "full analysis" }];
    }
    const subtasks = JSON.parse(jsonMatch[0]);
    if (!Array.isArray(subtasks) || subtasks.length === 0) {
      return [{ task, complexity: "medium", focus: "full analysis" }];
    }
    return subtasks.slice(0, 5).map((s) => ({
      task: s.task ?? task,
      complexity: ["light", "medium", "heavy", "critical"].includes(s.complexity) ? s.complexity : "medium",
      focus: s.focus ?? "analysis",
    }));
  } catch {
    return [{ task, complexity: "medium", focus: "full analysis" }];
  }
}

// ─── Parallel agent execution ────────────────────────────────────────

/**
 * Orchestrate a complex task:
 * 1. Decompose into sub-tasks (via OpenCode — cheap)
 * 2. Assign named agents with appropriate models
 * 3. Run all agents in parallel
 * 4. Stream progress updates
 * 5. Return combined results for Claude to validate
 *
 * @param {string} task - The complex task
 * @param {string} cwd - Working directory
 * @param {object} options - { onProgress, config, available }
 * @returns {Promise<OrchestratorResult>}
 */
export async function orchestrate(task, cwd, options = {}) {
  const config = options.config ?? getConfig(cwd);
  const available = config.availableModels ?? [];
  const onProgress = options.onProgress ?? ((msg) => process.stderr.write(msg + "\n"));

  const startTime = Date.now();

  // ── Phase 1: Decompose ──
  onProgress(`\n${C.cyan}${C.bold}┌─ Orchestrator ─────────────────────────────────${C.reset}`);
  onProgress(`${C.cyan}│${C.reset} ${C.dim}Analyzing task complexity...${C.reset}`);

  const subtasks = await decompose(task, cwd, config);
  const agentCount = subtasks.length;

  onProgress(`${C.cyan}│${C.reset} Decomposed into ${C.bold}${agentCount}${C.reset} sub-task${agentCount > 1 ? "s" : ""}`);

  // ── Phase 2: Assign agents ──
  const agents = pickAgents(agentCount);
  for (let i = 0; i < agents.length; i++) {
    agents[i].task = subtasks[i].task;
    agents[i].focus = subtasks[i].focus;
    agents[i].complexity = subtasks[i].complexity;
  }
  spreadModels(agents, config, available);

  onProgress(`${C.cyan}│${C.reset}`);
  onProgress(`${C.cyan}│${C.reset} Agents assigned:`);
  for (const a of agents) {
    const modelShort = a.model?.split("/").pop() ?? "default";
    onProgress(`${C.cyan}│${C.reset}   ${agentTag(a)} ${C.dim}${a.focus} (${a.complexity}) → ${modelShort}${C.reset}`);
  }
  onProgress(`${C.cyan}│${C.reset}`);
  onProgress(`${C.cyan}│${C.reset} Executing ${C.bold}${agentCount}${C.reset} agent${agentCount > 1 ? "s" : ""} in parallel...`);
  onProgress(`${C.cyan}${C.bold}└────────────────────────────────────────────────${C.reset}`);
  onProgress(``);

  // ── Phase 3: Execute in parallel ──
  const promises = agents.map(async (agent) => {
    agent.status = "running";
    agent.startedAt = Date.now();
    onProgress(agentProgress(agent, `working on: ${agent.focus}...`));

    const result = await executeWithRetry(CC_HINT + agent.task, {
      fallbackModels: [agent.model],
      timeout: 120_000,
      cwd,
      onAttempt: (n, max, model) => {
        if (n > 1) onProgress(agentProgress(agent, `retry ${n}/${max}...`));
      },
      onFallback: () => {},
    });

    agent.completedAt = Date.now();
    const elapsed = ((agent.completedAt - agent.startedAt) / 1000).toFixed(1);

    if (result.success) {
      agent.status = "done";
      agent.result = result.output;
      onProgress(agentProgress(agent, `done (${elapsed}s)`));
    } else {
      agent.status = "failed";
      agent.result = result.output || result.error || "No output";
      onProgress(agentProgress(agent, `failed (${elapsed}s)`));
    }

    return agent;
  });

  const completed = await Promise.all(promises);

  // ── Phase 4: Build synthesis ──
  const totalTime = ((Date.now() - startTime) / 1000).toFixed(1);
  const succeeded = completed.filter((a) => a.status === "done").length;
  const failed = completed.filter((a) => a.status === "failed").length;

  onProgress(``);
  onProgress(`${C.cyan}${C.bold}┌─ Results ──────────────────────────────────────${C.reset}`);
  onProgress(`${C.cyan}│${C.reset} ${C.green}${succeeded}/${agentCount}${C.reset} agents completed ${C.dim}(${totalTime}s)${C.reset}`);
  if (failed > 0) {
    onProgress(`${C.cyan}│${C.reset} ${C.red}${failed} failed${C.reset}`);
  }
  onProgress(`${C.cyan}${C.bold}└────────────────────────────────────────────────${C.reset}`);
  onProgress(``);

  // ── Build final output ──
  const sections = [];
  sections.push(`---`);
  sections.push(`**opencode** | orchestrate | ${succeeded}/${agentCount} agents | ${totalTime}s`);
  sections.push(`---`);
  sections.push(``);

  for (const agent of completed) {
    const modelShort = agent.model?.split("/").pop() ?? "default";
    const elapsed = agent.completedAt && agent.startedAt
      ? ((agent.completedAt - agent.startedAt) / 1000).toFixed(1) + "s"
      : "?";
    const statusIcon = agent.status === "done" ? "✓" : "✗";

    sections.push(`### ${agentTagPlain(agent)} ${agent.focus} ${statusIcon}`);
    sections.push(`*${agent.name} (${agent.trait}) · ${modelShort} · ${agent.complexity} · ${elapsed}*`);
    sections.push(``);

    if (agent.result) {
      // Clean OpenCode CLI decoration from output
      const cleaned = agent.result
        .replace(/\[0m/g, "")
        .replace(/> build.*\n?/g, "")
        .replace(/\x1b\[[0-9;]*m/g, "")
        .trim();
      sections.push(cleaned);
    } else {
      sections.push(`*(no output)*`);
    }
    sections.push(``);
    sections.push(`---`);
    sections.push(``);
  }

  sections.push(`**Claude**: validate these findings, resolve contradictions, and synthesize a final answer.`);

  return {
    output: sections.join("\n"),
    agents: completed,
    succeeded,
    failed,
    totalTime: parseFloat(totalTime),
    subtasks,
  };
}
