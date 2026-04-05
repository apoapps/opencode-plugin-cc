# OpenCode Plugin - Library Index

This directory contains modular, reusable components for the OpenCode Plugin for Claude Code.

## Quick Navigation

### Core Modules (`core/`)
- **`model-registry.mjs`** — Model metadata, fallback chains, timeouts
  - 50+ models with capabilities, costs, response times
  - Task-aware fallback sequences
  - Cost estimation and timeout calculation

### Routing Modules (`routing/`)
- **`smart-router.mjs`** — Intelligent task→model routing
  - Scoring algorithm (0-100 based on task characteristics)
  - Budget-aware model selection
  - Deadline feasibility checks

- **`pre-exec-detector.mjs`** — Auto-delegation detection
  - Prompt analysis and scoring (0-100)
  - Bilingual keyword detection (ES/EN)
  - Thresholds: DELEGATE (≥70), CONSIDER (50-69), SKIP (<50)

- **`implicit-commands.mjs`** — Natural language command parsing
  - Converts "analyze this" → `/opencode:ask`
  - Preset commands (`/review`, `/plan`, `/ask`)
  - Bilingual support for natural phrases

### UI Modules (`ui/`)
- **`session-formatter.mjs`** — Colored, human-readable output
  - ANSI color support (on/off)
  - Status emojis (✅ READY, 🔄 RUNNING, ✨ COMPLETED, ⚠️ FALLBACK, ❌ FAILED)
  - Session metadata headers (model, status, elapsed time, tokens saved)

### Config Modules (`config/`)
- **`defaults.mjs`** — Centralized configuration
  - Timeout rules, retry logic, model priorities
  - Token estimation formulas
  - UI settings (colors, emojis, verbosity)

---

## Architecture

### Before (Monolithic)
```
opencode-runner.mjs (963 lines)
├── CLI parsing
├── Model selection
├── OpenCode invocation
├── Retry logic
├── State management
├── Job tracking
└── Output formatting
```

### After (Modular)
```
lib/
├── core/           — Model metadata & registry
├── routing/        — Task analysis & smart routing
├── ui/             — Output formatting & visualization
└── config/         — Centralized configuration
```

### Benefits
✅ Single Responsibility Principle (each module <200 LOC)  
✅ Reusable across different entry points  
✅ Easy to test in isolation  
✅ Clear dependencies (ui-agnostic core)  
✅ Easy to extend (add routing rule = new file)

---

## Usage Examples

### Using ModelRegistry
```javascript
import ModelRegistry from './core/model-registry.mjs';

// Get metadata for a model
const model = ModelRegistry.getModel('minimax/MiniMax-M2.7');

// Get recommended model for a task
const recommended = ModelRegistry.getRecommendedModel('review', 'high', 'low');
// → 'minimax/MiniMax-M2.7'

// Get timeout for a model
const timeout = ModelRegistry.getTimeout('openai/gpt-5-codex');
// → 37500 (15s response * 2.5 safety margin)
```

### Using SmartRouter
```javascript
import SmartRouter from './routing/smart-router.mjs';

const decision = await SmartRouter.decide({
  taskType: 'review',
  complexity: 'high',
  codeSize: 5000,
  budget: 'medium',
  deadline: 30000,
  keywords: ['git-context', 'test-file'],
});

console.log(decision);
// → {
//     model: 'openai/gpt-5.1-codex',
//     fallbackChain: [...],
//     timeout: 37500,
//     rationale: 'GPT-5.1 Codex (...)',
//     estimatedTime: 15000,
//     confidence: 92
//   }
```

### Using PreExecDetector
```javascript
import PreExecDetector from './routing/pre-exec-detector.mjs';

const analysis = PreExecDetector.analyze(
  'Por favor revisa estos cambios en el PR',
  { hasGitDiff: true, contextSizeBytes: 25000 }
);

console.log(analysis);
// → {
//     score: 85,
//     recommendation: 'DELEGATE',
//     taskType: 'review',
//     keywords: ['review', 'git-context', 'large-context'],
//     reasoning: [
//       'keywords: review, git-context, large-context',
//       'git diff or version control context detected',
//       'large context: 24.4KB'
//     ],
//     language: 'es'
//   }
```

