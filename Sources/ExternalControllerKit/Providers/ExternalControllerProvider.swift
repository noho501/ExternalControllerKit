import Foundation

@MainActor
public protocol ExternalControllerProviderDelegate: AnyObject {
    func provider(_ provider: any ExternalControllerProvider, didReceive event: ButtonEvent)
    func provider(_ provider: any ExternalControllerProvider, didConnect device: Device)
    func provider(_ provider: any ExternalControllerProvider, didDisconnect device: Device)
}

@MainActor
public protocol ExternalControllerProvider: AnyObject {
    var providerKind: DeviceKind { get }
    var connectedDevices: [Device] { get }
    var delegate: (any ExternalControllerProviderDelegate)? { get set }
    func start()
    func stop()
    func refreshConnectedDevices()
}
