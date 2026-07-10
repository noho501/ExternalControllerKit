# Migration

## Phase 1: Core extraction

- Replace app-specific action enums with `ActionDefinition` values that contain host-defined `actionId` strings.
- Move mapping persistence behind `MappingStorage`.
- Start the singleton manager early and keep providers long-lived.

## Phase 2: Host integration

- Call `configure(actions:)` with the host app's action catalog.
- Subscribe to runtime events via delegate, observation closures, or NotificationCenter.
- Execute all business behavior in the host when action IDs are triggered.

## Phase 3: UI extraction

- Present `ExternalControllerConfigurationViewController` from the optional UIKit module.
- Disable runtime input while the UI is visible and stop listening on dismissal.
- Keep selected-device filtering only for listening mode.

## Phase 4: Parity validation

- Verify per-device mapping independence.
- Verify conflict replacement on the same device.
- Verify persistence across relaunch.
- Verify listening only accepts the selected device.
- Verify runtime input accepts events from all mapped devices.
