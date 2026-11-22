#!/bin/sh
# The checks every commit must pass. CI runs this file; so should you.
# tests/prose holds deliberately bad prose, so it is left out here and
# proved by prose-test.sh instead.
set -eu
cd "$(dirname "$0")/.."
vale README.md book research styles/README.md
sh tools/prose-test.sh
