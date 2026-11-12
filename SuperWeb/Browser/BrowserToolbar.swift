import UIKit

private func makeToolbarButton(_ symbol: String) -> UIButton {
    let button = UIButton(type: .system)
    button.setImage(Theme.symbol(symbol, size: 18, weight: .regular), for: .normal)
    button.tintColor = Theme.primaryText
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        button.widthAnchor.constraint(equalToConstant: 44),
        button.heightAnchor.constraint(equalToConstant: 44)
    ])
    return button
}

/// 底部工具栏：后退 / 前进 / 分享 / 收藏 / 标签页计数。
final class BrowserToolbar: UIView {

    private let backButton = makeToolbarButton("chevron.left")
    private let forwardButton = makeToolbarButton("chevron.right")
    private let shareButton = makeToolbarButton("square.and.arrow.up")
    private let bookmarkButton = makeToolbarButton("star")
    private let tabsButton = UIButton(type: .system)

    var onBack: (() -> Void)?
    var onForward: (() -> Void)?
    var onShare: (() -> Void)?
    var onBookmark: (() -> Void)?
    var onTabs: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = Theme.chrome

        tabsButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        tabsButton.translatesAutoresizingMaskIntoConstraints = false
        tabsButton.layer.cornerRadius = 6
        tabsButton.layer.cornerCurve = .continuous
        tabsButton.layer.borderWidth = 1.5
        tabsButton.layer.borderColor = Theme.secondaryText.cgColor

        let stack = UIStackView(arrangedSubviews: [backButton, forwardButton, shareButton, bookmarkButton, tabsButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 26),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -26),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            tabsButton.widthAnchor.constraint(equalToConstant: 26),
            tabsButton.heightAnchor.constraint(equalToConstant: 26)
        ])

        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(handleForward), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(handleShare), for: .touchUpInside)
        bookmarkButton.addTarget(self, action: #selector(handleBookmark), for: .touchUpInside)
        tabsButton.addTarget(self, action: #selector(handleTabs), for: .touchUpInside)
    }

    @objc private func handleBack() { onBack?() }
    @objc private func handleForward() { onForward?() }
    @objc private func handleShare() { onShare?() }
    @objc private func handleBookmark() { onBookmark?() }
    @objc private func handleTabs() { onTabs?() }

    func update(canGoBack: Bool, canGoForward: Bool, isBookmarked: Bool, tabCount: Int, isPrivate: Bool) {
        backButton.isEnabled = canGoBack
        forwardButton.isEnabled = canGoForward
        backButton.alpha = canGoBack ? 1.0 : 0.3
        forwardButton.alpha = canGoForward ? 1.0 : 0.3

        bookmarkButton.setImage(Theme.symbol(isBookmarked ? "star.fill" : "star", size: 18), for: .normal)
        bookmarkButton.tintColor = isBookmarked ? Theme.accent : Theme.primaryText

        tabsButton.setTitle("\(tabCount)", for: .normal)
        tabsButton.setTitleColor(isPrivate ? Theme.accent : Theme.primaryText, for: .normal)
        tabsButton.layer.borderColor = (isPrivate ? Theme.accent : Theme.secondaryText)
            .resolvedColor(with: traitCollection).cgColor
    }
}
