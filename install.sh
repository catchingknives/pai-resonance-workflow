#!/usr/bin/env bash
# install.sh — Install PAI Resonance Workflow into a PAI installation
#
# Idempotent: safe to run multiple times. Checks before patching.
#
# Usage: ./install.sh [PAI_DIR]
#   PAI_DIR defaults to ~/.claude

set -euo pipefail

PAI_DIR="${1:-$HOME/.claude}"
TELOS_DIR="$PAI_DIR/PAI/USER/TELOS"
SKILL_DIR="$PAI_DIR/skills/Telos"
HOOKS_DIR="$PAI_DIR/hooks"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
skip() { echo -e "${YELLOW}[SKIP]${NC} $1 (already installed)"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

echo "=== PAI Resonance Workflow Installer ==="
echo "PAI directory: $PAI_DIR"
echo ""

# ── Preflight checks ──
[ -d "$PAI_DIR" ] || fail "PAI directory not found: $PAI_DIR"
[ -d "$TELOS_DIR" ] || fail "TELOS directory not found: $TELOS_DIR"
[ -d "$SKILL_DIR" ] || fail "Telos skill not found: $SKILL_DIR"
[ -d "$HOOKS_DIR" ] || fail "Hooks directory not found: $HOOKS_DIR"
[ -f "$HOOKS_DIR/lib/learning-readback.ts" ] || fail "learning-readback.ts not found"
[ -f "$HOOKS_DIR/LoadContext.hook.ts" ] || fail "LoadContext.hook.ts not found"
[ -f "$SKILL_DIR/Tools/UpdateTelos.ts" ] || fail "UpdateTelos.ts not found"
[ -f "$SKILL_DIR/SKILL.md" ] || fail "SKILL.md not found"

echo "Preflight checks passed."
echo ""

# ── 1. RESONANCE.md ──
if [ -f "$TELOS_DIR/RESONANCE.md" ]; then
    skip "RESONANCE.md exists in TELOS"
else
    cp "$SRC_DIR/RESONANCE.md" "$TELOS_DIR/RESONANCE.md"
    ok "Created RESONANCE.md in TELOS"
fi

# ── 2. Workflow file ──
mkdir -p "$SKILL_DIR/Workflows"
if [ -f "$SKILL_DIR/Workflows/Resonance.md" ]; then
    skip "Workflows/Resonance.md exists"
else
    cp "$SRC_DIR/Resonance.workflow.md" "$SKILL_DIR/Workflows/Resonance.md"
    ok "Created Workflows/Resonance.md"
fi

# ── 3. UpdateTelos.ts — add RESONANCE.md to VALID_FILES ──
UPDATETELOS="$SKILL_DIR/Tools/UpdateTelos.ts"
if grep -q "'RESONANCE.md'" "$UPDATETELOS" 2>/dev/null; then
    skip "RESONANCE.md already in UpdateTelos.ts VALID_FILES"
else
    # Strategy: find the VALID_FILES array and add RESONANCE.md after PROJECTS.md
    # This uses sed to insert after the line containing PROJECTS.md
    if grep -q "'PROJECTS.md'" "$UPDATETELOS"; then
        sed -i.bak "s/'PROJECTS.md',/'PROJECTS.md', 'RESONANCE.md',/" "$UPDATETELOS"
        rm -f "$UPDATETELOS.bak"
        ok "Added RESONANCE.md to UpdateTelos.ts VALID_FILES"
    else
        echo -e "${YELLOW}[WARN]${NC} Could not find PROJECTS.md in VALID_FILES — manual patch needed"
        echo "  Add 'RESONANCE.md' to the VALID_FILES array in $UPDATETELOS"
    fi
fi

# Also add to the file comment block if not present
if grep -q "RESONANCE.md" "$UPDATETELOS" | head -1 && grep -q "Resonance tracking" "$UPDATETELOS"; then
    : # already has the comment
else
    if grep -q "PROJECTS.md - Active projects" "$UPDATETELOS"; then
        sed -i.bak "/PROJECTS.md - Active projects/a\\
 * - RESONANCE.md - Resonance tracking (R3/R4 insights with decay lifecycle)" "$UPDATETELOS"
        rm -f "$UPDATETELOS.bak"
        ok "Added RESONANCE.md to UpdateTelos.ts comment block"
    fi
fi

# ── 4a. SKILL.md — add routing entry ──
SKILLMD="$SKILL_DIR/SKILL.md"
if grep -q "Resonance" "$SKILLMD" 2>/dev/null; then
    skip "Resonance routing already in SKILL.md"
else
    # Insert after the WriteReport line in the routing table
    if grep -q "WriteReport" "$SKILLMD"; then
        sed -i.bak '/WriteReport.*Workflows\/WriteReport.md/a\
| **Resonance** | "resonance", "R3", "R4", "that resonated", "capture resonance" | `Workflows/Resonance.md` |' "$SKILLMD"
        rm -f "$SKILLMD.bak"
        ok "Added Resonance routing to SKILL.md"
    else
        echo -e "${YELLOW}[WARN]${NC} Could not find WriteReport row in SKILL.md — manual patch needed"
        echo "  Add this row to the Workflow Routing table:"
        echo '  | **Resonance** | "resonance", "R3", "R4", "that resonated", "capture resonance" | `Workflows/Resonance.md` |'
    fi
fi

# ── 4b. SKILL.md — add resonance triggers to description frontmatter ──
# The description: field in frontmatter is surfaced as the skill's USE WHEN keywords.
# Without these, the AI cannot match "R3"/"R4" to the Telos skill at skill-selection time.
if grep -q 'resonance, R3, R4' "$SKILLMD" 2>/dev/null; then
    skip "Resonance triggers already in SKILL.md description"
else
    if grep -q 'USE WHEN' "$SKILLMD"; then
        # Append resonance triggers before the trailing period of the USE WHEN clause
        sed -i.bak 's/\(USE WHEN.*\)\.$/\1, resonance, R3, R4, capture resonance, that resonated, review resonance./' "$SKILLMD"
        rm -f "$SKILLMD.bak"
        if grep -q 'resonance, R3, R4' "$SKILLMD"; then
            ok "Added resonance triggers to SKILL.md description"
        else
            echo -e "${YELLOW}[WARN]${NC} Could not patch USE WHEN line — manual patch needed"
            echo "  Add 'resonance, R3, R4, capture resonance, that resonated, review resonance' to the USE WHEN keywords in the description: frontmatter"
        fi
    else
        echo -e "${YELLOW}[WARN]${NC} Could not find USE WHEN in SKILL.md description — manual patch needed"
        echo "  Add 'resonance, R3, R4, capture resonance, that resonated, review resonance' to the USE WHEN keywords in the description: frontmatter"
    fi
fi

# ── 5. learning-readback.ts — add loadResonanceDue function ──
READBACK="$HOOKS_DIR/lib/learning-readback.ts"
if grep -q "loadResonanceDue" "$READBACK" 2>/dev/null; then
    skip "loadResonanceDue already in learning-readback.ts"
else
    # Strategy: insert the function before loadSignalTrends
    # Extract the function body from our source file (between BEGIN and END markers)
    FUNC_BODY=$(sed -n '/^\/\*\*/,/^}$/p' "$SRC_DIR/loadResonanceDue.ts" | head -n -2)

    if grep -q "export function loadSignalTrends" "$READBACK"; then
        # Create a temp file with the insertion
        TMPFILE=$(mktemp)
        awk -v func="$FUNC_BODY" '
        /^export function loadSignalTrends/ {
            print func
            print ""
        }
        { print }
        ' "$READBACK" > "$TMPFILE"
        mv "$TMPFILE" "$READBACK"
        ok "Added loadResonanceDue() to learning-readback.ts"
    else
        echo -e "${YELLOW}[WARN]${NC} Could not find loadSignalTrends in learning-readback.ts — manual patch needed"
        echo "  Paste the loadResonanceDue function from src/loadResonanceDue.ts"
    fi
fi

# ── 6. LoadContext.hook.ts — import and call loadResonanceDue ──
LOADCTX="$HOOKS_DIR/LoadContext.hook.ts"

# Add to import
if grep -q "loadResonanceDue" "$LOADCTX" 2>/dev/null; then
    skip "loadResonanceDue already imported in LoadContext.hook.ts"
else
    if grep -q "loadSignalTrends" "$LOADCTX"; then
        sed -i.bak 's/loadSignalTrends }/loadSignalTrends, loadResonanceDue }/' "$LOADCTX"
        # Handle case where import doesn't end with space-brace
        if ! grep -q "loadResonanceDue" "$LOADCTX"; then
            sed -i.bak "s/loadSignalTrends}/loadSignalTrends, loadResonanceDue}/" "$LOADCTX"
        fi
        # Handle case with 'from' on same line
        if ! grep -q "loadResonanceDue" "$LOADCTX"; then
            sed -i.bak "s/loadSignalTrends/loadSignalTrends, loadResonanceDue/" "$LOADCTX"
        fi
        rm -f "$LOADCTX.bak"
        ok "Added loadResonanceDue to imports in LoadContext.hook.ts"
    else
        echo -e "${YELLOW}[WARN]${NC} Could not patch import — manual patch needed"
    fi
fi

# Add call site
if grep -q "loadResonanceDue(paiDir)" "$LOADCTX" 2>/dev/null; then
    skip "loadResonanceDue() call already in LoadContext.hook.ts"
else
    if grep -q "failurePatterns" "$LOADCTX"; then
        # Insert after the failurePatterns line in the learningParts section
        sed -i.bak '/if (failurePatterns) learningParts.push(failurePatterns);/a\
      const resonanceDue = loadResonanceDue(paiDir);\
      if (resonanceDue) learningParts.push(resonanceDue);' "$LOADCTX"
        rm -f "$LOADCTX.bak"

        # If the above didn't work (different formatting), try alternate approach
        if ! grep -q "loadResonanceDue(paiDir)" "$LOADCTX"; then
            sed -i.bak '/failurePatterns.*learningParts/a\
      const resonanceDue = loadResonanceDue(paiDir);\
      if (resonanceDue) learningParts.push(resonanceDue);' "$LOADCTX"
            rm -f "$LOADCTX.bak"
        fi

        ok "Added loadResonanceDue() call to LoadContext.hook.ts"
    else
        echo -e "${YELLOW}[WARN]${NC} Could not find learningParts section — manual patch needed"
    fi
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Verify:"
echo "  1. Start a new Claude Code session — resonance due items should appear"
echo "  2. Say 'R3: [some insight]' — should trigger capture workflow"
echo "  3. Run: bun -e \"const {loadResonanceDue}=require('$READBACK'); console.log(loadResonanceDue('$PAI_DIR'))\""
echo ""
