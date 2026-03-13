# Resonance Workflow — Manual Installation Guide

This guide is for **AI agents** or **manual installation** when the automated `install.sh` doesn't work (e.g., after a major PAI restructure). It describes every change needed, what to look for, and how to adapt.

All paths are relative to the PAI root (`~/.claude` by default).

---

## Overview: 7 Changes

| # | File | Action | Type |
|---|------|--------|------|
| 1 | `PAI/USER/TELOS/RESONANCE.md` | Create new file | Copy |
| 2 | `skills/Telos/Tools/UpdateTelos.ts` | Add to VALID_FILES array | Patch |
| 3 | `skills/Telos/Workflows/Resonance.md` | Create new file | Copy |
| 4a | `skills/Telos/SKILL.md` | Add routing table row | Patch |
| 4b | `skills/Telos/SKILL.md` | Add triggers to `description:` USE WHEN | Patch |
| 5 | `hooks/lib/learning-readback.ts` | Add exported function | Patch |
| 6 | `hooks/LoadContext.hook.ts` | Import + call new function | Patch |

---

## Step 1: Create RESONANCE.md

**Target:** `PAI/USER/TELOS/RESONANCE.md`
**Source:** `src/RESONANCE.md` in this repo
**Action:** Copy the file. Do NOT copy any existing items — this is a clean template.

If RESONANCE.md already exists with user data, **do not overwrite it**.

---

## Step 2: Add RESONANCE.md to UpdateTelos.ts VALID_FILES

**Target:** `skills/Telos/Tools/UpdateTelos.ts`
**What to find:** The `VALID_FILES` array (a `const` containing an array of `.md` filenames)
**What to add:** `'RESONANCE.md'` — insert alphabetically (after `'PROJECTS.md'`)

**Before:**
```typescript
const VALID_FILES = [
  'BELIEFS.md', 'BOOKS.md', 'CHALLENGES.md', 'FRAMES.md', 'GOALS.md',
  'LESSONS.md', 'MISSION.md', 'MODELS.md', 'MOVIES.md', 'NARRATIVES.md',
  'PREDICTIONS.md', 'PROBLEMS.md', 'PROJECTS.md', 'STRATEGIES.md',
  'TELOS.md', 'TRAUMAS.md', 'WISDOM.md', 'WRONG.md'
];
```

**After:**
```typescript
const VALID_FILES = [
  'BELIEFS.md', 'BOOKS.md', 'CHALLENGES.md', 'FRAMES.md', 'GOALS.md',
  'LESSONS.md', 'MISSION.md', 'MODELS.md', 'MOVIES.md', 'NARRATIVES.md',
  'PREDICTIONS.md', 'PROBLEMS.md', 'PROJECTS.md', 'RESONANCE.md',
  'STRATEGIES.md', 'TELOS.md', 'TRAUMAS.md', 'WISDOM.md', 'WRONG.md'
];
```

**Also:** In the JSDoc comment block at the top of the file, add after the `PROJECTS.md` line:
```
 * - RESONANCE.md - Resonance tracking (R3/R4 insights with decay lifecycle)
```

**How to find if the file structure changed:** Search for `VALID_FILES` or search for the array of `.md` filenames. The variable name or location may change, but the pattern (array of allowed TELOS filenames) will be recognizable.

---

## Step 3: Create Workflow File

**Target:** `skills/Telos/Workflows/Resonance.md`
**Source:** `src/Resonance.workflow.md` in this repo
**Action:** Copy the file directly. No modifications needed.

---

## Step 4a: Add Routing Entry to SKILL.md

**Target:** `skills/Telos/SKILL.md`
**What to find:** The "Workflow Routing" table (a markdown table mapping workflow names to trigger phrases and files)
**What to add:** A new row:

```markdown
| **Resonance** | "resonance", "R3", "R4", "that resonated", "capture resonance" | `Workflows/Resonance.md` |
```

**Where:** After the last existing row in the table (typically WriteReport).

**How to find if the structure changed:** Search for `Workflow Routing` or look for a markdown table with columns like `Workflow | Trigger | File`. The table format is standard across PAI skills.

---

## Step 4b: Add Resonance Triggers to SKILL.md Description

**Target:** `skills/Telos/SKILL.md`
**What to find:** The `description:` field in the YAML frontmatter, specifically the `USE WHEN` keyword list
**Why this matters:** The `description:` frontmatter is the **only** text surfaced to the AI at session start for skill matching. The routing table (Step 4a) is only consulted *after* the skill is already invoked. Without these keywords in `USE WHEN`, bare triggers like "R3" or "R4" will never reach the Resonance workflow.

**What to change:** Append resonance trigger keywords to the end of the `USE WHEN` clause.

**Before:**
```
description: Life OS and project analysis — ...USE WHEN Telos, life goals, ..., dashboard, n=24.
```

**After:**
```
description: Life OS and project analysis — ...USE WHEN Telos, life goals, ..., dashboard, n=24, resonance, R3, R4, capture resonance, that resonated, review resonance.
```

