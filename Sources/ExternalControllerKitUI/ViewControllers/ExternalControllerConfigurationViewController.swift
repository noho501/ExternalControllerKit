#if canImport(UIKit)
import UIKit
import ExternalControllerKit

public final class ExternalControllerConfigurationViewController: UIViewController {
    private let controller: ExternalController
    private let uiConfiguration: ExternalControllerUIConfiguration
    private var observation: ExternalControllerObservation?
    private var actions: [ActionDefinition] = []
    private let collectionLayout = UICollectionViewFlowLayout()
    private var lastLaidOutCollectionWidth: CGFloat = 0

    private let deviceButton = UIButton(type: .system)
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: collectionLayout)
        view.backgroundColor = .systemBackground
        view.register(ActionMappingCell.self, forCellWithReuseIdentifier: ActionMappingCell.reuseIdentifier)
        view.delegate = self
        view.dataSource = self
        view.translatesAutoresizingMaskIntoConstraints = false
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshRequested), for: .valueChanged)
        view.refreshControl = refreshControl
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

        configureDeviceButton()
        configureCollectionLayout()

        view.addSubview(deviceButton)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([

            deviceButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),

            deviceButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            deviceButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            deviceButton.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),

            deviceButton.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),

            collectionView.topAnchor.constraint(equalTo: deviceButton.bottomAnchor, constant: 16),

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

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionLayoutIfNeeded(for: collectionView.bounds.width)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        controller.stopListening()
        controller.setInputEnabled(true)
    }

    @objc private func closeTapped() {
        controller.stopListening()
        controller.setInputEnabled(true)
        dismiss(animated: true)
    }

    @objc private func resetAllTapped() {
        controller.resetAllMappings()
    }

    @objc private func refreshRequested() {
        controller.refreshConnectedDevices()
    }

    private func reloadDevicesAndActions() {
        actions = uiConfiguration.actionSort(controller.actionDefinitions)
        let devices = uiConfiguration.deviceSort(uiConfiguration.deviceFilter(controller.connectedDevices))
        let currentTitle = devices.first(where: { $0.id == controller.selectedDeviceId })?.name ?? "Select Device"
        updateDeviceButtonTitle(currentTitle)
        deviceButton.menu = makeDeviceMenu(devices: devices)
        deviceButton.showsMenuAsPrimaryAction = true
        collectionView.refreshControl?.endRefreshing()
        collectionView.reloadData()
        updateCollectionLayoutIfNeeded(for: collectionView.bounds.width)
    }

    private func makeDeviceMenu(devices: [Device]) -> UIMenu {
        let actions = devices.map { device in
            UIAction(title: device.name, state: device.id == controller.selectedDeviceId ? .on : .off) { [weak self] _ in
                self?.controller.setSelectedDevice(id: device.id)
            }
        }
        return UIMenu(title: uiConfiguration.localization.selectedDeviceLabel, children: actions)
    }

    private func configureDeviceButton() {
        var configuration = UIButton.Configuration.bordered()
        configuration.image = UIImage(systemName: "chevron.down")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 8
        configuration.titleAlignment = .leading
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        deviceButton.configuration = configuration
        deviceButton.translatesAutoresizingMaskIntoConstraints = false
        deviceButton.showsMenuAsPrimaryAction = true
        deviceButton.contentHorizontalAlignment = .leading
        deviceButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        deviceButton.titleLabel?.adjustsFontForContentSizeCategory = true
        deviceButton.titleLabel?.lineBreakMode = .byTruncatingTail
        deviceButton.titleLabel?.numberOfLines = 1
    }

    private func configureCollectionLayout() {
        collectionLayout.minimumInteritemSpacing = 12
        collectionLayout.minimumLineSpacing = 12
        collectionLayout.sectionInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
    }

    private func updateDeviceButtonTitle(_ title: String) {
        var configuration = deviceButton.configuration
        configuration?.title = title
        deviceButton.configuration = configuration
    }

    private func updateCollectionLayoutIfNeeded(for width: CGFloat) {
        let roundedWidth = width.rounded(.down)
        guard roundedWidth > 0 else { return }
        guard roundedWidth != lastLaidOutCollectionWidth else { return }

        lastLaidOutCollectionWidth = roundedWidth

        let columns = numberOfColumns(for: roundedWidth)
        let totalSpacing = CGFloat(columns - 1) * collectionLayout.minimumInteritemSpacing
        let availableWidth = roundedWidth - collectionLayout.sectionInset.left - collectionLayout.sectionInset.right - totalSpacing
        let itemWidth = floor(availableWidth / CGFloat(columns))

        collectionLayout.itemSize = CGSize(width: itemWidth, height: 60)
        collectionLayout.invalidateLayout()
    }

    private func numberOfColumns(for width: CGFloat) -> Int {
        switch width {
        case 900...:
            3
        case 500...:
            2
        default:
            1
        }
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