### Using SessionFormatter
```javascript
import SessionFormatter from './ui/session-formatter.mjs';

const header = SessionFormatter.header({
  model: 'minimax/MiniMax-M2.7',
  status: 'COMPLETED',
  elapsed: 12300,
  tokens: 2500,
  attempt: 1,
  fallbackUsed: false,
});

console.log(header);
// ✨ OpenCode Session
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Model:    MiniMax 2.7 Balanced
// Status:   COMPLETED (12.3s)
// Tokens:   ~2,500 (saves ~15,000 Claude tokens)
// Attempt:  1/3
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Using ImplicitCommands
```javascript
import ImplicitCommands from './routing/implicit-commands.mjs';

const parsed = ImplicitCommands.parse(
  'Analiza estos cambios en git',
  { hasGitDiff: true }
);

console.log(parsed);
// → {
//     command: 'opencode:review',
//     args: ['--base', 'origin/main'],
//     explicit: false,
//     implied: true,
//     rationale: 'implied review (score: 85, keywords: git-context, ...)'
//   }
```

---

## Integration Points

### Phase 2: Smart Routing Integration
Integrate `SmartRouter` into `scripts/opencode-runner.mjs`:
```javascript
import SmartRouter from './lib/routing/smart-router.mjs';

// Before invoking OpenCode, analyze the task
const decision = await SmartRouter.decide(taskAnalysis);
console.log(`Routing to ${decision.model}: ${decision.rationale}`);
```

### Phase 3: Pre-Execution Detection
Create hook `hooks/pre-execution.mjs` using `PreExecDetector`:
```javascript
import PreExecDetector from './lib/routing/pre-exec-detector.mjs';

const analysis = PreExecDetector.analyze(userPrompt, context);
if (analysis.recommendation === 'DELEGATE') {
  // Auto-delegate with suggested command
}
```

### Phase 4: Implicit Commands
Create hook `hooks/implicit-command.mjs` using `ImplicitCommands`:
```javascript
import ImplicitCommands from './lib/routing/implicit-commands.mjs';

const parsed = ImplicitCommands.parse(userInput, context);
if (parsed.command) {
  // Execute parsed command automatically
}
```

### Phase 5: UI Enhancement
Update all commands to use `SessionFormatter`:
```javascript
import SessionFormatter from './lib/ui/session-formatter.mjs';

const output = SessionFormatter.response(content, {
  model: 'minimax/MiniMax-M2.7',
  status: 'COMPLETED',
  elapsed: 12000,
});
```

---

## Configuration

See `config/defaults.mjs` for centralized settings:
- Timeout ranges (5s min, 30s default, 120s max)
- Retry strategy (3 attempts, exponential backoff)
- Token estimation formulas
- Model priority chains by task type
- UI preferences (colors, emojis, verbosity)

---

## Testing

Each module is designed to be testable in isolation:

```javascript
// Unit test example
import SmartRouter from './routing/smart-router.mjs';
import assert from 'assert';

const decision = await SmartRouter.decide({
  taskType: 'ask',
  complexity: 'low',
  budget: 'low',
});

assert(decision.model.includes('minimax'), 'Should prefer MiniMax for low-budget quick asks');
```

---

## Future Extensions

- Add new routing rules: extend `SmartRouter._scoreModels()`
- Add new models: extend `ModelRegistry.models`
- Add new task types: extend `ModelRegistry.fallbackChains`
- Add new presets: call `ImplicitCommands.registerPreset()`
- Customize UI: override `SessionFormatter` methods

---

## Backward Compatibility

✅ All existing commands continue to work  
✅ New features are opt-in (disabled by default in Phase 1)  
✅ Zero breaking changes  
✅ Fallback to monolithic runner if new modules fail

---

**Last updated**: 2026-04-03  
**Phase**: 1 (Complete) / 5  
**Status**: Ready for Phase 2 integration
