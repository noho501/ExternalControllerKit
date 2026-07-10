# Architecture

ExternalControllerKit is split into five layers:

1. Models define devices, button events, actions, mappings, and manager state.
2. Providers normalize GameController, Keyboard, and MIDI input into `ButtonEvent` values.
3. `ExternalController` owns connected devices, exclusive listening state, mapping rules, runtime input gating, and action dispatch.
4. Persistence is abstracted behind `MappingStorage`, with a default `UserDefaultsMappingStorage` implementation and legacy-key migration support.
5. `ExternalControllerKitUI` is an optional UIKit configuration layer that reads manager state instead of owning it.

Runtime flow:

1. Providers emit normalized `ButtonEvent` instances.
2. `ExternalController` applies listening rules first.
3. If idle, the manager resolves mappings by exact `(deviceId, buttonId)` match.
4. The manager emits action IDs through delegates, observation closures, and NotificationCenter.
5. The host app decides what each action ID means.
