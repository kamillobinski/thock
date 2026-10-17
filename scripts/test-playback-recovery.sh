#!/bin/sh
set -eu
repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/thock-recovery-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
xcrun swiftc -swift-version 5 -module-cache-path "$test_dir/module-cache" \
  "$repo_dir/Thock/Managers/PlaybackRecoveryGuard.swift" \
  "$repo_dir/scripts/tests/PlaybackRecoveryGuardTests.swift" \
  -o "$test_dir/recovery-guard-tests"
"$test_dir/recovery-guard-tests"
