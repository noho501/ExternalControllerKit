# Architecture

ExternalControllerKit is split into five layers:

1. Models define devices, input events, input values, actions, mappings, and manager state.
2. Providers normalize GameController, Keyboard, and MIDI input into `InputEvent` values.
3. `ExternalController` owns connected devices, exclusive listening state, mapping rules, runtime input gating, and action dispatch.
4. Persistence is abstracted behind `MappingStorage`, with a default `UserDefaultsMappingStorage` implementation and legacy-key migration support.
5. `ExternalControllerKitUI` is an optional UIKit configuration layer that reads manager state instead of owning it.

Runtime flow:

1. Providers emit normalized `InputEvent` instances with `deviceId`, `inputId`, and `value`.
2. `ExternalController` applies listening rules first and only accepts digital activation events while listening.
3. If idle, the manager resolves mappings by exact `(deviceId, inputId)` match.
4. The manager emits action IDs plus input values through delegates, observation closures, and NotificationCenter.
5. The host app decides what each action ID means.
