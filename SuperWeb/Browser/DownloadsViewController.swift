import UIKit

final class DownloadCell: UITableViewCell {

    static let reuseIdentifier = "DownloadCell"

    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let actionButton = UIButton(type: .system)

    var onAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        selectionStyle = .none
        backgroundColor = Theme.surface

        nameLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = Theme.primaryText
        nameLabel.numberOfLines = 2

        detailLabel.font = UIFont.systemFont(ofSize: 11)
        detailLabel.textColor = Theme.secondaryText
        detailLabel.numberOfLines = 2

        progressView.progressTintColor = Theme.accent
        progressView.trackTintColor = Theme.separator
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.heightAnchor.constraint(equalToConstant: 3).isActive = true

        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        actionButton.setTitleColor(Theme.accent, for: .normal)
        actionButton.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        actionButton.setContentHuggingPriority(.required, for: .horizontal)

        let bottomRow = UIStackView(arrangedSubviews: [detailLabel, actionButton])
        bottomRow.axis = .horizontal
        bottomRow.alignment = .center
        bottomRow.spacing = 8

        let stack = UIStackView(arrangedSubviews: [nameLabel, progressView, bottomRow])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    @objc private func tapped() {
        onAction?()
    }

    func configure(with job: DownloadJob) {
        nameLabel.text = job.fileName
        detailLabel.text = job.detailText
        progressView.progress = Float(job.progress)
        actionButton.setTitle(job.actionTitle, for: .normal)
        actionButton.isHidden = job.state == .probing
    }
}

/// 下载列表：进度、暂停/继续、重试、完成后分享。
final class DownloadsViewController: UITableViewController {

    private let manager = DownloadManager.shared
    private var observer: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "下载"
        view.backgroundColor = Theme.background
        tableView.backgroundColor = Theme.background
        tableView.separatorColor = Theme.separator
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 96
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "完成",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(done))

        observer = NotificationCenter.default.addObserver(forName: DownloadManager.changedNotification,
                                                          object: nil,
                                                          queue: .main) { [weak self] _ in
            self?.tableView.reloadData()
            self?.updateEmptyState()
        }
        updateEmptyState()
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    @objc private func done() {
        dismiss(animated: true)
    }

    private func updateEmptyState() {
        if manager.jobs.isEmpty {
            let label = UILabel()
            label.text = "还没有下载任务\n网页里点下载链接就会出现在这里"
            label.font = UIFont.systemFont(ofSize: 15)
            label.textColor = Theme.tertiaryText
            label.textAlignment = .center
            label.numberOfLines = 0
            tableView.backgroundView = label
            tableView.tableFooterView = nil
        } else {
            let label = UILabel()
            label.text = "文件保存在「文件」App → 我的 iPhone → Super Web → Downloads"
            label.font = UIFont.systemFont(ofSize: 11)
            label.textColor = Theme.tertiaryText
            label.textAlignment = .center
            label.numberOfLines = 0
            label.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 48)
            tableView.tableFooterView = label
            tableView.backgroundView = nil
        }
    }

    // MARK: - 表格

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return manager.jobs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DownloadCell.reuseIdentifier, for: indexPath)
            as! DownloadCell
        let job = manager.jobs[indexPath.row]
        cell.configure(with: job)
        cell.onAction = { [weak self] in
            self?.handle(job)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
        -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "移除") { [weak self] _, _, completion in
            guard let self = self else {
                completion(false)
                return
            }
            let job = self.manager.jobs[indexPath.row]
            self.manager.remove(job)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    // MARK: - 操作

    private func handle(_ job: DownloadJob) {
        switch job.state {
        case .probing, .running:
            manager.pause(job)
        case .paused:
            manager.resume(job)
        case .finished:
            if let url = job.destinationURL {
                share(url)
            }
        case .failed, .cancelled:
            manager.retry(job)
        }
    }

    private func share(_ url: URL) {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        present(controller, animated: true)
    }
}
