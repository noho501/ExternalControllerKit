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
- `assign(deviceId:buttonId:actionId:)`
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

## Persistence

Inject any custom `MappingStorage` implementation into `ExternalController`.
