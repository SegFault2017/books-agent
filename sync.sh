#!/bin/sh
# Copy every /book-to-skill output from ~/.agents/skills into skills/.
# Book skills are the ones whose description starts with "Knowledge base from".
set -eu
src="${1:-$HOME/.agents/skills}"
dest="$(dirname "$0")/skills"
mkdir -p "$dest"
for f in "$src"/*/SKILL.md; do
  name="$(basename "$(dirname "$f")")"
  [ "$name" = book-to-skill ] && continue
  grep -q '^description: "Knowledge base from' "$f" || continue
  rm -rf "$dest/$name"
  cp -RL "$(dirname "$f")" "$dest/$name"
  echo "synced $name"
done
