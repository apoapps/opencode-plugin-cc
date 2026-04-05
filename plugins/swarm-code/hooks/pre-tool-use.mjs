#!/usr/bin/env node
/**
 * pre-tool-use.mjs — PreToolUse guardrail hook (v3.0.0)
 *
 * Minimal: only hints when opencode-worker is spawned without model: "haiku".
 * No Bash blocking. No team_name enforcement.
 *
 * Made by Alejandro Apodaca Cordova (apoapps.com)
 */

import { readFileSync } from "node:fs";

let toolData = {};
try {
  const raw = readFileSync("/dev/stdin", { encoding: "utf8", flag: "r" });
  if (raw.trim()) toolData = JSON.parse(raw);
} catch { /* no stdin — pass through */ }

const { tool_name, tool_input } = toolData;

// Opt-out
if (process.env.SWARM_DELEGATE === "0") process.exit(0);

// Only intercept Agent tool
if (tool_name !== "Agent") process.exit(0);

const subtype = tool_input?.subagent_type ?? "";
const model   = tool_input?.model ?? "";

// Hint (not block): opencode-worker should use model: "haiku"
if (subtype.includes("opencode-worker") && model && model !== "haiku") {
  const hint = [
    `[swarm-code] Hint: opencode-worker runs best with model="haiku" (cheaper, faster).`,
    `You passed model="${model}". Proceeding anyway.`,
  ].join("\n");

  // Pass through — just print hint to stderr so Claude sees it
  process.stderr.write(hint + "\n");
}

process.exit(0);
