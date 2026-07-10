import XCTest
@testable import ExternalControllerKit

final class ExternalControllerManagerTests: XCTestCase {
    func testExclusiveListeningSameActionIsNoOp() async {
        await MainActor.run {
            let provider = TestProvider(kind: .keyboard, devices: [Device(id: "keyboard", name: "Keyboard", kind: .keyboard)])
            let controller = Self.makeController(provider: provider)
            var states: [ManagerState] = []
            let observation = controller.observe(onStateChanged: { states.append($0) })
            defer { observation.invalidate() }

            controller.startListening(for: "action.jump")
            controller.startListening(for: "action.jump")

            XCTAssertEqual(states, [.listening(actionId: "action.jump")])
            XCTAssertEqual(controller.state, .listening(actionId: "action.jump"))
        }
    }

    func testListeningAcceptsOnlySelectedDevice() async {
        await MainActor.run {
            let provider = TestProvider(kind: .gameController, devices: [
                Device(id: "pad1", name: "Pad 1", kind: .gameController),
                Device(id: "pad2", name: "Pad 2", kind: .gameController)
            ])
            let controller = Self.makeController(provider: provider)
            controller.setSelectedDevice(id: "pad1")
            controller.startListening(for: "action.jump")

            provider.send(InputEvent(deviceId: "pad2", inputId: "button_a", value: .button(true)))
            XCTAssertEqual(controller.allMappings(), [])
            XCTAssertEqual(controller.state, .listening(actionId: "action.jump"))

            provider.send(InputEvent(deviceId: "pad1", inputId: "button_a", value: .button(true)))
            XCTAssertEqual(controller.mapping(for: "action.jump", deviceId: "pad1"), Mapping(deviceId: "pad1", inputId: "button_a", actionId: "action.jump"))
            XCTAssertEqual(controller.state, .idle)
        }
    }

    func testListeningIgnoresAnalogInputs() async {
        await MainActor.run {
            let provider = TestProvider(kind: .gameController, devices: [Device(id: "pad1", name: "Pad 1", kind: .gameController)])
            let controller = Self.makeController(provider: provider)
            controller.setSelectedDevice(id: "pad1")
            controller.startListening(for: "action.look")

            provider.send(InputEvent(deviceId: "pad1", inputId: "left_stick_x", value: .axis(0.75)))

            XCTAssertEqual(controller.allMappings(), [])
            XCTAssertEqual(controller.state, .listening(actionId: "action.look"))
        }
    }

    func testRuntimeInputGateBlocksTriggersWhenDisabled() async {
        await MainActor.run {
            let provider = TestProvider(kind: .keyboard, devices: [Device(id: "keyboard", name: "Keyboard", kind: .keyboard)])
            let controller = Self.makeController(provider: provider)
            controller.assign(deviceId: "keyboard", inputId: "key_a", actionId: "action.jump")
            var triggered: [(String, String, String, InputValue)] = []
            let observation = controller.observe(onActionTriggered: { triggered.append(($0, $1, $2, $3)) })
            defer { observation.invalidate() }

            provider.send(InputEvent(deviceId: "keyboard", inputId: "key_a", value: .button(true)))
            controller.setInputEnabled(false)
            provider.send(InputEvent(deviceId: "keyboard", inputId: "key_a", value: .button(true)))

            XCTAssertEqual(triggered.count, 1)
            XCTAssertEqual(triggered.first?.0, "action.jump")
            XCTAssertEqual(triggered.first?.3, .button(true))
        }
    }

    func testRuntimeDispatchIncludesAnalogValues() async {
        await MainActor.run {
            let provider = TestProvider(kind: .gameController, devices: [Device(id: "pad1", name: "Pad 1", kind: .gameController)])
            let controller = Self.makeController(provider: provider)
            controller.assign(deviceId: "pad1", inputId: "left_stick_x", actionId: "action.look")
            var triggered: [(String, InputValue)] = []
            let observation = controller.observe(onActionTriggered: { triggered.append(($0, $3)) })
            defer { observation.invalidate() }

            provider.send(InputEvent(deviceId: "pad1", inputId: "left_stick_x", value: .axis(-0.75)))

            XCTAssertEqual(triggered, [("action.look", .axis(-0.75))])
        }
    }

