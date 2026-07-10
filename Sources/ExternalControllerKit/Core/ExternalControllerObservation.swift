import Foundation

@MainActor
public final class ExternalControllerObservation {
    private let onInvalidate: () -> Void
    private var isActive = true

    init(onInvalidate: @escaping () -> Void) {
        self.onInvalidate = onInvalidate
    }

    public func invalidate() {
        guard isActive else { return }
        isActive = false
        onInvalidate()
    }
}
