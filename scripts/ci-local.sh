#!/usr/bin/env bash
set -euo pipefail

xcodegen generate
swiftlint lint --strict
swift test
xcodebuild build \
  -scheme "${SCHEME:-FindMe}" \
  -destination "${DESTINATION:-generic/platform=iOS Simulator}" \
  CODE_SIGNING_ALLOWED=NO
