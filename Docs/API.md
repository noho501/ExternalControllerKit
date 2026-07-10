# API

## Core entry point

```swift
let controller = ExternalController.shared
controller.configure(actions: [
    ActionDefinition(actionId: "host.jump", displayTitle: "Jump")
])
controller.start()
```

## Mapping APIs

- `startListening(for:)`
- `stopListening()`
- `assign(deviceId:inputId:actionId:)`
- `mapping(for:deviceId:)`
- `mappings(for:)`
- `allMappings()`
- `resetAllMappings()`

## Device APIs

- `connectedDevices`
- `selectedDeviceId`
- `setSelectedDevice(id:)`
- `refreshConnectedDevices()`

## Event APIs

- `delegate`
- `observe(...)`
- NotificationCenter notifications in `ExternalControllerNotifications.swift`

Runtime action callbacks include `actionId`, `deviceId`, `inputId`, and `InputValue`.

Listening mode still assigns only digital button activation events.

## Persistence

Inject any custom `MappingStorage` implementation into `ExternalController`.
