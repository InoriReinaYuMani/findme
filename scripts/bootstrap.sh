#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi

if ! command -v swiftlint >/dev/null 2>&1; then
  brew install swiftlint
fi

if ! command -v bundle >/dev/null 2>&1; then
  gem install bundler
fi

bundle install
xcodegen generate
