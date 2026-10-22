# uCDD method: the change loop, its hook, the test matrix and the ledger

Tooling for working on uCDD, kept apart from the driver. It puts the agreed
order of work into these pieces:

| Piece | What it does |
|---|---|
| `skills/change-loop/SKILL.md` | A Claude Code skill: the order of one change (spec, family, baseline, reproduce, row first, fix, prove, close), honest results, the check before `fixes` |
| `hooks/commit-msg`, `method.toml` | A git hook that refuses a code commit without its row and its evidence |
| `matrix/matrix.toml`, `matrix/plan.py` | One definition of the test matrix, and a planner that turns a diff into the runs it needs |
| `tools/ledger.py` | The results ledger: the runners record each verdict and the binaries it was for; the hook reads it |
| `guard/guard.py` | A Claude Code hook: no `--no-verify`, no hand-written ledger, no write into the game library, no commits through the GitHub tools, nothing to the upstream |
| `tools/trailers.py` | Counts Issue:, Lesson: and Evidence: trailers in the history |
| `tools/game.py` | Before a game runs: its engine, driver versions and family, looked up in the library; what the notes lack |
| `tools/ci.py`, `ci/method.yml` | The checks on GitHub: every branch built with its headroom, and the hook's checks on commits made after the hook went in |
| `install.sh`, `tests/test_method.py`, `lib/methodlib.py` | Install per worktree; self-tests; what the pieces share |

Standard library only: Python 3.11 or later (tomllib), git, sh.

## Why a branch of its own

This branch shares no history with the driver's branches, like
`reference-library`: git refuses to merge it into `fixes` without
`--allow-unrelated-histories`, so a `.claude/` or test tooling never rides
into a fix by accident. Nothing from this fork goes to the upstream at all
(see "Nothing goes upstream" below).

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
  prints the PreToolUse lines to merge into `<dir>/.claude/settings.json`
  (the guard, for Bash, file edits and the GitHub tools). It does not edit
  the settings itself.
- **The self-tests:** they make commits in a temporary worktree of
  `UCDD_REF` and remove it afterwards, with a temporary ledger.

## What is not in git (redo it on a new machine)

- **NASM on PATH** wherever commits are made: the hook builds to prove
  `Evidence: none` and to compare a plan's binaries, and refuses when nothing
  builds.
- **`method.local.toml`**: `[games] paths` and the bench's banned words.
- **`GAMES`** in the runners' environment: the game runner's command reads
  `$GAMES/{library}`.
- **The hook**, per worktree: `sh install.sh <worktree> ...` (it is safe to
  run again).
- **The skill link and the guard** in Claude Code's settings:
  `sh install.sh --claude <dir>` prints the lines to compare.
- **The ledger** (`ledger/`, or `[ledger] path`): its results and saved plans
  exist only where the runners wrote them. Keep it on storage that is backed
  up; a lost ledger means plans are saved and run again before a commit can
  cite them.
- **The self-tests** need `UCDD_REPO` (a uCDD clone) and `UCDD_REF`, and NASM
  on PATH, or most of them skip.

There are no other environment variables: `UCDD_LEDGER`, `UCDD_GAMES` and
`UCDD_METHOD_LOCAL` only override method.toml, and `UCDD_SPOT=1` marks a
spot check.

## The hook

A commit that touches `src/` or `scripts/build.py` is a code commit. Any
other commit is a notes commit and needs nothing. A code commit needs these
trailers in the last paragraph of its message:

    Issue: F17
    Evidence: data sheet: SBG 6-12, a 14h block ends on its last byte
    Evidence: emulator: plan 3f2a91c4, 46 runs, all passed (ledger), D10 against D9: F17 gone

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
- **A plan named in an emulator line** ("plan 3f2a91c4") is checked against
  the ledger: the plan must be saved and unedited, every one of its runs
  recorded as a pass, and the binaries each run recorded must be the ones
  this commit builds (the hook builds the staged tree to compare). See "The
  ledger".
