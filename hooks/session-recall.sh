#!/usr/bin/env bash
# A Claude Code SessionStart hook (startup, resume, compact): what a fresh
# or compacted context must have in front of it before it touches anything.
# Plain stdout from a SessionStart hook is added to Claude's context.
#
# Prints: the ledger's state, the fixes index (newest rows), STATE.md's open
# faults and questions, and the standing rules that compaction loses first.
# Finds the top folder by walking up from CLAUDE_PROJECT_DIR (or the cwd)
# to the directory that holds context/LESSONS.md.

set -u
start="${CLAUDE_PROJECT_DIR:-$PWD}"
top=""
d="$start"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  if [ -f "$d/context/LESSONS.md" ]; then top="$d"; break; fi
  d="$(dirname "$d")"
done
[ -z "$top" ] && exit 0

echo "=== Session recall (hooks/session-recall.sh) ==="
echo "Top folder: $top"

ledger="$top/ledger/runs.jsonl"
if [ -f "$ledger" ]; then
  echo "Ledger: $(wc -l < "$ledger") runs recorded in ledger/runs.jsonl."
else
  echo "Ledger: EMPTY (no ledger/runs.jsonl). No 'Evidence: emulator' trailer is valid until the runners record. Rebuild the runner-to-ledger path first."
fi

fixed=""
for f in "$top/context/FIXED.md" "$top/FIXED.md"; do
  [ -f "$f" ] && fixed="$f" && break
done
if [ -n "$fixed" ]; then
  echo "--- Fixes already made ($fixed, newest 25 rows) ---"
  grep -E '^\| ' "$fixed" | sed -n '3,27p'
else
  echo "--- FIXED.md is missing: run python3 METHOD/tools/fixed.py --out $top/context/FIXED.md in a uCDD worktree ---"
fi

state="$top/context/STATE.md"
if [ -f "$state" ]; then
  echo "--- STATE.md: open faults ---"
  awk '/^## Open faults/{f=1;next} /^## /{f=0} f' "$state" | head -40
  echo "--- STATE.md: questions for Michael (unanswered questions become your assumptions) ---"
  awk '/^## Questions for Michael/{f=1;next} /^## /{f=0} f' "$state" | head -30
  # Gate tables for any directive in force (Tightening r3, Project A, ...): the current gate and
  # its first unmet acceptance line are what a fresh or compacted context acts on first.
  for sec in "Tightening r3" "Project A"; do
    if grep -q "^## $sec" "$state"; then
      echo "--- STATE.md: $sec (do the first gate that is not PASS; nothing else) ---"
      awk -v s="^## $sec" '$0 ~ s {f=1;next} /^## /{f=0} f' "$state" | head -40
    fi
  done
fi

cat <<'EOF'
--- Standing rules that compaction loses first ---
- Before any edit to src/*.asm, *.inc or scripts/build.py the recall hook shows what the notes already say; read it in full; cite or cherry-pick an existing fix, never rewrite it (a rewrite is a lesson hit).
- No "Evidence: emulator" without a ledger entry the runners wrote; no verdict from a run with the dynamic recompiler on (RIG_DYNAREC=0 for every run that records).
- Rule 1 first: the citation is written in the row before the fix, and it names a key in method.toml [references].
- One ISSUES.md, on the notes branch; rows go there, never into a feature branch's copy.
- "Built, not run" is not done. Say it in every place the change is mentioned.
EOF
exit 0
