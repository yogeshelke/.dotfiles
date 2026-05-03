#!/bin/bash
# Auto-format .tf files after edits using terraform fmt.
# This hook is triggered by Cursor's afterFileEdit event.
# It reads the edited file path from stdin JSON and runs terraform fmt on it.

input=$(cat)
file_path=$(echo "$input" | jq -r '.path // empty')

if [[ -z "$file_path" ]]; then
  exit 0
fi

if [[ "$file_path" == *.tf ]]; then
  if command -v terraform &>/dev/null; then
    terraform fmt "$file_path" 2>/dev/null
  fi
fi

exit 0
