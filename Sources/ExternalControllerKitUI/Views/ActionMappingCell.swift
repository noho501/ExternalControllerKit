#if canImport(UIKit)
import UIKit

final class ActionMappingCell: UICollectionViewCell {

    static let reuseIdentifier = "ActionMappingCell"

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let spacer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.separator.cgColor

        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.numberOfLines = 1

        detailLabel.font = .preferredFont(forTextStyle: .body)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        detailLabel.textAlignment = .right
        detailLabel.numberOfLines = 1
        detailLabel.lineBreakMode = .byTruncatingMiddle

        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detailLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            spacer,
            detailLabel
        ])

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        title: String,
        detail: String,
        listeningText: String?,
        isListening: Bool
    ) {

        titleLabel.text = title

        if isListening {
            detailLabel.text = listeningText
            detailLabel.textColor = .systemBlue
            contentView.layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            detailLabel.text = detail
            detailLabel.textColor = detail == "Unmapped"
                ? .tertiaryLabel
                : .secondaryLabel
            contentView.layer.borderColor = UIColor.separator.cgColor
        }
    }
}
#endif
