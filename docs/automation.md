# Automated iOS Development Flow

This repository is set up for a low-cost issue-to-TestFlight workflow:

1. Create a GitHub Issue with clear acceptance criteria.
2. Ask Codex Free to implement the issue on a branch and open a PR.
3. GitHub Actions runs XcodeGen, SwiftLint, Swift Package tests, and a simulator-generic Xcode app build.
4. Ask Claude Free to review the PR diff and CI output.
5. Merge after approval and green CI.
6. Run the `TestFlight` workflow manually when you want to distribute a build.

## Required local tools

- Xcode 26 or newer
- `xcodebuild`
- XcodeGen
- SwiftLint
- Ruby/Bundler
- Fastlane
- GitHub CLI (`gh`)

Run:

```bash
./scripts/bootstrap.sh
```

## Required GitHub settings

Enable branch protection for `main`:

- Require pull request before merging
- Require status checks to pass: `build-test`
- Require conversation resolution
- Disable direct pushes to `main`

Optional labels:

- `feature`
- `bug`
- `codex`
- `needs-review`
- `testflight`

## TestFlight secrets

Create a GitHub Environment named `testflight`, then add these secrets:

- `APP_IDENTIFIER`: bundle identifier, for example `com.example.findme`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_P8`: base64 encoded `.p8` key content
- `APP_STORE_CONNECT_TEAM_ID`
- `DEVELOPER_PORTAL_TEAM_ID`

The TestFlight workflow is manual (`workflow_dispatch`) to avoid accidental uploads and unnecessary macOS minutes.

## Apple official MCP

Keep the Apple official Xcode MCP configured on developer machines for future Codex CLI / Claude Code workflows. CI should stay scriptable with XcodeGen, `xcodebuild`, SwiftLint, and Fastlane so it also works without the MCP bridge.


## CI reliability notes

The pull-request workflow intentionally uses `macos-15` instead of `macos-latest` and builds with `generic/platform=iOS Simulator`. This avoids two common sources of free-runner flakes: hosted-image migration notices and unavailable named simulators such as `iPhone 16`. Swift package tests still validate `FindMeCore`; the Xcode step validates that the generated app project builds without requiring code signing.
