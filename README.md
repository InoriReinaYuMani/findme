# FindMe

FindMe is a SwiftUI iOS sample app for creating a temporary room with a shared passphrase (合言葉) and sharing participant locations after the user grants location permission.

## What is included

- `FindMeApp/FindMeApp`: SwiftUI screens, map UI, and Core Location permission flow.
- `Sources/FindMeCore`: room validation, stable passphrase-to-room identifiers, and an in-memory room store.
- `Tests/FindMeCoreTests`: unit tests for room creation, validation, and location updates.

## Running the sample

1. Open the repository in Xcode 15 or newer.
2. Add `Sources/FindMeCore` as the `FindMeCore` package product if Xcode does not resolve the local Swift package automatically.
3. Create an iOS app target that uses the files under `FindMeApp/FindMeApp`.
4. Run on a physical device or simulator and allow location access when prompted.

## Production note

The included `InMemoryRoomStore` is intentionally local and testable. To share locations between different devices, implement the `RoomStore` protocol with a backend such as CloudKit, Firebase, or your own API, then inject it into `RoomViewModel`.


## Automation workflow

This repository uses XcodeGen, SwiftLint, GitHub Actions, and Fastlane to support an issue-to-TestFlight flow.

- Generate the Xcode project with `xcodegen generate`.
- Run local checks with `./scripts/ci-local.sh`.
- Pull requests run `.github/workflows/main.yml`.
- TestFlight uploads run manually through `.github/workflows/testflight.yml` after the required App Store Connect secrets are configured.

See `docs/automation.md` for the full operating procedure and required GitHub settings.
