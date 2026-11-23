#!/bin/sh
# Rewrite gen from the book. Run this after changing any code in a chapter.
# It runs the tangler twice: once to write the new tangler, once more so
# the new tangler writes gen itself. The gate checks that a third run
# would change nothing.
set -eu
cd "$(dirname "$0")/.."
for pass in 1 2; do
    (cd gen && zig build --prefix ../.build/tangler --cache-dir ../.build/zig-cache)
    .build/tangler/bin/tangle --out gen
done
