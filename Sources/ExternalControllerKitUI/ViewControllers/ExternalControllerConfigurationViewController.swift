#if canImport(UIKit)
import UIKit
import ExternalControllerKit

private final class ActionMappingSectionHeader: UICollectionReusableView {
    static let reuseIdentifier = "ActionMappingSectionHeader"

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemBackground
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        titleLabel.text = title
    }
}

public final class ExternalControllerConfigurationViewController: UIViewController {
    private struct ActionSection {
        let title: String?
        var actions: [ActionDefinition]
    }

    private static let learnMoreURL = URL(string: "external-controller-kit://learn-more")!

    private let controller: ExternalController
    private let uiConfiguration: ExternalControllerUIConfiguration
    private var observation: ExternalControllerObservation?
    private var actionSections: [ActionSection] = []
    private let collectionLayout = UICollectionViewFlowLayout()
    private var lastLaidOutCollectionWidth: CGFloat = 0
    private var headerHeight: CGFloat = 0

    private let deviceButton = UIButton(type: .system)
    private let deviceContainer = UIView()
    private let headerContainerView = UIView()
    private let headerStackView = UIStackView()
    private let descriptionTextView = UITextView()
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: collectionLayout)
        view.backgroundColor = .systemBackground
        view.register(ActionMappingCell.self, forCellWithReuseIdentifier: ActionMappingCell.reuseIdentifier)
        view.register(
            ActionMappingSectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: ActionMappingSectionHeader.reuseIdentifier
        )
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
        self.actionSections = Self.makeActionSections(from: uiConfiguration.actionSort(controller.actionDefinitions))
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
        actionSections = Self.makeActionSections(from: uiConfiguration.actionSort(controller.actionDefinitions))
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

    private static func makeActionSections(from actions: [ActionDefinition]) -> [ActionSection] {
        var sectionIndices: [String?: Int] = [:]
        var sections: [ActionSection] = []

        for action in actions {
            let title = action.groupingKey?.isEmpty == true ? nil : action.groupingKey
            if let sectionIndex = sectionIndices[title] {
                sections[sectionIndex].actions.append(action)
            } else {
                sectionIndices[title] = sections.count
                sections.append(ActionSection(title: title, actions: [action]))
            }
        }

        return sections
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
        headerContainerView.translatesAutoresizingMaskIntoConstraints = true

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

        let wasAtTop = collectionView.contentOffset.y <= -collectionView.adjustedContentInset.top + 1
        headerContainerView.bounds = CGRect(x: 0, y: 0, width: roundedWidth, height: 0)
        headerContainerView.setNeedsLayout()
        headerContainerView.layoutIfNeeded()

        let targetSize = CGSize(width: roundedWidth, height: UIView.layoutFittingCompressedSize.height)
        let measuredHeight = ceil(headerContainerView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height)
        let topInset = measuredHeight + 12

        headerContainerView.frame = CGRect(x: 0, y: -topInset, width: roundedWidth, height: measuredHeight)
        if headerHeight != measuredHeight {
            headerHeight = measuredHeight
            collectionLayout.invalidateLayout()
        }

        collectionView.contentInset.top = topInset
        collectionView.verticalScrollIndicatorInsets.top = topInset
        if wasAtTop {
            collectionView.setContentOffset(
                CGPoint(x: collectionView.contentOffset.x, y: -collectionView.adjustedContentInset.top),
                animated: false
            )
        }
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

extension ExternalControllerConfigurationViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        actionSections.count
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        actionSections[section].actions.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let action = actionSections[indexPath.section].actions[indexPath.item]
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

    public func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: ActionMappingSectionHeader.reuseIdentifier,
            for: indexPath
        ) as! ActionMappingSectionHeader
        header.configure(title: actionSections[indexPath.section].title ?? "")
        return header
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        guard actionSections[section].title != nil else { return .zero }
        return CGSize(width: collectionView.bounds.width, height: 32)
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        UIEdgeInsets(
            top: 0,
            left: self.collectionLayout.sectionInset.left,
            bottom: self.collectionLayout.sectionInset.bottom,
            right: self.collectionLayout.sectionInset.right
        )
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        controller.startListening(for: actionSections[indexPath.section].actions[indexPath.item].actionId)
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
