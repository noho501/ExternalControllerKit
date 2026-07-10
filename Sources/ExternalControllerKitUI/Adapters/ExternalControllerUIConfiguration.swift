#if canImport(UIKit)
import Foundation
import ExternalControllerKit

public protocol ExternalControllerLocalizationProviding {
    var title: String { get }
    var selectedDeviceLabel: String { get }
    var refreshButtonTitle: String { get }
    var closeButtonTitle: String { get }
    var resetAllButtonTitle: String { get }
    var listeningPrompt: String { get }
    var unmappedValue: String { get }
}

public struct DefaultExternalControllerLocalizationProvider: ExternalControllerLocalizationProviding {
    public init() {}
    public let title = "External Controller"
    public let selectedDeviceLabel = "Selected Device"
    public let refreshButtonTitle = "Refresh"
    public let closeButtonTitle = "Close"
    public let resetAllButtonTitle = "Reset All"
    public let listeningPrompt = "Press any button..."
    public let unmappedValue = "Not mapped"
}

public struct ExternalControllerUIConfiguration {
    public var localization: any ExternalControllerLocalizationProviding
    public var buttonLabelFormatter: @Sendable (String) -> String
    public var deviceFilter: @Sendable ([Device]) -> [Device]
    public var deviceSort: @Sendable ([Device]) -> [Device]
    public var actionSort: @Sendable ([ActionDefinition]) -> [ActionDefinition]

    public init(
        localization: any ExternalControllerLocalizationProviding = DefaultExternalControllerLocalizationProvider(),
        buttonLabelFormatter: @escaping @Sendable (String) -> String = { $0 },
        deviceFilter: @escaping @Sendable ([Device]) -> [Device] = { $0 },
        deviceSort: @escaping @Sendable ([Device]) -> [Device] = { devices in
            devices.sorted { lhs, rhs in lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending }
        },
        actionSort: @escaping @Sendable ([ActionDefinition]) -> [ActionDefinition] = { actions in
            actions.sorted {
                let lhsOrder = $0.sortOrder ?? .max
                let rhsOrder = $1.sortOrder ?? .max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
            }
        }
    ) {
        self.localization = localization
        self.buttonLabelFormatter = buttonLabelFormatter
        self.deviceFilter = deviceFilter
        self.deviceSort = deviceSort
        self.actionSort = actionSort
    }
}
#endif
