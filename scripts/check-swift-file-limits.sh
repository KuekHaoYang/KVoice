#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAX_SWIFT_LINES=300
MAX_PRODUCTION_LINES=250
FAILED=0

while IFS= read -r -d '' file; do
  lines="$(wc -l < "$file" | tr -d '[:space:]')"
  if (( lines > MAX_SWIFT_LINES )); then
    printf 'ERROR: %s has %s lines; limit is %s.\n' "$file" "$lines" "$MAX_SWIFT_LINES" >&2
    FAILED=1
  fi
  case "$file" in
    "$ROOT"/Sources/*)
      if (( lines > MAX_PRODUCTION_LINES )); then
        printf 'ERROR: %s has %s lines; production limit is %s.\n' \
          "$file" "$lines" "$MAX_PRODUCTION_LINES" >&2
        FAILED=1
      fi
      ;;
  esac
done < <(find "$ROOT/Sources" "$ROOT/Tests" -type f -name '*.swift' -print0)

if (( FAILED != 0 )); then
  exit 1
fi

printf 'Swift file limits passed.\n'
