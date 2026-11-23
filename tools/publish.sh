#!/bin/sh
# Publish the book: build its website into .build/site.
# The Incipit is the repo's README.md; every other chapter lives in book/.
set -eu
cd "$(dirname "$0")/.."
rm -rf .build
mkdir -p .build/src
# On GitHub the Incipit links into book/; on the site every chapter sits beside it.
sed "s#](book/#](#g" README.md > .build/src/README.md
cp book/*.md .build/src/
mdbook build
echo "published: .build/site"
