# uCDD method: the change loop, its hook and the test matrix

Tooling for working on uCDD, kept apart from the driver. It puts the agreed
order of work into four pieces:

| Piece | What it does |
|---|---|
| `skills/change-loop/SKILL.md` | A Claude Code skill: the order of one change (spec, family, baseline, reproduce, row first, fix, prove, close) |
| `hooks/commit-msg`, `method.toml` | A git hook that refuses a code commit without its row and its evidence |
| `matrix/matrix.toml`, `matrix/plan.py` | One definition of the test matrix, and a planner that turns a diff into the runs it needs |
| `guard/no_verify.py` | A Claude Code hook that refuses `--no-verify` and core.hooksPath changes |
| `tools/trailers.py` | Counts Issue:, Lesson: and Evidence: trailers in the history |
| `install.sh`, `tests/test_method.py` | Install per worktree; self-tests |

Standard library only: Python 3.11 or later (tomllib), git, sh.

## Why a branch of its own

This branch shares no history with the driver's branches, like
`reference-library`: git refuses to merge it into `fixes` or anything bound
for the upstream without `--allow-unrelated-histories`. A `.claude/` or test
tooling never rides into a fix by accident.

## Install

From the uCDD clone:

    git fetch origin claude/brave-franklin-6h9xzo
    git worktree add ../method -b method origin/claude/brave-franklin-6h9xzo
    UCDD_REF=irq-counters python3 ../method/tests/test_method.py
    sh ../method/install.sh <worktree> [<worktree> ...]
    sh ../method/install.sh --claude <the directory Claude Code runs in>

- **Which worktrees:** all the worktrees share one hooks directory, so
  install.sh sets `core.hooksPath` per worktree (`git config --worktree`,
  after `extensions.worktreeConfig`). Worktrees you don't name never see the
  hook. `sh install.sh --remove <worktree>` takes it out again.
- **Claude Code:** `--claude` links the skill into `<dir>/.claude/skills` and
  prints the PreToolUse lines to merge into `<dir>/.claude/settings.json`. It
  does not edit the settings itself.
- **The self-tests:** they make commits in a temporary worktree of
  `UCDD_REF` and remove it afterwards.

## The hook

A commit that touches `src/` or `scripts/build.py` is a code commit. Any
other commit is a notes commit and needs nothing. A code commit needs these
trailers in the last paragraph of its message:

    Issue: F17
    Evidence: data sheet: SBG 6-12, a 14h block ends on its last byte
    Evidence: emulator: plan 3f2a91c4, 46 runs, D10 against D9, F17 gone, the rest unchanged

- **`Issue:`** must name a row that is already committed: in ISSUES.md or
  `docs/*.md`, at the parent commit or on `sound-engine-library` or
  `spec-first`. A row added in the same commit as the code is refused. That
  is step 5: the row before the fix.
- **`Evidence:`** starts with a grade:
  - `data sheet` (also: doc, spec)
  - `emulator` (also: 86Box, DOSBox-X, QEMU, trace)
  - `hardware` (also: hw)
  - `reading`: no check could fail on the old build
  - `none`

  Every code commit needs a `data sheet` line (rule 1). When the documents
  are silent, the line says so: `Evidence: data sheet: silent; the CT2290
  decided`.
- **`Evidence: none`** claims the binaries don't change (comments, names,
  layout). The hook proves it: it builds the parent and the staged tree with
  each variant in method.toml and compares the EXE and BIN files, which takes
  about 15 seconds. On a mismatch it builds both sides again before refusing,
  because this machine has had memory faults.
- **The bench's nickname** is refused in every commit, in the message and in
  every added line (rule 7). The pattern is in method.toml.
- **Not checked:** merge commits are checked for the nickname in their
  message only. Branches matching `archive/*` are not checked at all.

When it refuses, it says what is missing and keeps the message in
COMMIT_EDITMSG. Claude never bypasses it. A person who must can use
`git commit --no-verify` in their own shell.

All of it is in method.toml: which paths count as code, the grades, the notes
refs, the build variants.

## The matrix and the planner

`matrix/matrix.toml` holds:
- **The axes:** physical card, physical IRQ, virtual model, virtual IRQ,
  mode, MIDI, client and build.
- **Parked and opt-in values:** the ESS work is parked; `base`, `free` and
  the verify build are opt-in.
- **Defaults:** Michael's lines of 20 Oct, including the older models on IRQ
  7.
