#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PREFIX_CHANNEL:-}" ]]; then
  echo "error: set PREFIX_CHANNEL to your prefix.dev channel name" >&2
  exit 2
fi

shopt -s nullglob
packages=("$@")
if [[ ${#packages[@]} -eq 0 ]]; then
  packages=(dist/conda/**/*.conda)
fi

if [[ ${#packages[@]} -eq 0 ]]; then
  echo "error: no .conda packages found; run 'pixi run build-recipe' first" >&2
  exit 2
fi

cmd=(
  rattler-build upload
  prefix
  --channel "${PREFIX_CHANNEL}"
  --skip-existing
)

redacted_cmd=("${cmd[@]}")
if [[ -n "${PREFIX_API_KEY:-}" ]]; then
  cmd+=(--api-key "${PREFIX_API_KEY}")
  redacted_cmd+=(--api-key "********")
fi

cmd+=("${packages[@]}")
redacted_cmd+=("${packages[@]}")

echo "+ ${redacted_cmd[*]}"
"${cmd[@]}"
