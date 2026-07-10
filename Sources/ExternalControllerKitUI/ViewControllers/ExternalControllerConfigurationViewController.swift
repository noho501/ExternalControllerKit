#if canImport(UIKit)
import UIKit
import ExternalControllerKit

@MainActor
public final class ExternalControllerConfigurationViewController: UIViewController {
    private let controller: ExternalController
    private let uiConfiguration: ExternalControllerUIConfiguration
    private var observation: ExternalControllerObservation?
    private var actions: [ActionDefinition] = []

    private let selectedDeviceLabel = UILabel()
    private let deviceButton = UIButton(type: .system)
    private let refreshButton = UIButton(type: .system)
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: makeLayout(for: traitCollection))
        view.backgroundColor = .systemBackground
        view.register(ActionMappingCell.self, forCellWithReuseIdentifier: ActionMappingCell.reuseIdentifier)
        view.delegate = self
        view.dataSource = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public init(
        controller: ExternalController = .shared,
        uiConfiguration: ExternalControllerUIConfiguration = ExternalControllerUIConfiguration()
    ) {
        self.controller = controller
        self.uiConfiguration = uiConfiguration
        super.init(nibName: nil, bundle: nil)
        self.actions = uiConfiguration.actionSort(controller.actionDefinitions)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = uiConfiguration.localization.title
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: uiConfiguration.localization.closeButtonTitle, style: .plain, target: self, action: #selector(closeTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: uiConfiguration.localization.resetAllButtonTitle, style: .plain, target: self, action: #selector(resetAllTapped))

        selectedDeviceLabel.text = uiConfiguration.localization.selectedDeviceLabel
        selectedDeviceLabel.font = .preferredFont(forTextStyle: .subheadline)

        deviceButton.configuration = .bordered()
        refreshButton.configuration = .bordered()
        refreshButton.setTitle(uiConfiguration.localization.refreshButtonTitle, for: .normal)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)

        let deviceStack = UIStackView(arrangedSubviews: [selectedDeviceLabel, deviceButton, refreshButton])
        deviceStack.axis = .horizontal
        deviceStack.spacing = 12
        deviceStack.alignment = .center
        deviceStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(deviceStack)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            deviceStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            deviceStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            deviceStack.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            collectionView.topAnchor.constraint(equalTo: deviceStack.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        observation = controller.observe(
            onDevicesChanged: { [weak self] _ in self?.reloadDevicesAndActions() },
            onMappingsChanged: { [weak self] _ in self?.collectionView.reloadData() },
            onStateChanged: { [weak self] _ in self?.collectionView.reloadData() }
        )
        reloadDevicesAndActions()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        controller.setInputEnabled(false)
        controller.refreshConnectedDevices()
        reloadDevicesAndActions()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        controller.stopListening()
        controller.setInputEnabled(true)
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        collectionView.setCollectionViewLayout(makeLayout(for: traitCollection), animated: false)
    }

    @objc private func closeTapped() {
        controller.stopListening()
        controller.setInputEnabled(true)
        dismiss(animated: true)
    }

    @objc private func resetAllTapped() {
        controller.resetAllMappings()
    }

    @objc private func refreshTapped() {
        controller.refreshConnectedDevices()
    }

    private func reloadDevicesAndActions() {
        actions = uiConfiguration.actionSort(controller.actionDefinitions)
        let devices = uiConfiguration.deviceSort(uiConfiguration.deviceFilter(controller.connectedDevices))
        let currentTitle = devices.first(where: { $0.id == controller.selectedDeviceId })?.name ?? "-"
        deviceButton.setTitle(currentTitle, for: .normal)
        deviceButton.menu = makeDeviceMenu(devices: devices)
        deviceButton.showsMenuAsPrimaryAction = true
        collectionView.reloadData()
    }

    private func makeDeviceMenu(devices: [Device]) -> UIMenu {
        let actions = devices.map { device in
            UIAction(title: device.name, state: device.id == controller.selectedDeviceId ? .on : .off) { [weak self] _ in
                self?.controller.setSelectedDevice(id: device.id)
            }
        }
        return UIMenu(title: uiConfiguration.localization.selectedDeviceLabel, children: actions)
    }

    private func makeLayout(for traits: UITraitCollection) -> UICollectionViewLayout {
        let columns: Int
        if traits.horizontalSizeClass == .compact {
            columns = 1
        } else if traits.verticalSizeClass == .regular {
            columns = 2
        } else {
            columns = 3
        }

        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(110))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(110))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: columns)
        group.interItemSpacing = .fixed(12)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        return UICollectionViewCompositionalLayout(section: section)
    }
}

extension ExternalControllerConfigurationViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        actions.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let action = actions[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ActionMappingCell.reuseIdentifier, for: indexPath) as! ActionMappingCell
        let mapping = controller.selectedDeviceId.flatMap { controller.mapping(for: action.actionId, deviceId: $0) }
        let detail = mapping.map { uiConfiguration.buttonLabelFormatter($0.inputId) } ?? uiConfiguration.localization.unmappedValue
        let isListening: Bool
        switch controller.state {
        case .listening(let actionId): isListening = actionId == action.actionId
        case .idle: isListening = false
        }
        cell.configure(
            title: action.displayTitle,
            detail: detail,
            listeningText: uiConfiguration.localization.listeningPrompt,
            isListening: isListening
        )
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        controller.startListening(for: actions[indexPath.item].actionId)
    }
}
#endif
