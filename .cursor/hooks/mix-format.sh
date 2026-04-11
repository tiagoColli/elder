#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.path // empty')

if [[ -z "$file_path" ]]; then
  exit 0
fi

if [[ "$file_path" != *.ex && "$file_path" != *.exs ]]; then
  exit 0
fi

mix format "$file_path" 2>/dev/null || true

exit 0
