#!/bin/sh
# Build the public edition of the book into .build/site.
# The Incipit is the repo's README.md; every other chapter lives in book/.
set -eu
cd "$(dirname "$0")/.."
rm -rf .build
mkdir -p .build/src
cp README.md .build/src/README.md
cp book/*.md .build/src/
mdbook build
echo "book built: .build/site"
