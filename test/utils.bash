#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/utils.bash
source "$repo_root/lib/utils.bash"

failures=0

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [ "$expected" != "$actual" ]; then
    echo "FAIL: $message -- expected '$expected', got '$actual'"
    failures=$((failures + 1))
  else
    echo "PASS: $message"
  fi
}

assert_true() {
  local message="$1"
  shift

  if "$@"; then
    echo "PASS: $message"
  else
    echo "FAIL: $message"
    failures=$((failures + 1))
  fi
}

assert_false() {
  local message="$1"
  shift

  if "$@"; then
    echo "FAIL: $message"
    failures=$((failures + 1))
  else
    echo "PASS: $message"
  fi
}

jdtls_list_versions() {
  cat <<'EOF'
1.30.1
1.40.0
1.54.0
1.55.0
1.57.0
EOF
}

assert_true "version_ge handles newer semver" version_ge 1.55.0 1.54.0
assert_false "version_ge handles older semver" version_ge 1.30.1 1.55.0
assert_eq 17 "$(jdtls_min_java_for_version 1.54.0)" "1.54.0 requires Java 17"
assert_eq 21 "$(jdtls_min_java_for_version 1.55.0)" "1.55.0 requires Java 21"
assert_eq 1.57.0 "$(jdtls_resolve_version latest)" "latest resolves to newest version"
assert_eq 1.54.0 "$(jdtls_latest_compatible_version 17)" "latest Java 17 compatible release resolves correctly"
assert_eq 1.57.0 "$(jdtls_latest_compatible_version 21)" "latest Java 21 compatible release resolves correctly"
assert_eq 1.54.0 "$(jdtls_resolve_version latest-java17)" "latest-java17 alias resolves correctly"
assert_eq 1.57.0 "$(jdtls_resolve_version latest-java21)" "latest-java21 alias resolves correctly"

if [ "$failures" -ne 0 ]; then
  echo
  echo "$failures test(s) failed"
  exit 1
fi

echo
echo "All tests passed"
