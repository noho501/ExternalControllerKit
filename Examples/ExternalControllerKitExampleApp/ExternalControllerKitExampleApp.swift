#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

@main
struct ExternalControllerKitExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ExampleHostContainerView()
        }
    }
}

private struct ExampleHostContainerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UINavigationController(rootViewController: ExampleHostViewController())
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#endif