    func testPerDeviceMappingsStayIndependent() async {
        await MainActor.run {
            let provider = TestProvider(kind: .gameController, devices: [
                Device(id: "pad1", name: "Pad 1", kind: .gameController),
                Device(id: "pad2", name: "Pad 2", kind: .gameController)
            ])
            let controller = Self.makeController(provider: provider)

            controller.assign(deviceId: "pad1", inputId: "button_a", actionId: "action.jump")
            controller.assign(deviceId: "pad2", inputId: "button_a", actionId: "action.jump")

            XCTAssertEqual(controller.mappings(for: "pad1"), [Mapping(deviceId: "pad1", inputId: "button_a", actionId: "action.jump")])
            XCTAssertEqual(controller.mappings(for: "pad2"), [Mapping(deviceId: "pad2", inputId: "button_a", actionId: "action.jump")])
        }
    }

    func testMappingConflictReplacementIsPerDevice() async {
        await MainActor.run {
            let provider = TestProvider(kind: .midi, devices: [Device(id: "midi1", name: "MIDI", kind: .midi)])
            let controller = Self.makeController(provider: provider)

            controller.assign(deviceId: "midi1", inputId: "note_60", actionId: "action.jump")
            controller.assign(deviceId: "midi1", inputId: "note_61", actionId: "action.jump")
            controller.assign(deviceId: "midi1", inputId: "note_61", actionId: "action.pause")

            XCTAssertEqual(controller.allMappings(), [Mapping(deviceId: "midi1", inputId: "note_61", actionId: "action.pause")])
        }
    }

    func testRefreshPreservesMappingsAndReusesProvider() async {
        await MainActor.run {
            let provider = TestProvider(kind: .keyboard, devices: [Device(id: "keyboard", name: "Keyboard", kind: .keyboard)])
            let controller = Self.makeController(provider: provider)
            controller.assign(deviceId: "keyboard", inputId: "key_a", actionId: "action.jump")

            controller.refreshConnectedDevices()

            XCTAssertEqual(provider.refreshCount, 1)
            XCTAssertEqual(controller.mapping(for: "action.jump", deviceId: "keyboard")?.inputId, "key_a")
        }
    }

    func testDeviceConnectDisconnectPropagatesIntoSnapshot() async {
        await MainActor.run {
            let provider = TestProvider(kind: .gameController, devices: [])
            let controller = Self.makeController(provider: provider)

            provider.connect(Device(id: "pad1", name: "Pad 1", kind: .gameController))
            XCTAssertEqual(controller.connectedDevices.map(\.id), ["pad1"])
            XCTAssertEqual(controller.selectedDeviceId, "pad1")

            provider.disconnect(deviceId: "pad1")
            XCTAssertEqual(controller.connectedDevices, [])
            XCTAssertNil(controller.selectedDeviceId)
        }
    }

    @MainActor
    private static func makeController(provider: TestProvider) -> ExternalController {
        let storage = InMemoryMappingStorage()
        let controller = ExternalController(providers: [provider], storage: storage)
        controller.start()
        return controller
    }
}

@MainActor
private final class TestProvider: ExternalControllerProvider {
    let providerKind: DeviceKind
    weak var delegate: (any ExternalControllerProviderDelegate)?
    var connectedDevices: [Device]
    var refreshCount = 0

    init(kind: DeviceKind, devices: [Device]) {
        self.providerKind = kind
        self.connectedDevices = devices
    }

    func start() {
        connectedDevices.forEach { delegate?.provider(self, didConnect: $0) }
    }

    func stop() {}

    func refreshConnectedDevices() {
        refreshCount += 1
    }

    func send(_ event: InputEvent) {
        delegate?.provider(self, didReceive: event)
    }

    func connect(_ device: Device) {
        connectedDevices.append(device)
        delegate?.provider(self, didConnect: device)
    }

    func disconnect(deviceId: String) {
        guard let index = connectedDevices.firstIndex(where: { $0.id == deviceId }) else { return }
        let device = connectedDevices.remove(at: index)
        delegate?.provider(self, didDisconnect: device)
    }
}

private struct InMemoryMappingStorage: MappingStorage {
    var store: [Mapping] = []
    func loadMappings() throws -> [Mapping] { store }
    func saveMappings(_ mappings: [Mapping]) throws {}
    func clearMappings() throws {}
}
