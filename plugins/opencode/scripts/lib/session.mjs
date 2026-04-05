/**
 * opencode-session.mjs — HTTP session manager for opencode serve
 *
 * Manages a persistent opencode server + session so Claude and the user
 * share the same running instance. Claude sends via HTTP API; user sees
 * live output via `opencode attach <url>` in the tmux pane.
 *
 * State persisted at: /tmp/oc-bridge-state.json
 * { url, sessionID, pid, cwd }
 */

import { spawn, execSync } from "node:child_process";
import { readFileSync, writeFileSync, existsSync, unlinkSync } from "node:fs";

const STATE_FILE = "/tmp/oc-bridge-state.json";
const SERVER_READY_RE = /opencode server listening on (http:\/\/\S+)/;
const SERVER_START_TIMEOUT_MS = 12_000;

// ─── State helpers ─────────────────────────────────────────────────────────

function readState() {
  try {
    return existsSync(STATE_FILE) ? JSON.parse(readFileSync(STATE_FILE, "utf8")) : null;
  } catch {
    return null;
  }
}

function saveState(state) {
  writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

function clearState() {
  if (existsSync(STATE_FILE)) unlinkSync(STATE_FILE);
}

// ─── Server health check ────────────────────────────────────────────────────

async function isServerAlive(url) {
  try {
    const res = await fetch(`${url}/session`, { signal: AbortSignal.timeout(2000) });
    return res.ok || res.status < 500;
  } catch {
    return false;
  }
}

// ─── Start opencode serve ───────────────────────────────────────────────────

export async function ensureServer(cwd = process.cwd()) {
  const state = readState();

  // Reuse if server still alive
  if (state?.url && state.cwd === cwd) {
    if (await isServerAlive(state.url)) {
      return state;
    }
    // Server died — clear state and restart
    clearState();
  }

  // Start new server
  const url = await startServer(cwd);
  const sessionID = await createSession(url, cwd);
  const newState = { url, sessionID, cwd, startedAt: Date.now() };
  saveState(newState);
  return newState;
}

function startServer(cwd) {
  return new Promise((resolve, reject) => {
    const child = spawn("opencode", ["serve", "--port", "0"], {
      cwd,
      stdio: ["ignore", "pipe", "pipe"],
      detached: true,
    });

    let buf = "";
    const onData = (chunk) => {
      buf += chunk.toString();
      const m = SERVER_READY_RE.exec(buf);
      if (m) {
        clearTimeout(timer);
        child.stdout.off("data", onData);
        child.stderr.off("data", onData);
        child.unref();
        resolve(m[1]);
      }
    };

    child.stdout.on("data", onData);
    child.stderr.on("data", onData);
    child.on("error", reject);

    const timer = setTimeout(() => {
      reject(new Error(`opencode serve did not start within ${SERVER_START_TIMEOUT_MS}ms`));
    }, SERVER_START_TIMEOUT_MS);
  });
}

// ─── Session management ─────────────────────────────────────────────────────

async function createSession(url, cwd) {
  const res = await fetch(`${url}/session`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ cwd }),
  });
  if (!res.ok) throw new Error(`Failed to create session: ${res.status}`);
  const session = await res.json();
  return session.id;
}

// ─── Send message ───────────────────────────────────────────────────────────

/**
 * Send a message to the running session and collect the full text response.
 * @param {string} url   - server URL
 * @param {string} sid   - session ID
 * @param {string} text  - message text
 * @returns {Promise<string>} - assistant response text
 */
export async function sendMessage(url, sid, text) {
  const body = {
    parts: [{ type: "text", text }],
  };

  const res = await fetch(`${url}/session/${sid}/message`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text().catch(() => "unknown error");
    throw new Error(`sendMessage failed (${res.status}): ${err}`);
  }

  const data = await res.json();

  // Extract text from assistant parts
  const parts = data?.parts ?? [];
  return parts
    .filter((p) => p.type === "text")
    .map((p) => p.text ?? "")
    .join("")
    .trim();
}

// ─── Get server state (for bridge/attach) ──────────────────────────────────

export { readState, saveState, clearState, isServerAlive };
