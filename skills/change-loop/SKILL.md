---
name: change-loop
description: The order of work for any uCDD change, fault or fix - spec, family, baseline, reproduce, row first, fix, prove with the matrix plan, close with commit trailers. Use before writing or changing uCDD code, when a game or test shows a fault, when choosing which tests to run, and before every uCDD commit, including when the commit-msg hook refuses one.
---

# The change loop

One change, in this order. A step is done when its output is written where
it says. Skipping a step, or doing one out of order, is how the faults in
the lessons register came back.

METHOD below is the method worktree: two directories above this skill's
real path (`readlink -f` on the skill directory).

## 0. Lessons

Run the register's checklist for the kind of work before starting:
`python3 context/lessons.py TAG` (fix, blame for a game fault, code, run,
probe, kit), heaviest first. When something goes wrong, search LESSONS.md
before anything else.

## 1. Specification

Find the document and the line that decide the behaviour: the text copies on
`reference-library`, docs/vsb-spec.md, vess-spec.md, host-cdrom-spec.md,
spec-first.md. Write the citation down now, not after the fix. Where the
documents are silent, say so and name what decides instead: the emulator,
then the hardware (rule 1).

## 2. Family

Look the game up in docs/sound-engines (inventory.md, census.md): its
engine, its driver version, the other games on the same driver. A fault is
one game's own only after its family has been tried (rule 10). Note what the
family page predicts before running anything.

## 3. Baseline

Run the same set-up without uCDD (`plan.py --test NAME --baseline` gives the
pair). A fault that shows without uCDD is not uCDD's. Check the game's own
configuration first: its IRQ, its card (F16). Every uCDD run holds the driver
on; a run where it stepped aside tested the bare card (L7).

## 4. Reproduce

Find a check that fails on the current build and say by how much. A check is
trusted only once it fails on a known-bad build (L4). If nothing fails, the
fix will stand on reading: decide that now and write it in the row, not after.

## 5. The row, before the fix

Write the row in ISSUES.md or findings.md: symptom, citation, family,
baseline, reproducer, hypothesis, and the plan tag from step 7's command run
now. Commit it on its own (a notes commit). The hook accepts a code commit
only when its `Issue:` row is already committed.

## 6. Fix

Fix the shared cause, once, for the family; no special case for one game
(rules 1 and 10). The build stops at the segment limits: note the headroom.

Code under a join (a label whose comment names its incoming paths: "Joined
from", "Called from", "On both paths") is shared by every path into it
(L2). Check each path against the comment, bring the comment up to date,
and name the label in a `Paths:` trailer. The hook refuses a commit that
changes a join without naming it.

## 7. Prove

1. The reproducer from step 4 passes on the new build.
2. From the uCDD worktree: `python3 METHOD/matrix/plan.py --base <where the
   topic started> --save`. Run it through the runners: phase 1 (probes, up
   to seven at a time), then phase 2 (recordings, one at a time with nothing
   else running, L6). Phase 3, on the PC, only when Michael is running the
   kit. The runners record each verdict in the ledger; you never do.
3. `python3 METHOD/tools/ledger.py show <tag>`: the plan is evidence only
   when every run passed on the binaries you are committing. Commit exactly
   what was built and run; a change after the runs means running again.
4. Compare against the build before (rsum.py with a BASE). A difference
   nobody can explain is a finding, not noise.
5. The plan's "Blocked" lines are tests this change needs and nobody can run
   yet. Give them what they lack, or write in the row why not.

A trace build explains; the clean build and the recording judge (L3).

## 8. Close

Commit with the trailers in the last paragraph of the message:

    Issue: F17
    Evidence: data sheet: SBG 6-12, a 14h block ends on its last byte
    Evidence: emulator: plan 3f2a91c4, 46 runs, all passed (ledger), D10 against D9: F17 gone
    Evidence: hardware: the PC, D10 kit, Jill on the CT2290
    Paths: audio_irq.acknowledged, all four incoming paths checked
    Lesson: L7

Then the row gets its result and grade. A lesson that applied and was
missed gets its hit line in LESSONS.md (date, severity 1 to 4, relearned or
applied) and `lessons.py` is run to re-rank; the `Lesson:` trailer only
links the commit to it.

| Grade | Means |
|---|---|
| data sheet | a document and its line, or "silent" and what decided instead; needed on every code commit |
| emulator | 86Box, DOSBox-X or QEMU: which build, which plan, the result |
| hardware | Michael's PC: which kit, which card, the result |
| reading | no check could fail on the old build; the fix stands on reading |
| none | nothing a binary sees changed; the hook builds both sides to prove it |

## Honest results

A correct "not verified" is worth more than a wrong "verified". Write only
results read from a tool's output or the ledger, never from memory or from
what a run should have shown. When something could not be run, say so: the
row names what is untested and why, the commit cites only what ran (a
smaller plan, `reading`, or no emulator line), and Blocked runs stay listed.
A claim found wrong later is corrected everywhere it was written, as soon as
it is found.

## Before a branch is merged into fixes

A session with no stake in the fix checks it:
1. It reads the row, the diff and the evidence, and says whether the
   evidence supports the claim.
2. `ledger.py spot <tag>` picks two passed runs at random; it re-runs each
   with the command shown (UCDD_SPOT=1 marks the result as a spot check).
3. `ledger.py audit <tag>`: a disagreement stops the merge. It is a finding
   about the fix or about the instrument (L11).

## When the hook or the guard refuses

Read what it says and give the commit what it lacks. Never `--no-verify`,
never move core.hooksPath, never write the ledger by hand (the guard refuses
all three). If the hook is wrong, say so, fix it in METHOD, and tell
Michael. Notes commits pass without trailers; the test-bench nickname never
passes anywhere.

## Nothing goes upstream

Nothing from this fork goes to vorvek (Michael, 20 Oct 2026): no pull
request, issue, comment or @mention on his repository, and no link to his
issues in a commit or a note. Pull requests, if any, go to EarBoye/uCDD only
(`gh pr create --repo EarBoye/uCDD`). The guard and the hook refuse the rest.

## The matrix

matrix.toml is the only list of what can be run. A new test program, game
or setting goes there, not into regress.sh or games.py, and
`python3 METHOD/matrix/plan.py check` runs after every edit to it.
