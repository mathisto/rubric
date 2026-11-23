#!/bin/sh
# Rewrite gen from the book. Run this after changing any code in a chapter.
# It runs the extractor twice: once to write the new extractor, once more so
# the new extractor writes gen itself. The gate checks that a third run
# would change nothing.
set -eu
cd "$(dirname "$0")/.."
for pass in 1 2; do
    (cd gen && zig build --prefix ../.build/extractor --cache-dir ../.build/zig-cache)
    .build/extractor/bin/extract --out gen
done