- **`Evidence: none`** claims the binaries don't change (comments, names,
  layout). The hook proves it: it builds the parent and the staged tree with
  each variant in method.toml and compares the EXE and BIN files, which takes
  about 15 seconds. On a mismatch it builds both sides again before refusing,
  because this machine has had memory faults.
- **`Paths:`** is needed when the commit changes code under a join: a label
  whose comment names its incoming paths, as the data-flow pass wrote them
  ("Joined from", "Called from", "On both paths"; 16 such labels on
  irq-counters). The trailer names the label, after every path into it was
  checked against the comment (lesson L2). It is recall at the moment of
  the change, not proof: the hook shows the comment and asks for the name.
  An `Evidence: none` commit is exempt.
- **`Family:`** names the sound engine family the fault belongs to (rule 10),
  from `[families]` in matrix.toml, or says `none` and why it is no one
  family's. The family's page in the library (`HEAD` or the
  sound-engine-library branch) must already name the row: the knowledge goes
  back to the whole family before the fix. When the commit cites plans, one
  of them must survey the family (`plan.py --family`). An `Evidence: none`
  commit is exempt.
- **Game code, refused in every commit** (Michael, 20 Oct 2026: we never
  ship, patch or alter game code; any game as it was sold must run with uCDD
  alone): a program, driver or disc file by its suffix (`[games] suffixes`),
  a file the census knows as a game's driver under any name, three or more
  lines of a disassembly listing, two or more lines with a decompiler's own
  names (Ghidra's `FUN_0001a2b4`, `DAT_`, `undefined4`, `unaff_`, `in_AX`),
  and a game's folder name or a program name
  in a string in driver code (a special case; comments may name games). Run
  over 187 recent commits of fixes, irq-counters, sound-engine-library and
  spec-first, it finds nothing (two false alarms were fixed on the way: a web
  address, and the English word "undefined").
- **No local path, in every commit** (Michael, 20 Oct 2026): a home directory
  (`/home/<name>/`, `/Users/<name>/`, `C:\Users\<name>\`) is refused in the
  message and in every added line. The bench's own paths and account name
  live in `method.local.toml` (below), which git ignores.
- **Refused in every commit**, in the message and in every added line: the
  bench's nickname (rule 7), and an @mention of the upstream author or a
  link to one of his issues or pull requests. The patterns are in
  method.toml.
- **Not checked:** merge commits are checked for the banned patterns in their
  message only. Branches matching `archive/*` are not checked at all.

When it refuses, it says what is missing and keeps the message in
COMMIT_EDITMSG. Claude never bypasses it. A person who must can use
`git commit --no-verify` in their own shell.

All of it is in method.toml: which paths count as code, the grades, the notes
refs, the build variants, the ledger.

## The bench's own settings

`method.local.toml`, beside method.toml, is never committed (`.gitignore`).
Its tables merge into method.toml's and its `[[banned]]` entries add to the
list, so the bench can ban its own account name without publishing it:

    [games]
    paths = ["<the game library>", "<its disc images>"]

    [[banned]]
    pattern = '(?i)<the account name>'
    why = "the bench's account name"

`UCDD_METHOD_LOCAL` points at another file. The runners' commands in
matrix.toml name the library as `$GAMES`, which the bench sets in its own
environment.

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

    python3 ../method/matrix/plan.py --base irq-counters --save   # this topic's change
    python3 ../method/matrix/plan.py --files src/audio/irq.asm
    python3 ../method/matrix/plan.py --test JILLJUNG --baseline    # with runs without uCDD (step 3)
    python3 ../method/matrix/plan.py --group pc                # add the PC's runs
    python3 ../method/matrix/plan.py --format tsv              # for a runner
    python3 ../method/matrix/plan.py check                     # after every edit to matrix.toml

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
- the `Evidence:` line the commit can carry once the ledger shows every run
  passed.

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

## Fix by family (rule 10)

The sound engine library on `sound-engine-library` is the source; the tools
read it rather than keep their own copy.

- **Before a game runs:** `python3 ../method/tools/game.py <its folder>` finds
  its driver files by the names the census knows, hashes them as the census
  does, and looks up the game in inventory.md, each version in census.md and
  its families in matrix.toml, with the findings its family page names. It
  exits 1 and says what to add when the notes lack a game, a driver version,
  a trace or a family. Engines built into the game have no driver file: the
  inventory row is their only record. A game that runs from its disc image
  keeps its drivers there, to be scanned by hand.
- **The survey:** `plan.py --family <family>` plans one traced game per driver
  version of the family's digital drivers (`survey` in `[families]`;
  `--driver` for others), each run as its driver's card, plus every traced
  game of the family whose engine is built in. A version nobody has traced
  is listed under Blocked with the games that carry it. Survey games are
  named as the census names them; `[launchers]` maps a folder name to its
  launcher where they differ.
- **The commit:** `Family:`, the row on the family page first, and the survey
  in the cited plan (see "The hook").

## The ledger

Evidence is what a tool wrote, not what an agent says. The runners record
each verdict once a run is judged:

    python3 ../method/tools/ledger.py record <tag> <run> pass|fail \
        --build-dir <the directory the run's UCDD.EXE came from> \
        --tool runs/sndreg/sndreg.py --tool runs/rec/audiocmp.py --output <the recording>

- **What an entry holds:** the time, the plan and run, the verdict, the hash
  of every EXE and BIN in the build directory, the hash of each tool given
  (the bench is not versioned, so this pins the instruments), the hash of
  each output, and the host.
- **Where it lives:** `ledger/` beside this README (ignored by git), or
  `[ledger] path` in method.toml, or `UCDD_LEDGER`. The ledger is append
  only: `runs.jsonl` and the saved plans in `plans/`.
- **Who writes it:** the runners only. `record` refuses a plan that was not
  saved first (`plan.py --save`) and a run the plan does not have. The guard
  refuses `ledger.py record` typed by Claude, edits of the ledger's files, and
  shell commands that name them. Michael can record a run by hand in his own
  shell.
- **Reading it:** `ledger.py show <tag>` (every run's latest verdict), `spot`
  and `audit` (below).
- **Turning it on fully:** with `[ledger] require = true`, every emulator line
  must name a recorded plan. Leave it off until the runners call `record`,
  then switch it on.
- **What it does not stop:** an agent that edits a runner to record a pass it
  did not see. That is deliberate forgery, not a rounded-up summary, and the
  spot checks are there to catch it.

**The spot check before `fixes`.** A session with no stake in the fix runs
`ledger.py spot <tag>`, which picks two passed runs at random and prints
their commands. It re-runs them with `UCDD_SPOT=1` set, so the runner records
them as spot checks. Then `ledger.py audit <tag>` compares each with its
first verdict. A disagreement stops the merge: it is a finding about the fix
or about the instrument (L11).

## Game code

We never ship, patch or alter game code. Any DOS game, as it was sold, must
run with uCDD as it would on the real hardware, with no patch, extra file or
setting for that game. Decompiled or traced code only teaches what a game
expects of the hardware; the notes say it in words.

- **The hook** refuses game files, listings and games named in driver code
  (see "The hook").
- **The guard** refuses a write into the game library: an edit, an overwrite
  (`cp` onto it, `>`, `dd of=`, `xxd -r`), a move or a removal, and an in-place
  `sed`/`perl`. Reading, hex dumps, disassembling into another directory and
  copying out are allowed, and so are the runners, which set a game's own
  configuration as its setup program would. Set `[games] paths` in
  method.local.toml to the library and its disc images (or `UCDD_GAMES`).
- **The GitHub tools** cannot commit files (the guard refuses
  `create_or_update_file`, `push_files` and `delete_file`): commits are made
  with git, where the hook sees them.

## Nothing goes upstream

Nothing from this fork goes to vorvek (Michael, 20 Oct 2026). What reaches
him on GitHub, and what does not:

- **Reaches him:** a pull request or issue on his repository, a comment
  there, an @mention of him, and a link to one of his issues or pull
  requests from a commit or a note (it shows on that issue).
- **Does not reach him:** pushes to this fork, its branches and any CI it
  runs. The fork is public, though, and listed among his repository's
  forks, so anyone, him included, can read it.

The hook refuses the mention and the links. The guard refuses a push to his
repository, gh and GitHub-tool writes there, and a `gh pr create` that does
not name `--repo EarBoye/uCDD` (in a fork, gh and GitHub's own page offer
the original repository as the target).

## On GitHub

The workflow lives on `fixes` as `.github/workflows/method.yml` (a copy of
`ci/method.yml`; Michael, 20 Oct: acceptable on fixes for now, to be
reviewed). It runs only in this fork.

- **When:** on a push to a branch that has the file (fixes, and branches
  made from it or merged with it after the file went in), every hour for
  every branch, and from the Actions tab (Run workflow).
- **What:**
  - Every branch head with scripts/build.py is built with each variant in
    `[identical] variants`, and the headroom of UCDD.EXE, the host,
    UCDDPLAY and UCDDSET is reported against build.py's limits, naming the
    build where each is tightest.
  - Every commit made after `[ci] check_after` gets the hook's checks, apart
    from the ledger, which is on the bench. A commit made with the hook off,
    or from another clone, shows up here.
- **Where the results go:** commit statuses (`method/build` on a head,
  `method/commits` on each commit; a commit that has one is not checked
  again) and the run's summary. GitHub tells the account that last changed
  the schedule in the workflow file when a scheduled run fails.
- **Turning it on:**
  - If the Actions tab says workflows are not run on this fork, enable them
    there.
  - Set `[ci] check_after` to the time the hook went in (a commit on this
    branch). Until then only the builds are checked.
  - If this branch is renamed, set the repository variable `METHOD_REF` to
    the new name.
- **What it cannot do:** run 86Box, the games or the PC; read the ledger.

Locally: `python3 tools/ci.py --dry-run [--branch NAME] [--check-after DATE]`
from a clone.

## The tally

    python3 ../method/tools/trailers.py [--since 2026-10-01] [refs]

This counts each Issue:, Lesson: and Evidence: grade across the history,
with dates. A row that keeps coming back in Issue: trailers is a fault that
was not fixed by family.

The lessons' weights are not computed here. LESSONS.md and its
`lessons.py` hold them: each hit scored by its severity (1 to 4) and doubled
when the answer was already written and not used. A `Lesson: Ln` trailer
only links a commit to the lesson it hit, so the Lesson counts here are a
cross-check: every trailer should have its hit line in the register.

## Not done yet

- **`[games] paths`** belongs in the bench's method.local.toml, or the guard
  cannot protect the library.
- **The runners do not record yet.** regress.sh, sndreg, game_live.py and
  probe_test.py each need a `ledger.py record` call after a run is judged,
  with the build directory, the tools and the outputs; then `[ledger]
  require = true`.
- **Lines marked "check" in matrix.toml** are the seed's best reading of the
  bench's report: the PROBE_RUN names, the GL_CFG_V4 fields, the runners'
  arguments, the bset suffixes, and what some probes check. The `[builds]`
  options must be the ones bset.sh uses, or the hook's binary comparison
  will refuse good runs.
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
- **`[ci] check_after`** is empty: GitHub builds every branch but checks no
  commits until it is set to the time the hook went in.
- **An amend** can fold a row into the code commit it should precede. The
  hook sees only the parent.

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
> 6. Make the runners call `ledger.py record` after each judged run, then set
>    `[ledger] require = true`.
> 7. Then plan the next change with `plan.py --save` before running anything.
>
> Where this disagrees with your guards or the lessons register, say so to Michael
> rather than working around either.
