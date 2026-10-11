# FindMe

FindMe is a SwiftUI iOS sample app for creating a temporary room with a shared passphrase (合言葉) and sharing participant locations after the user grants location permission.

## What is included

- `FindMeApp/FindMeApp`: SwiftUI screens, map UI, and Core Location permission flow.
- `Sources/FindMeCore`: room validation, stable passphrase-to-room identifiers, and an in-memory room store.
- `Tests/FindMeCoreTests`: unit tests for room creation, validation, and location updates.
- Target selection, approximate straight-line distance, and approaching/receding status (接近ナビ).

## Target tracking

After joining, select another participant under **接近ナビ**. The selected map marker turns orange,
and a card above the participant list shows their approximate distance and movement status.
Select another person or use **相手の選択を解除** to clear the history. Leaving also clears tracking.
Distance changes reflect movement by either person; the arrows are not compass directions or walking routes.

The tracker compares samples at least five seconds apart. Changes within 10 meters or the combined
GPS uncertainty are treated as roughly unchanged. Readings older than 30 seconds or with accuracy
worse than 50 meters hide the distance. Missing accuracy allows approximate distance but prevents
movement claims. These are conservative initial heuristics and still need outdoor device validation.

`RoomViewModel(store:)` supports injecting a backend or an in-memory store preloaded with test participants.
Room locations refresh every two seconds even when this device is stationary. A production store must
preserve measurement timestamps and horizontal accuracy, enforce room membership, and remove departed users.
The default store still has **no cross-device sharing**: a second iPhone will not appear until a server
implementation is connected. The `TargetTrackingView` Xcode preview shows the card without a backend.

See [target tracking checks](docs/target-tracking.md) for device acceptance steps and remaining work.

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
