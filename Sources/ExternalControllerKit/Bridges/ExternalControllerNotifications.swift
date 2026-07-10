import Foundation

public extension Notification.Name {
    static let externalControllerDevicesChanged = Notification.Name("ExternalController.devicesChanged")
    static let externalControllerMappingsChanged = Notification.Name("ExternalController.mappingsChanged")
    static let externalControllerStateChanged = Notification.Name("ExternalController.stateChanged")
    static let externalControllerActionTriggered = Notification.Name("ExternalController.actionTriggered")
}

public enum ExternalControllerNotificationUserInfoKey {
    public static let devices = "devices"
    public static let mappings = "mappings"
    public static let state = "state"
    public static let actionId = "actionId"
    public static let deviceId = "deviceId"
    public static let buttonId = "buttonId"
}
