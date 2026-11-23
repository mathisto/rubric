#!/bin/sh
# The checks every commit must pass. CI runs this file; so should you.
# tests/prose holds deliberately bad prose, so it is left out of the prose
# check and proved by prose-test.sh instead.
set -eu
cd "$(dirname "$0")/.."

echo "== prose"
vale README.md book research styles/README.md
sh tools/prose-test.sh

echo "== code"
zig fmt --check gen
# Build the extractor from gen, as the book last left it, and run its tests.
(cd gen && zig build --prefix ../.build/extractor --cache-dir ../.build/zig-cache)
(cd gen && zig build test --cache-dir ../.build/zig-cache)

echo "== the book and gen agree"
.build/extractor/bin/extract --out .build/fresh --rules
if ! diff -r gen .build/fresh; then
    echo "gen differs from the book. Fix the book, then run tools/extract.sh." >&2
    exit 1
fi

echo "== the program at every chapter"
for chapter in $(sed -n "s/.*](\([^)]*\)).*/\1/p" book/SUMMARY.md); do
    .build/extractor/bin/extract --through "$chapter" --out .build/snapshot
    if [ -f .build/snapshot/build.zig ]; then
        (cd .build/snapshot && zig build test --cache-dir ../zig-cache)
        echo "$chapter: builds and passes its tests"
    else
        echo "$chapter: no code yet"
    fi
done
echo "gate: all checks passed"
