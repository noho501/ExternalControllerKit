#if canImport(UIKit)
import UIKit
import ExternalControllerKit

public final class ExternalControllerConfigurationViewController: UIViewController {
    private static let learnMoreURL = URL(string: "external-controller-kit://learn-more")!

    private let controller: ExternalController
    private let uiConfiguration: ExternalControllerUIConfiguration
    private var observation: ExternalControllerObservation?
    private var actions: [ActionDefinition] = []
    private let collectionLayout = UICollectionViewFlowLayout()
    private var lastLaidOutCollectionWidth: CGFloat = 0

    private let deviceButton = UIButton(type: .system)
    private let deviceContainer = UIView()
    private let headerContainerView = UIView()
    private let headerStackView = UIStackView()
    private let descriptionTextView = UITextView()
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
        configureDescriptionTextView()
        configureHeader()
        configureCollectionLayout()
        updateDescriptionText()

        view.addSubview(collectionView)
        collectionView.addSubview(headerContainerView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),

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
        updateHeaderLayout(for: collectionView.bounds.width)
        updateCollectionLayoutIfNeeded(for: collectionView.bounds.width)
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory else { return }
        updateDescriptionText()
        updateHeaderLayout(for: collectionView.bounds.width)
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
        let currentTitle = devices.first(where: { $0.id == controller.selectedDeviceId })?.name ?? uiConfiguration.localization.selectedDeviceLabel
        updateDeviceButtonTitle(currentTitle)
        deviceButton.menu = makeDeviceMenu(devices: devices)
        deviceButton.showsMenuAsPrimaryAction = true
        collectionView.refreshControl?.endRefreshing()
        collectionView.reloadData()
        updateHeaderLayout(for: collectionView.bounds.width)
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
        configuration.titleAlignment = .center
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        deviceButton.configuration = configuration
        deviceButton.translatesAutoresizingMaskIntoConstraints = false
        deviceButton.showsMenuAsPrimaryAction = true
        deviceButton.contentHorizontalAlignment = .center
        deviceButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        deviceButton.titleLabel?.adjustsFontForContentSizeCategory = true
        deviceButton.titleLabel?.lineBreakMode = .byTruncatingTail
        deviceButton.titleLabel?.numberOfLines = 1
    }

    private func configureDescriptionTextView() {
        descriptionTextView.backgroundColor = .clear
        descriptionTextView.delegate = self
        descriptionTextView.font = .preferredFont(forTextStyle: .body)
        descriptionTextView.adjustsFontForContentSizeCategory = true
        descriptionTextView.textColor = .secondaryLabel
        descriptionTextView.isEditable = false
        descriptionTextView.isSelectable = true
        descriptionTextView.isScrollEnabled = false
        descriptionTextView.textContainerInset = .zero
        descriptionTextView.textContainer.lineFragmentPadding = 0
    }

    private func configureHeader() {
        headerContainerView.backgroundColor = .clear

        headerStackView.axis = .vertical
        headerStackView.alignment = .fill
        headerStackView.spacing = 12
        headerStackView.translatesAutoresizingMaskIntoConstraints = false

        deviceContainer.translatesAutoresizingMaskIntoConstraints = false
        deviceButton.translatesAutoresizingMaskIntoConstraints = false

        deviceContainer.addSubview(deviceButton)

        NSLayoutConstraint.activate([
            deviceButton.centerXAnchor.constraint(equalTo: deviceContainer.centerXAnchor),
            deviceButton.topAnchor.constraint(equalTo: deviceContainer.topAnchor),
            deviceButton.bottomAnchor.constraint(equalTo: deviceContainer.bottomAnchor),

            deviceButton.leadingAnchor.constraint(greaterThanOrEqualTo: deviceContainer.leadingAnchor),
            deviceButton.trailingAnchor.constraint(lessThanOrEqualTo: deviceContainer.trailingAnchor)
        ])

        headerContainerView.addSubview(headerStackView)

        headerStackView.addArrangedSubview(deviceContainer)
        headerStackView.addArrangedSubview(descriptionTextView)

        NSLayoutConstraint.activate([
            headerStackView.topAnchor.constraint(equalTo: headerContainerView.topAnchor),
            headerStackView.leadingAnchor.constraint(equalTo: headerContainerView.leadingAnchor),
            headerStackView.trailingAnchor.constraint(equalTo: headerContainerView.trailingAnchor),
            headerStackView.bottomAnchor.constraint(equalTo: headerContainerView.bottomAnchor)
        ])
    }
    
    private func configureCollectionLayout() {
        collectionLayout.minimumInteritemSpacing = 12
        collectionLayout.minimumLineSpacing = 12
        collectionLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
    }

    private func updateDeviceButtonTitle(_ title: String) {
        var configuration = deviceButton.configuration
        configuration?.title = title
        deviceButton.configuration = configuration
    }

    private func updateDescriptionText() {
        guard let rawDescription = uiConfiguration.headerDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !rawDescription.isEmpty else {
            descriptionTextView.attributedText = nil
            descriptionTextView.isHidden = true
            return
        }

        let font = UIFont.preferredFont(forTextStyle: .footnote)
        descriptionTextView.linkTextAttributes = [
            .font: font,
            .foregroundColor: UIColor.systemBlue
        ]

        let descriptionAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel
        ]

        let attributedText = NSMutableAttributedString(string: rawDescription, attributes: descriptionAttributes)
        if let rawLearnMoreTitle = uiConfiguration.learnMoreTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawLearnMoreTitle.isEmpty,
           uiConfiguration.onLearnMore != nil {
            attributedText.append(NSAttributedString(string: " ", attributes: descriptionAttributes))
            attributedText.append(NSAttributedString(
                string: rawLearnMoreTitle,
                attributes: [
                    .font: font,
                    .foregroundColor: UIColor.systemBlue,
                    .link: Self.learnMoreURL
                ]
            ))
        }

        descriptionTextView.attributedText = attributedText
        descriptionTextView.isHidden = false
    }

    private func updateHeaderLayout(for width: CGFloat) {
        let roundedWidth = width.rounded(.down)
        guard roundedWidth > 0 else { return }

        headerContainerView.bounds = CGRect(x: 0, y: 0, width: roundedWidth, height: 0)
        headerContainerView.setNeedsLayout()
        headerContainerView.layoutIfNeeded()

        let targetSize = CGSize(width: roundedWidth, height: UIView.layoutFittingCompressedSize.height)
        let headerHeight = ceil(headerContainerView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height)

        headerContainerView.frame = CGRect(x: 0, y: 0, width: roundedWidth, height: headerHeight)
        let updatedTopInset = headerHeight + 12
        if collectionLayout.sectionInset.top != updatedTopInset {
            collectionLayout.sectionInset.top = updatedTopInset
            collectionLayout.invalidateLayout()
        }
        collectionView.verticalScrollIndicatorInsets.top = headerHeight
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

extension ExternalControllerConfigurationViewController: UITextViewDelegate {
    public func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        guard URL == Self.learnMoreURL else { return true }
        uiConfiguration.onLearnMore?()
        return false
    }
}
#endif
