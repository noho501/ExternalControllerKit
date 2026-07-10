#if canImport(UIKit)
import UIKit
import ExternalControllerKit
import ExternalControllerKitUI

@MainActor
final class ExampleHostViewController: UIViewController {
    private let controller = ExternalController.shared
    private var observation: ExternalControllerObservation?
    private let logView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Example Host"

        controller.configure(actions: [
            ActionDefinition(actionId: "host.jump", displayTitle: "Jump", groupingKey: "Gameplay", sortOrder: 0),
            ActionDefinition(actionId: "host.pause", displayTitle: "Pause", groupingKey: "Gameplay", sortOrder: 1),
            ActionDefinition(actionId: "host.menu.select", displayTitle: "Select", groupingKey: "Menu", sortOrder: 2)
        ])
        controller.start()

        let button = UIButton(type: .system)
        button.configuration = .borderedProminent()
        button.setTitle("Open Controller Mapping", for: .normal)
        button.addTarget(self, action: #selector(openMappingUI), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false

        logView.isEditable = false
        logView.font = .preferredFont(forTextStyle: .body)
        logView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(button)
        view.addSubview(logView)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logView.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 20),
            logView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            logView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            logView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        observation = controller.observe(onActionTriggered: { [weak self] actionId, deviceId, buttonId in
            self?.appendLog("Triggered actionId=\(actionId) deviceId=\(deviceId) buttonId=\(buttonId)")
        })
        appendLog("Configured host-defined actions. Runtime callbacks remain host-controlled.")
    }

    @objc private func openMappingUI() {
        let navigationController = UINavigationController(rootViewController: ExternalControllerConfigurationViewController(controller: controller))
        present(navigationController, animated: true)
    }

    private func appendLog(_ message: String) {
        logView.text = ([logView.text, message].filter { !$0.isEmpty }).joined(separator: "\n")
    }
}
#endif