- **Constraints** taken from the code.
- **The environment** each value sets, and the runners' command lines.
- **Every test:** the probes, one game per family, and the findings' own
  cases.
- **The areas:** which files need which tests, varied over which axes.

From a uCDD worktree:

    python3 ../method/matrix/plan.py --base irq-counters    # this topic's change
    python3 ../method/matrix/plan.py --files src/audio/irq.asm
    python3 ../method/matrix/plan.py --test JILLJUNG --baseline   # with runs without uCDD (step 3)
    python3 ../method/matrix/plan.py --group pc               # add the PC's runs
    python3 ../method/matrix/plan.py --format tsv             # for a runner
    python3 ../method/matrix/plan.py check                    # after every edit to matrix.toml

**What a plan contains.** For each test it reaches, the plan covers:
- every value of a varied axis;
- every pair of values across two varied axes;
- every combination of an area's `full` axes. The interrupt area has `full`
  set on the two IRQ lines, so 5/5, 5/7, 7/5 and 7/7 always run.

Every run holds the driver on (`mode engaged`, GL_CFG_V4=1,0) unless the test
asks for `base` or `free`.

**How it is laid out:**
- Probes come first, up to seven at a time.
- Recordings come after, one at a time.
- Runs on the PC come last.

**What else it lists:**
- the estimated time;
- the coverage of each axis;
- "Blocked" tests: needed by the change, but missing a launcher ID or a
  program;
- the `Evidence:` line for the commit, with the plan's tag.

**For regress.sh and sndreg:** the aim is one definition, so these should
read the matrix instead of keeping their own lists:
- **regress.sh** reads `--format tsv` (run, phase, kind, test, build, env,
  command).
- **sndreg** imports the planner:

      sys.path.insert(0, '<method>/matrix')
      import plan
      matrix = plan.load()
      matrix.group('families')                      # the test names
      config = matrix.config('JILLJUNG', {'vmodel': 'pro'})
      matrix.env('JILLJUNG', config)                # GL_IRQ=5 GL_VIRQ=7 GL_VMODEL=1 GL_CFG_V4=1,0

  Once they do, delete the lists in regress.sh (a, b, c), MODELS in
  sndreg/games.py and fixtest.SOUNDS.

## The tally

    python3 ../method/tools/trailers.py [--since 2026-10-01] [refs]

This counts each Issue:, Lesson: and Evidence: grade across the history,
with dates. Two uses:
- A row that keeps coming back in Issue: trailers is a fault that was not
  fixed by family.
- A `Lesson: Ln` trailer on a commit that hit a known lesson gives
  LESSONS.md its hit count from the record instead of by hand.

## Not done yet

- **Lines marked "check" in matrix.toml** are the seed's best reading of the
  bench's report: the PROBE_RUN names, the GL_CFG_V4 fields, the runners'
  arguments, the bset suffixes, and what some probes check.
- **Tests that need a launcher ID or a fact:**
  - F1: Warcraft or System Shock;
  - F4: Doom, Hexen or Raptor;
  - F15: Fade to Black;
  - XCOMUF's family and client;
  - the three games in sndreg/games.py that are not in the matrix yet.
- **Tests no area has yet:**
  - a step-aside test (mode `free`, byte-for-byte state across transitions);
  - UCDDSET's checks;
  - playcheck for UCDDPLAY.

  The plan names each as a warning when its area is hit.
- **The test bench is not versioned.** Once it is, the matrix belongs with
  it, and `[rows] refs` in method.toml may need its branch.
- **Ideas not built:**
  - The hook could check that an `Evidence: emulator: plan <tag>` names the
    plan for the commit's own diff.
  - An amend can fold a row into the code commit it should precede. The hook
    sees only the parent.

## For the session that runs the bench

> This branch is the method Michael and a cloud session agreed on 20 Oct, built
> from your status report. Please read README.md and skills/change-loop/SKILL.md,
> then:
> 1. Run the self-tests.
> 2. Install the hook in the worktrees Michael names (at least `irqcnt` and
>    `sndlib`).
> 3. Link the skill and merge the guard into the settings.
> 4. Go through every line marked "check" in matrix/matrix.toml and the "Not done
>    yet" list, and correct the matrix from what the bench actually does.
> 5. Point regress.sh and sndreg at the matrix and delete their own lists.
> 6. Then plan the next change with `plan.py` before running anything.
>
> Where this disagrees with your guards or the lessons register, say so to Michael
> rather than working around either.
