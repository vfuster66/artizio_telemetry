#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
canonical_dir="$(cd "$script_dir/.." && pwd -P)"
workspace_dir="$(cd "$canonical_dir/.." && pwd -P)"
apps=(frezio_flutter staggio_flutter surfacio_flutter trajio_flutter)
status=0

for app in "${apps[@]}"; do
  integration="$workspace_dir/$app/packages/artizio_telemetry"
  if [[ ! -L "$integration" ]]; then
    echo "ERROR: $integration is not a symbolic link." >&2
    status=1
    continue
  fi

  target="$(cd "$integration" && pwd -P)"
  if [[ "$target" != "$canonical_dir" ]]; then
    echo "ERROR: $integration points to $target, expected $canonical_dir." >&2
    status=1
    continue
  fi

  echo "OK: $app -> $canonical_dir"
done

exit "$status"
