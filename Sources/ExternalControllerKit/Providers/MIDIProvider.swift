import Foundation
#if canImport(CoreMIDI)
import CoreMIDI
#endif

public final class MIDIProvider: ExternalControllerProvider {
    public weak var delegate: (any ExternalControllerProviderDelegate)?
    public let providerKind: DeviceKind = .midi
    public var connectedDevices: [Device] { Array(devices.values).sorted { $0.name < $1.name } }

    private let logger: any ExternalControllerLogger
    private var devices: [String: Device] = [:]
    #if canImport(CoreMIDI)
    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    #endif

    public init(logger: any ExternalControllerLogger = DisabledExternalControllerLogger()) {
        self.logger = logger
    }

    public func start() {
        #if canImport(CoreMIDI)
        guard client == 0 else { return }
        MIDIClientCreateWithBlock("ExternalControllerKit" as CFString, &client) { [weak self] notification in
            self?.handleNotification(notification.pointee)
        }
        MIDIInputPortCreateWithProtocol(client, "ExternalControllerKit.Input" as CFString, ._1_0, &inputPort) { [weak self] eventList, _ in
            self?.handleEventList(eventList.pointee)
        }
        refreshConnectedDevices()
        #endif
    }

    public func stop() {
        #if canImport(CoreMIDI)
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
            inputPort = 0
        }
        if client != 0 {
            MIDIClientDispose(client)
            client = 0
        }
        devices.removeAll()
        #endif
    }

    public func refreshConnectedDevices() {
        #if canImport(CoreMIDI)
        guard inputPort != 0 else { return }
        var refreshed: [String: Device] = [:]
        let sourceCount = MIDIGetNumberOfSources()
        for index in 0..<sourceCount {
            let source = MIDIGetSource(index)
            guard source != 0 else { continue }
            let device = makeDevice(for: source)
            refreshed[device.id] = device
            MIDIPortConnectSource(inputPort, source, Unmanaged.passUnretained(self).toOpaque())
        }
        let removedIds = Set(devices.keys).subtracting(refreshed.keys)
        devices = refreshed
        for device in connectedDevices {
            delegate?.provider(self, didConnect: device)
        }
        for removedId in removedIds {
            delegate?.provider(self, didDisconnect: Device(id: removedId, name: removedId, kind: .midi))
        }
        #endif
    }

    #if canImport(CoreMIDI)
    private func handleNotification(_ notification: MIDINotification) {
        logger.log(level: .debug, message: "MIDI notification \(notification.messageID.rawValue)")
        refreshConnectedDevices()
    }

    private func handleEventList(_ eventList: MIDIEventList) {
        let packetCount = Int(eventList.numPackets)
        var packet = eventList.packet
        for _ in 0..<packetCount {
            let words = Mirror(reflecting: packet.words).children.compactMap { $0.value as? UInt32 }
            for word in words where word != 0 {
                parseMIDIWord(word)
            }
            packet = MIDIEventPacketNext(&packet).pointee
        }
    }

    private func parseMIDIWord(_ word: UInt32) {
        let status = UInt8(word & 0xFF)
        let data1 = UInt8((word >> 8) & 0xFF)
        let data2 = UInt8((word >> 16) & 0xFF)
        let type = status & 0xF0
        guard let device = connectedDevices.first else { return }
        switch type {
        case 0x90:
            if data2 == 0 {
                emit(deviceId: device.id, buttonId: "NOTE_\(data1)", isPressed: false)
            } else {
                emit(deviceId: device.id, buttonId: "NOTE_\(data1)", isPressed: true)
            }
        case 0x80:
            emit(deviceId: device.id, buttonId: "NOTE_\(data1)", isPressed: false)
        case 0xB0:
            emit(deviceId: device.id, buttonId: "CC_\(data1)", isPressed: data2 > 0)
        default:
            break
        }
    }

    private func emit(deviceId: String, buttonId: String, isPressed: Bool) {
        logger.log(level: .debug, message: "MIDI event \(deviceId) \(buttonId) pressed=\(isPressed)")
        delegate?.provider(self, didReceive: ButtonEvent(deviceId: deviceId, buttonId: buttonId, isPressed: isPressed))
    }

    private func makeDevice(for endpoint: MIDIEndpointRef) -> Device {
        let name = midiStringProperty(kMIDIPropertyDisplayName, endpoint: endpoint) ?? midiStringProperty(kMIDIPropertyName, endpoint: endpoint) ?? "MIDI Device"
        let uniqueId = midiIntegerProperty(kMIDIPropertyUniqueID, endpoint: endpoint).map(String.init) ?? String(endpoint)
        return Device(id: "midi_\(uniqueId)", name: name, kind: .midi)
    }

    private func midiStringProperty(_ property: CFString, endpoint: MIDIEndpointRef) -> String? {
        var unmanaged: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(endpoint, property, &unmanaged) == noErr else { return nil }
        return unmanaged?.takeRetainedValue() as String?
    }

    private func midiIntegerProperty(_ property: CFString, endpoint: MIDIEndpointRef) -> Int32? {
        var value: Int32 = 0
        return MIDIObjectGetIntegerProperty(endpoint, property, &value) == noErr ? value : nil
    }
    #endif
}
