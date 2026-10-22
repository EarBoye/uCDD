#!/bin/sh
# Commit whatever changed in the bench repository and push it: the runners,
# the notes, the ledger. Folders that must live elsewhere (Claude's memory,
# say) are first copied in under mirror/<name>. From the user's crontab, no
# root needed:
#
#   17 * * * *  sh <method>/bench/backup.sh <bench repository> [<folder> ...] >> <bench>/backup.log 2>&1
#
# The pre-commit hook still refuses game, program, disc and big files; a
# refused backup leaves everything staged and says why in the log.

set -eu
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
git commit -q -m "Backup: $(date -u +%Y-%m-%dT%H:%MZ)"
# Name the branch: the first backup of a new repository has no upstream yet.
git push -q origin HEAD
echo "$(date -u +%Y-%m-%dT%H:%MZ) backed up $(git rev-parse --short HEAD)"
