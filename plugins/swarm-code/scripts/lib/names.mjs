/**
 * Greek mythology agent name generator.
 * Each agent gets a unique name + a short trait for personality.
 *
 * Made by Alejandro Apodaca Cordova (apoapps.com)
 */

// ANSI colors — used only on stderr (never in stdout that Claude reads)
const C = {
  reset:   '\x1b[0m',
  bold:    '\x1b[1m',
  dim:     '\x1b[2m',
  blue:    '\x1b[38;5;75m',
  cyan:    '\x1b[38;5;87m',
  green:   '\x1b[38;5;114m',
  yellow:  '\x1b[38;5;220m',
  magenta: '\x1b[38;5;213m',
  orange:  '\x1b[38;5;215m',
};
const PALETTE = [C.blue, C.cyan, C.green, C.yellow, C.magenta, C.orange];

function colorFor(name) {
  let h = 0;
  for (const ch of name) h = ((h << 5) - h + ch.charCodeAt(0)) | 0;
  return PALETTE[Math.abs(h) % PALETTE.length];
}

const AGENTS = [
  // Olympians & major gods
  { name: "Artemis", trait: "precision" },
  { name: "Athena", trait: "strategy" },
  { name: "Apollo", trait: "clarity" },
  { name: "Hermes", trait: "speed" },
  { name: "Hephaestus", trait: "craft" },
  { name: "Demeter", trait: "patience" },
  { name: "Hestia", trait: "thoroughness" },
  // Titans
  { name: "Prometheus", trait: "insight" },
  { name: "Hyperion", trait: "vision" },
  { name: "Themis", trait: "judgment" },
  { name: "Mnemosyne", trait: "memory" },
  { name: "Coeus", trait: "intellect" },
  { name: "Phoebe", trait: "radiance" },
  { name: "Rhea", trait: "flow" },
  { name: "Tethys", trait: "depth" },
  // Heroes
  { name: "Theseus", trait: "courage" },
  { name: "Perseus", trait: "focus" },
  { name: "Odysseus", trait: "resourcefulness" },
  { name: "Atalanta", trait: "swiftness" },
  { name: "Daedalus", trait: "invention" },
  { name: "Orpheus", trait: "harmony" },
  { name: "Achilles", trait: "tenacity" },
  { name: "Penelope", trait: "diligence" },
  { name: "Cassandra", trait: "foresight" },
  { name: "Icarus", trait: "ambition" },
  // Muses
  { name: "Calliope", trait: "eloquence" },
  { name: "Clio", trait: "history" },
  { name: "Thalia", trait: "creativity" },
  { name: "Erato", trait: "expression" },
  { name: "Urania", trait: "analysis" },
  { name: "Melpomene", trait: "depth" },
  { name: "Terpsichore", trait: "rhythm" },
  { name: "Polyhymnia", trait: "reflection" },
  { name: "Euterpe", trait: "joy" },
  // Nymphs & minor deities
  { name: "Callisto", trait: "observation" },
  { name: "Ariadne", trait: "navigation" },
  { name: "Iris", trait: "communication" },
  { name: "Selene", trait: "illumination" },
  { name: "Eos", trait: "freshness" },
  { name: "Echo", trait: "listening" },
  { name: "Psyche", trait: "understanding" },
  { name: "Nike", trait: "determination" },
  { name: "Tyche", trait: "intuition" },
  { name: "Astraea", trait: "precision" },
  // Philosophers (honorary Greeks)
  { name: "Hypatia", trait: "logic" },
  { name: "Archimedes", trait: "mechanics" },
  { name: "Euclid", trait: "proof" },
  { name: "Pythagoras", trait: "patterns" },
  { name: "Heraclitus", trait: "change" },
  { name: "Thales", trait: "foundation" },
  { name: "Zeno", trait: "persistence" },
  { name: "Anaxagoras", trait: "reason" },
  { name: "Democritus", trait: "atoms" },
  { name: "Empedocles", trait: "elements" },
  // Constellations (Greek origin)
  { name: "Andromeda", trait: "scale" },
  { name: "Orion", trait: "hunting" },
  { name: "Lyra", trait: "resonance" },
  { name: "Phoenix", trait: "renewal" },
  { name: "Pegasus", trait: "ascent" },
  { name: "Draco", trait: "vigilance" },
  { name: "Cygnus", trait: "grace" },
  { name: "Hydra", trait: "persistence" },
];

/**
 * Pick N unique agents from the pool.
 * Returns array of { name, trait, id } objects.
 */
export function pickAgents(count) {
  const shuffled = [...AGENTS].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, Math.min(count, AGENTS.length)).map((a, i) => ({
    ...a,
    id: `agent-${i}`,
    startedAt: null,
    completedAt: null,
    status: "pending",
    result: null,
    model: null,
    task: null,
  }));
}

/**
 * Get a single random agent.
 */
export function pickOne() {
  return pickAgents(1)[0];
}

/**
 * Colored agent tag — for stderr only (user's terminal).
 */
export function agentTag(agent) {
  const c = colorFor(agent.name);
  return `${c}${C.bold}[${agent.name}]${C.reset}`;
}

/**
 * Plain agent tag — for stdout (what Claude reads, no ANSI waste).
 */
export function agentTagPlain(agent) {
  return `[${agent.name}]`;
}

/**
 * Colored status line for stderr progress.
 */
export function agentProgress(agent, message) {
  const modelPart = agent.model ? ` ${C.dim}(${agent.model.split("/").pop()})${C.reset}` : "";
  return `${agentTag(agent)} ${message}${modelPart}`;
}

export const AGENT_POOL_SIZE = AGENTS.length;
