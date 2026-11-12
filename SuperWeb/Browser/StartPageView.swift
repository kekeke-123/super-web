import UIKit

/// 新标签页的启动页。
final class StartPageView: UIView {

    var onOpenURL: ((URL) -> Void)?

    private let shortcuts: [(String, String)] = [
        ("百度", "https://www.baidu.com"),
        ("哔哩哔哩", "https://www.bilibili.com"),
        ("GitHub", "https://github.com")
    ]

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

        let titleLabel = UILabel()
        titleLabel.text = "Super Web"
        titleLabel.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = Theme.primaryText
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = "轻量、干净、属于你的浏览器"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = Theme.secondaryText
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let hintLabel = UILabel()
        hintLabel.text = "在上方地址栏输入网址，或直接输入关键词搜索"
        hintLabel.font = UIFont.systemFont(ofSize: 13)
        hintLabel.textColor = Theme.tertiaryText
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0

        let shortcutStack = UIStackView()
        shortcutStack.axis = .horizontal
        shortcutStack.alignment = .center
        shortcutStack.distribution = .equalSpacing
        shortcutStack.spacing = 12
        for (title, link) in shortcuts {
            let button = makeShortcutButton(title: title, link: link)
            shortcutStack.addArrangedSubview(button)
        }

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, hintLabel, shortcutStack])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.setCustomSpacing(28, after: hintLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -30),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
    }

    private func makeShortcutButton(title: String, link: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = Theme.surface
        configuration.baseForegroundColor = Theme.primaryText
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 18, bottom: 9, trailing: 18)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            return outgoing
        }
        let button = UIButton(configuration: configuration)
        button.addAction(UIAction { [weak self] _ in
            guard let url = URL(string: link) else { return }
            self?.onOpenURL?(url)
        }, for: .touchUpInside)
        return button
    }
}
