#!/bin/sh
# Prove the prose rules work: every line in tests/prose/bad.md trips its
# expected rule, and tests/prose/good.md is clean.
set -u
cd "$(dirname "$0")/.."
out=$(vale --output=line tests/prose/bad.md 2>&1)
fail=0
while read -r line rule; do
  if ! printf '%s\n' "$out" | grep -q "bad.md:$line:[0-9]*:$rule:"; then
    echo "MISSED line $line: $rule"; fail=1
  fi
done < tests/prose/expect.txt
good=$(vale --output=line tests/prose/good.md 2>&1)
if [ -n "$good" ]; then echo "good.md is not clean:"; printf '%s\n' "$good"; fail=1; fi
[ $fail -eq 0 ] && echo "prose rules: $(wc -l < tests/prose/expect.txt | tr -d ' ') fire as expected; good.md clean"
exit $fail