**How to find if the structure changed:** Search for `USE WHEN` in the frontmatter `description:` field. The pattern is a comma-separated keyword list that the AI matches against user input. Every PAI skill uses this convention.

---

## Step 5: Add loadResonanceDue() to learning-readback.ts

**Target:** `hooks/lib/learning-readback.ts`
**Source:** `src/loadResonanceDue.ts` in this repo (contains the complete function)
**What to do:** Add the `loadResonanceDue` function as a new export.

**Where to insert:** Before the `loadSignalTrends` function. The file has a pattern of exported functions, each with a JSDoc comment. Insert the new function in the same style.

**The function:**
- Takes `paiDir: string` as its only argument
- Returns `string | null`
- Reads `PAI/USER/TELOS/RESONANCE.md`
- Parses the `## Active` section for items with pending dates
- Returns a compact string if any items are due/overdue today
- Handles monthly digest (1st of month) and Day 90 purge flagging
- Uses `readFileSync`, `existsSync` from `fs` and `join` from `path` (already imported)

**How to find if the structure changed:** Search for `learning-readback` or `loadLearningDigest` or `loadSignalTrends`. This is the file that provides readback functions called by LoadContext. As long as PAI has a session-start context injection mechanism, this pattern will exist somewhere.

**Key regex to preserve:** The Active section parser uses:
```typescript
content.match(/## Active\n([\s\S]*?)(?=\n+---\n+## )/)
```
This handles variable whitespace around `---` separators. If RESONANCE.md format changes, this regex may need updating.

---

## Step 6: Wire loadResonanceDue into LoadContext.hook.ts

**Target:** `hooks/LoadContext.hook.ts`
**Two changes needed:**

### 6a. Add to import

**Find:** The import line that imports from `./lib/learning-readback`
**Add:** `loadResonanceDue` to the destructured import

**Before:**
```typescript
import { loadLearningDigest, loadWisdomFrames, loadFailurePatterns, loadSignalTrends } from './lib/learning-readback';
```

**After:**
```typescript
import { loadLearningDigest, loadWisdomFrames, loadFailurePatterns, loadSignalTrends, loadResonanceDue } from './lib/learning-readback';
```

### 6b. Add call site

**Find:** The section where `learningParts` array is built (where `loadFailurePatterns` result is pushed)
**Add:** Call `loadResonanceDue(paiDir)` and push the result

**Before:**
```typescript
      const learningParts: string[] = [];
      if (signalTrends) learningParts.push(signalTrends);
      if (wisdomFrames) learningParts.push(wisdomFrames);
      if (learningDigest) learningParts.push(learningDigest);
      if (failurePatterns) learningParts.push(failurePatterns);
```

**After:**
```typescript
      const resonanceDue = loadResonanceDue(paiDir);

      const learningParts: string[] = [];
      if (signalTrends) learningParts.push(signalTrends);
      if (wisdomFrames) learningParts.push(wisdomFrames);
      if (learningDigest) learningParts.push(learningDigest);
      if (failurePatterns) learningParts.push(failurePatterns);
      if (resonanceDue) learningParts.push(resonanceDue);
```

**How to find if the structure changed:** Search for `learningParts` or `learning-readback` or `loadLearningDigest`. The pattern is: import readback functions → call them → collect results → inject into context. As long as PAI has session-start hooks, this pattern will exist.

---

## Verification

After installation, verify:

1. **Function works:**
   ```bash
   bun -e "const {loadResonanceDue}=require('./hooks/lib/learning-readback.ts'); console.log(loadResonanceDue('$HOME/.claude'))"
   ```
   Should return `null` for empty RESONANCE.md.

2. **UpdateTelos accepts RESONANCE.md:**
   ```bash
   bun skills/Telos/Tools/UpdateTelos.ts RESONANCE.md "test" "test verification"
   ```
   Should succeed. Remove the appended "test" line afterward.

3. **Session-start surfacing:**
   Add a test item to RESONANCE.md with `Day 3: [pending TODAY]`, start a new session, check for the resonance check-in in dynamic context.

4. **Capture flow:**
   Say "R3: [some insight]" in a session. PAI should route to the Resonance workflow and capture.

---

## Adapting to PAI Restructures

If PAI's file structure changes significantly:

| What moved | How to find it |
|------------|---------------|
| TELOS directory | Search for `BELIEFS.md`, `WISDOM.md`, `GOALS.md` — they'll be together |
| UpdateTelos.ts | Search for `VALID_FILES` or a filename whitelist with `.md` entries |
| Workflow routing | Search for `Workflow Routing` table in any SKILL.md |
| Session-start hooks | Search for `SessionStart` trigger or `LoadContext` |
| Learning readback | Search for `loadLearningDigest` or similar readback pattern |

The **concepts** are stable even if paths change:
1. A data file in the TELOS directory
2. A whitelist that controls which TELOS files can be updated
3. A workflow file that defines the skill's operations
4. A routing table that maps triggers to workflows
5. A readback function that surfaces data at session start
6. A hook that calls the readback function
