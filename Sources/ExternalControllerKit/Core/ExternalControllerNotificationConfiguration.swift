import Foundation

public struct ExternalControllerNotificationConfiguration: Sendable {
    public let devicesChanged: Notification.Name
    public let mappingsChanged: Notification.Name
    public let stateChanged: Notification.Name
    public let actionTriggered: Notification.Name

    public init(
        devicesChanged: Notification.Name,
        mappingsChanged: Notification.Name,
        stateChanged: Notification.Name,
        actionTriggered: Notification.Name
    ) {
        self.devicesChanged = devicesChanged
        self.mappingsChanged = mappingsChanged
        self.stateChanged = stateChanged
        self.actionTriggered = actionTriggered
    }

    public static let `default` = ExternalControllerNotificationConfiguration(
        devicesChanged: .externalControllerDevicesChanged,
        mappingsChanged: .externalControllerMappingsChanged,
        stateChanged: .externalControllerStateChanged,
        actionTriggered: .externalControllerActionTriggered
    )
}
