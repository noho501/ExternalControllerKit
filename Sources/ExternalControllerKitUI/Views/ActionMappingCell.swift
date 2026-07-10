#if canImport(UIKit)
import UIKit

final class ActionMappingCell: UICollectionViewCell {
    static let reuseIdentifier = "ActionMappingCell"

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let listeningLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.separator.cgColor

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0

        listeningLabel.font = .preferredFont(forTextStyle: .footnote)
        listeningLabel.adjustsFontForContentSizeCategory = true
        listeningLabel.textColor = .systemBlue
        listeningLabel.numberOfLines = 0
        listeningLabel.isHidden = true

        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel, listeningLabel])
        stack.axis = .vertical
        stack.spacing = 8
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

    func configure(title: String, detail: String, listeningText: String?, isListening: Bool) {
        titleLabel.text = title
        detailLabel.text = detail
        listeningLabel.text = listeningText
        listeningLabel.isHidden = !isListening
        contentView.layer.borderColor = isListening ? UIColor.systemBlue.cgColor : UIColor.separator.cgColor
    }
}
#endif
