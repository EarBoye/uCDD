#!/bin/sh
# Commit whatever changed in a bench repository, and push it when the
# repository has a remote. Folders that live elsewhere (Claude's memory) are
# first copied in under mirror/<name>. From the user's crontab, no root:
#
#   17 * * * *  sh <method>/bench/backup.sh <bench folder> >> <top>/backup.log 2>&1
#   19 * * * *  sh <method>/bench/backup.sh <top> <Claude's memory folder> >> <top>/backup.log 2>&1
#
# The bench folder pushes to the private GitHub repository; the top folder
# (notes, memory, ledger) has no remote and stays on this machine and its
# backup disk (bench/README.md).
#
# The bench's check (hooks/pre-commit) runs here before the commit, so a
# backup is checked whether the hook is installed or not. A refused backup
# leaves everything staged and says why in the log.

set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$1
shift
for folder in "$@"; do
    mkdir -p "$repo/mirror"
    if command -v rsync >/dev/null; then
        rsync -a --delete "$folder/" "$repo/mirror/$(basename "$folder")/"
    else
        rm -rf "$repo/mirror/$(basename "$folder")"
        cp -a "$folder" "$repo/mirror/"
    fi
done
cd "$repo"
git add -A
if git diff --cached --quiet; then
    exit 0
fi
python3 "$here/hooks/pre-commit" ||
    { echo "$(date -u +%Y-%m-%dT%H:%MZ) $repo not backed up" >&2; exit 1; }
git commit -q -m "Backup: $(date -u +%Y-%m-%dT%H:%MZ)"
if git remote get-url origin >/dev/null 2>&1; then
    # Name the branch: the first backup of a new repository has no upstream yet.
    git push -q origin HEAD
fi
echo "$(date -u +%Y-%m-%dT%H:%MZ) backed up $(git rev-parse --short HEAD)"
