# The bench repository

On 22 Oct 2026 the bench machine failed and its bench folder was lost with
it: none of it was in git. This kit makes the bench a private GitHub
repository with an hourly backup, so a lost machine costs an afternoon, not
the bench.

## What goes in, what stays out

- **In:** the runners and their wiring, the test programs' sources, the
  86Box machine configurations (text), the kit scripts, the notes (CONTEXT,
  HANDOFF, STATE, LESSONS and lessons.py), Claude's project settings and
  skill links, Claude's memory (mirrored in by backup.sh), the bench's
  method.local.toml, and the ledger.
- **Out:** the games and their disc images (never in any repository); built
  binaries (UCDD.EXE, the test .COM programs, the kits: they come back from
  their sources); recordings, ROMs and disk images (game content or licensed
  software: back them up apart, on a disk); any file over 20 MB.
- **Private:** the repository may hold the bench's own paths and account
  name. The public fork may not; its hook refuses home paths.

The pre-commit hook (`bench/hooks/pre-commit`, settings in `bench.toml`)
refuses game, program, disc, recording and image files and anything over
20 MB. An exception goes in `.bench-allow` at the top of the bench
repository, one shell glob a line, with a comment saying why.

## Setting it up, once

1. Michael creates `EarBoye/ucdd-bench` on github.com/new: **Private**, empty
   (no README, no licence).
2. In the bench's top directory, the one holding the bench folder and the
   notes:

       git init -b main
       cp <method>/bench/gitignore .gitignore     # then name the folders the bench keeps
       git config core.hooksPath <method>/bench/hooks
       git remote add origin https://github.com/EarBoye/ucdd-bench.git

   The game libraries may sit in the same directory: the `.gitignore`
   ignores everything it does not name.
3. Move the bench's own settings in, so a restore brings them back:
   - the ledger: `[ledger] path = "<top>/ledger"` in method.local.toml, and
     move the ledger's files there if it has any;
   - method.local.toml itself: move it to `<top>/method.local.toml` and set
     `UCDD_METHOD_LOCAL` to that path where the hook, the guard and the
     runners run.
4. Look before the first commit: `git status --short` must list nothing from
   a game library, no recording, no build output. Then:

       git add -A && git commit -m "Bench: first commit" && git push -u origin main

5. The hourly backup, from the user's crontab (`crontab -e`, no root needed):

       17 * * * * sh <method>/bench/backup.sh <top> <Claude's memory folder> >> <top>/backup.log 2>&1

   An hour later `backup.log` names a commit (or is silent when nothing
   changed), and GitHub shows it.

The method guard refuses shell commands that name the ledger's files.
`backup.sh` adds everything with `git add -A` and runs as a script, so it is
not refused. Never check out, reset or revert the ledger: it only grows.

## On a new machine

1. `git clone https://github.com/EarBoye/ucdd-bench.git <top>`, and copy
   `mirror/<memory>` back to Claude's memory folder.
2. Clone the fork, add the method branch as a worktree, and run
   `install.sh` for the worktrees and for Claude (see the method README).
3. Set `UCDD_METHOD_LOCAL`, `GAMES` and `PATH` (NASM), put the crontab line
   back, and run the self-tests: 51 run, none skipped.
4. Restore the games, recordings and images from their own backup.
