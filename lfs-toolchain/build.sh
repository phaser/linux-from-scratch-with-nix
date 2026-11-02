#!/usr/bin/env bash
  set -euo pipefail
  attr=${1:-binutils}
  link=${2:-result-$attr}
  root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
  nix-build -E "(builtins.getFlake \"$root\").legacyPackages.aarch64-linux" \
    -A "$attr" -o "$root/$link"
