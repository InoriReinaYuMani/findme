#!/usr/bin/env bash
set -euo pipefail

xcodegen generate
swiftlint lint --strict
swift test
xcodebuild test \
  -scheme "${SCHEME:-FindMe}" \
  -destination "${DESTINATION:-platform=iOS Simulator,name=iPhone 16}" \
  -enableCodeCoverage YES
