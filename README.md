# ExternalControllerKit

ExternalControllerKit is a generic SDK for mapping external hardware input to host-defined action IDs. The package keeps business logic in the host app and supports GameController, Keyboard (`GCKeyboard`), and MIDI (`CoreMIDI`) providers in v1.

## What it solves

- Normalize supported external input providers into shared input events.
- Persist per-device mappings.
- Expose exclusive listening mode for configuration flows.
- Emit action IDs with input values so the host app controls behavior.
- Offer an optional UIKit mapping UI for parity migrations.

## Supported providers

- GameController
- Keyboard (`GCKeyboard`)
- MIDI (`CoreMIDI`)

Not included in v1:

- BLE
- CoreBluetooth
- Auto-pairing or custom hardware connection flows
- App-specific business logic

## Installation

Add the package in Swift Package Manager and choose one or both library products:

- `ExternalControllerKit`
- `ExternalControllerKitUI`

## Quick start

```swift
import ExternalControllerKit

let controller = ExternalController.shared
controller.configure(actions: [
    ActionDefinition(actionId: "host.jump", displayTitle: "Jump"),
    ActionDefinition(actionId: "host.pause", displayTitle: "Pause")
])
controller.start()

let observation = controller.observe(onActionTriggered: { actionId, deviceId, inputId, value in
    print("Host executes behavior for \(actionId) from \(deviceId) / \(inputId) with \(value)")
})
```

## Defining and registering actions

Actions are host-defined. Each `ActionDefinition` includes:

- `actionId` (stable string)
- `displayTitle`
- optional `groupingKey`
- optional `sortOrder`
- optional metadata dictionary

The SDK stores action IDs and emits `actionId` plus the triggering `InputValue`.

## Listening and mapping flow

1. Select a device.
2. Call `startListening(for:)`.
3. The next pressed digital button from the selected device is assigned.
4. Existing conflicts on that same device are replaced.
5. Listening ends automatically after a successful assignment.

## Runtime callback handling

When `ExternalController` is idle and input is enabled, mapped inputs emit action events through:

- delegate callbacks
- observation closures
- NotificationCenter notifications

The host app decides what each action ID should do.

## Selected device behavior and manual refresh

- Selected-device filtering applies only while listening.
- Runtime input accepts mapped events from all mapped devices.
- `refreshConnectedDevices()` re-queries long-lived providers.
- Refresh does not recreate providers or clear mappings.

## Persistence and customization

Mappings are stored through `MappingStorage`.

The default implementation is `UserDefaultsMappingStorage`, which supports:

- configurable storage keys
- empty/corrupt-data fallback safety
- optional migration from legacy key `external_controller_mappings`

Customizable surfaces include:

- persistence backend
- logger
- notification names
- UI localization strings
- UI input label formatting
- UI device filtering and sorting
- UI action sorting

## Optional UIKit module

`ExternalControllerKitUI` includes `ExternalControllerConfigurationViewController`, which preserves the existing interaction model:

- selected device control
- manual refresh button
- reset all
- close button
- exclusive listening indicator
- adaptive action grid

While the UI is visible, runtime input is disabled and listening is stopped on dismissal.

## Migration from an existing in-app implementation

1. Extract provider logic, models, and manager state into `ExternalControllerKit`.
2. Replace app-specific action enums with host-defined `ActionDefinition` values.
3. Keep host-side business handlers in the app and respond to emitted `actionId` values.
4. Present the optional UIKit configuration screen for parity with the prior in-app flow.

See `Docs/Migration.md` and `Docs/Architecture.md` for more detail.

## Example app

`Examples/ExternalControllerKitExampleApp/ExampleHostViewController.swift` demonstrates:

- dynamic action registration through `configure(actions:)`
- presenting the mapping UI
- host-controlled runtime callbacks
- persistent mappings across relaunch through the shared controller
- selected-device listening behavior

To run the sample app in Xcode:

1. Open `Examples/ExternalControllerKitExampleApp/ExternalControllerKitExampleApp.xcodeproj`.
2. Select the `ExternalControllerKitExampleApp` scheme.
3. Run on an iOS 15+ simulator or device.

The sample project uses the package in this repository through a local Swift Package dependency, so changes under `Sources/` are reflected directly in the sample app.

## Limitations and roadmap

- v1 intentionally excludes BLE and CoreBluetooth.
- Controller-specific stable IDs depend on the best attributes exposed by Apple frameworks.
- Future releases can add optional providers, including BLE, without changing the action-mapping runtime model.
