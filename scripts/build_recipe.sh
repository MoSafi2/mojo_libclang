#!/usr/bin/env bash
set -euo pipefail

recipe="${RECIPE_PATH:-packaging/modular-community/libclang_mojo/recipe.yaml}"
output_dir="${CONDA_BLD_PATH:-dist/conda}"

cmd=(
  rattler-build build
  --recipe "${recipe}"
  --output-dir "${output_dir}"
  --channel conda-forge
  --channel https://conda.modular.com/max
)

if [[ -n "${PREFIX_CHANNEL:-}" ]]; then
  cmd+=(--channel "https://prefix.dev/${PREFIX_CHANNEL}")
fi

cmd+=("$@")

echo "+ ${cmd[*]}"
"${cmd[@]}"
