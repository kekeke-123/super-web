import UIKit

/// 胶囊形地址栏：左侧状态图标 + 输入框 + 右侧刷新/停止。
final class AddressBarView: UIView {

    let textField = UITextField()
    private let iconView = UIImageView()
    private let actionButton = UIButton(type: .system)
    private let stack = UIStackView()

    var onReloadOrStop: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = Theme.field
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        clipsToBounds = true

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Theme.secondaryText
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 15),
            iconView.heightAnchor.constraint(equalToConstant: 17)
        ])

        textField.font = UIFont.systemFont(ofSize: 15)
        textField.textColor = Theme.primaryText
        textField.tintColor = Theme.accent
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.keyboardType = .webSearch
        textField.returnKeyType = .go
        textField.clearButtonMode = .never
        textField.textContentType = .URL
        textField.attributedPlaceholder = NSAttributedString(
            string: "搜索或输入网址",
            attributes: [.foregroundColor: Theme.tertiaryText]
        )

        actionButton.tintColor = Theme.secondaryText
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        actionButton.addTarget(self, action: #selector(tappedAction), for: .touchUpInside)
        NSLayoutConstraint.activate([
            actionButton.widthAnchor.constraint(equalToConstant: 30),
            actionButton.heightAnchor.constraint(equalToConstant: 30)
        ])

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(textField)
        stack.addArrangedSubview(actionButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @objc private func tappedAction() {
        onReloadOrStop?()
    }

    func update(isSecure: Bool, isLoading: Bool, isPrivate: Bool) {
        let iconName: String
        if isLoading {
            iconName = "xmark"
        } else if isPrivate {
            iconName = "eyeglasses"
        } else {
            iconName = isSecure ? "lock.fill" : "magnifyingglass"
        }
        iconView.image = Theme.symbol(iconName, size: 13, weight: .semibold)
        iconView.tintColor = isPrivate ? Theme.accent : Theme.secondaryText

        let actionName = isLoading ? "xmark" : "arrow.clockwise"
        actionButton.setImage(Theme.symbol(actionName, size: 15, weight: .medium), for: .normal)

        backgroundColor = isPrivate ? Theme.privateField : Theme.field
    }
}
