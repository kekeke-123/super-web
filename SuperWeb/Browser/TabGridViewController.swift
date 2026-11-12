import UIKit

final class TabCell: UICollectionViewCell {

    static let reuseIdentifier = "TabCell"

    private let card = UIView()
    private let titleLabel = UILabel()
    private let urlLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    var onClose: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = Theme.surface
        card.layer.cornerRadius = 12
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        contentView.addSubview(card)

        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = Theme.primaryText
        titleLabel.numberOfLines = 2

        urlLabel.font = UIFont.systemFont(ofSize: 11)
        urlLabel.textColor = Theme.secondaryText
        urlLabel.numberOfLines = 1

        closeButton.setImage(Theme.symbol("xmark", size: 12, weight: .bold), for: .normal)
        closeButton.tintColor = Theme.secondaryText
        closeButton.addTarget(self, action: #selector(tappedClose), for: .touchUpInside)

        [titleLabel, urlLabel, closeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview($0)
        }

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),

            closeButton.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),

            urlLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            urlLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            urlLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            urlLabel.topAnchor.constraint(greaterThanOrEqualTo: titleLabel.bottomAnchor, constant: 4)
        ])
    }

    @objc private func tappedClose() {
        onClose?()
    }

    func configure(title: String, url: String, isSelected: Bool) {
        titleLabel.text = title
        urlLabel.text = url
        card.layer.borderWidth = isSelected ? 2.0 : 0.0
        card.layer.borderColor = Theme.accent.cgColor
    }
}

/// 标签页总览（网格）。
final class TabGridViewController: UIViewController {

    private let tabs: TabManager
    private let collectionView: UICollectionView
    private let doneButton = UIButton(type: .system)
    private let addButton = UIButton(type: .system)

    var onSelect: ((Tab) -> Void)?
    var onClose: ((Tab) -> Void)?
    var onNewTab: ((Bool) -> Void)?

    init(tabs: TabManager) {
        self.tabs = tabs
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 110, right: 16)
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        buildLayout()
    }

    private func buildLayout() {
        let titleLabel = UILabel()
        titleLabel.text = "标签页"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = Theme.primaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        doneButton.setTitle("完成", for: .normal)
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        doneButton.setTitleColor(Theme.accent, for: .normal)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.addTarget(self, action: #selector(done), for: .touchUpInside)

        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(TabCell.self, forCellWithReuseIdentifier: TabCell.reuseIdentifier)

        var configuration = UIButton.Configuration.filled()
        configuration.image = Theme.symbol("plus", size: 22, weight: .semibold)
        configuration.baseBackgroundColor = Theme.accent
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .capsule
        addButton.configuration = configuration
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.addTarget(self, action: #selector(addTab), for: .touchUpInside)

        [titleLabel, doneButton, collectionView, addButton].forEach { view.addSubview($0) }

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            doneButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            addButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -24),
            addButton.widthAnchor.constraint(equalToConstant: 52),
            addButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    @objc private func done() {
        dismiss(animated: true)
    }

    @objc private func addTab() {
        onNewTab?(tabs.isPrivateMode)
    }
}

extension TabGridViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tabs.tabs.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TabCell.reuseIdentifier,
                                                      for: indexPath) as! TabCell
        let tab = tabs.tabs[indexPath.item]
        cell.configure(title: tab.displayTitle,
                       url: tab.displayURL,
                       isSelected: indexPath.item == tabs.selectedIndex)
        cell.onClose = { [weak self] in
            guard let self = self else { return }
            self.onClose?(tab)
            self.collectionView.reloadData()
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let available = collectionView.bounds.width - 16 * 2 - 12
        let width = floor(available / 2)
        return CGSize(width: width, height: max(112, width * 0.8))
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard tabs.tabs.indices.contains(indexPath.item) else { return }
        onSelect?(tabs.tabs[indexPath.item])
    }
}
