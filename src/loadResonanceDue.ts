/**
 * loadResonanceDue.ts — Resonance session-start hook function
 *
 * This function is added to hooks/lib/learning-readback.ts during installation.
 * It reads RESONANCE.md, parses Active items for pending re-rating dates,
 * and returns a compact string for session-start context injection.
 *
 * Features:
 * - Day 3/7/40 check-in surfacing (due/overdue)
 * - Day 90 purge flagging (forced decision)
 * - Monthly digest on 1st of month
 *
 * Dependencies: readFileSync, existsSync from 'fs'; join from 'path'
 * (already imported by learning-readback.ts)
 */

// --- BEGIN FUNCTION (paste into learning-readback.ts before loadSignalTrends) ---

/**
 * Load resonance items due for re-rating, monthly digest, and Day 90 purge flags.
 * Reads PAI/USER/TELOS/RESONANCE.md, parses Active items for pending dates.
 * Returns compact string if any items are due/overdue today, null otherwise.
 */
export function loadResonanceDue(paiDir: string): string | null {
  const resonancePath = join(paiDir, 'PAI', 'USER', 'TELOS', 'RESONANCE.md');
  if (!existsSync(resonancePath)) return null;

  try {
    const content = readFileSync(resonancePath, 'utf-8');

    // Extract Active section only (handle variable whitespace around --- separators)
    const activeMatch = content.match(/## Active\n([\s\S]*?)(?=\n+---\n+## )/);
    if (!activeMatch) return null;
    const activeSection = activeMatch[1];

    // Parse individual items
    const itemBlocks = activeSection.split(/(?=^### RES-)/m).filter(b => b.startsWith('### RES-'));
    if (itemBlocks.length === 0) return null;

    const today = new Date();
    const todayStr = today.toISOString().split('T')[0];
    const isFirstOfMonth = today.getDate() === 1;

    const dueItems: string[] = [];
    const purgeItems: string[] = [];
    let activeCount = 0;

    for (const block of itemBlocks) {
      activeCount++;

      // Extract item ID and insight
      const headerMatch = block.match(/^### (RES-\d+): (.+)$/m);
      if (!headerMatch) continue;
      const [, itemId, insight] = headerMatch;

      // Extract rating
      const ratingMatch = block.match(/\*\*Rating:\*\*\s*(R[34])/);
      const rating = ratingMatch ? ratingMatch[1] : 'R?';

      // Extract captured date for Day 90 calculation
      const capturedMatch = block.match(/\*\*Captured:\*\*\s*(\d{4}-\d{2}-\d{2})/);
      const capturedDate = capturedMatch ? capturedMatch[1] : null;

      // Check Day 3, Day 7, Day 40 pending dates
      const checkpoints = ['Day 3', 'Day 7', 'Day 40'];
      for (const checkpoint of checkpoints) {
        const pendingRegex = new RegExp(`\\*\\*${checkpoint}:\\*\\*\\s*\\[pending (\\d{4}-\\d{2}-\\d{2})\\]`);
        const pendingMatch = block.match(pendingRegex);
        if (pendingMatch) {
          const pendingDate = pendingMatch[1];
          if (pendingDate <= todayStr) {
            const truncInsight = insight.length > 50 ? insight.substring(0, 47) + '...' : insight;
            const overdue = pendingDate < todayStr ? ' (OVERDUE)' : '';
            dueItems.push(`${itemId} (${rating}): "${truncInsight}" — ${checkpoint} due${overdue}`);
          }
        }
      }

      // Day 90 purge check (relative to capture date)
      if (capturedDate) {
        const captured = new Date(capturedDate);
        const day90 = new Date(captured);
        day90.setDate(day90.getDate() + 90);
        const day90Str = day90.toISOString().split('T')[0];
        if (day90Str <= todayStr) {
          const truncInsight = insight.length > 50 ? insight.substring(0, 47) + '...' : insight;
          purgeItems.push(`${itemId} (${rating}): "${truncInsight}" — Day 90: FORCED DECISION (promote/upgrade/archive)`);
        }
      }
    }

    const parts: string[] = [];

    if (dueItems.length > 0) {
      parts.push('**Resonance Check-In:**');
      dueItems.forEach(item => parts.push(`  ${item}`));
    }

    if (purgeItems.length > 0) {
      parts.push('**Resonance Day 90 — Forced Decision:**');
      purgeItems.forEach(item => parts.push(`  ${item}`));
    }

    // Monthly digest on 1st of month
    if (isFirstOfMonth && activeCount > 0) {
      parts.push(`**Resonance Monthly Digest:** ${activeCount} active item${activeCount !== 1 ? 's' : ''} in the pipeline`);
    }

    return parts.length > 0 ? parts.join('\n') : null;
  } catch {
    return null;
  }
}

// --- END FUNCTION ---
