import UIKit

/// 页面加载失败时的占位视图。
final class ErrorView: UIView {

    var onRetry: (() -> Void)?

    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = Theme.background
        isHidden = true

        let iconView = UIImageView(image: Theme.symbol("wifi.exclamationmark", size: 38, weight: .regular))
        iconView.tintColor = Theme.tertiaryText
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = "无法打开这个页面"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = Theme.primaryText
        titleLabel.textAlignment = .center

        messageLabel.font = UIFont.systemFont(ofSize: 13)
        messageLabel.textColor = Theme.secondaryText
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        var configuration = UIButton.Configuration.filled()
        configuration.title = "重新加载"
        configuration.baseBackgroundColor = Theme.accent
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 22, bottom: 10, trailing: 22)
        let retryButton = UIButton(configuration: configuration)
        retryButton.addAction(UIAction { [weak self] _ in
            self?.onRetry?()
        }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, messageLabel, retryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(20, after: messageLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32)
        ])
    }

    func show(message: String) {
        messageLabel.text = message
        isHidden = false
    }

    func hide() {
        isHidden = true
    }
}
