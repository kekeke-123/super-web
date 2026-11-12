import UIKit

/// 历史记录 / 书签共用的列表页。
final class BrowseListViewController: UITableViewController {

    enum Mode {
        case history
        case bookmarks
    }

    private struct Row {
        let title: String
        let detail: String
        let url: String
    }

    private let mode: Mode
    private let store = HistoryStore.shared
    private var rows: [Row] = []

    var onSelect: ((String) -> Void)?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()

    init(mode: Mode) {
        self.mode = mode
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = mode == .history ? "历史记录" : "书签"
        view.backgroundColor = Theme.background
        tableView.backgroundColor = Theme.background
        tableView.separatorColor = Theme.separator
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "清空",
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(clearAll))
        reload()
    }

    private func reload() {
        switch mode {
        case .history:
            rows = store.history.map {
                Row(title: $0.title,
                    detail: "\(Self.dateFormatter.string(from: $0.date))  ·  \($0.url)",
                    url: $0.url)
            }
        case .bookmarks:
            rows = store.bookmarks.map {
                Row(title: $0.title.isEmpty ? $0.url : $0.title,
                    detail: $0.url,
                    url: $0.url)
            }
        }
        tableView.reloadData()
        applyEmptyState()
    }

    private func applyEmptyState() {
        guard rows.isEmpty else {
            tableView.backgroundView = nil
            return
        }
        let label = UILabel()
        label.text = mode == .history ? "还没有浏览记录" : "还没有收藏任何页面"
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = Theme.tertiaryText
        label.textAlignment = .center
        tableView.backgroundView = label
    }

    @objc private func clearAll() {
        guard !rows.isEmpty else { return }
        let alert = UIAlertController(title: nil,
                                      message: mode == .history ? "确定清空全部历史记录？" : "确定清空全部书签？",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            if self.mode == .history {
                self.store.clearHistory()
            } else {
                self.store.clearBookmarks()
            }
            self.reload()
        })
        present(alert, animated: true)
    }

    // MARK: - 表格

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RowCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "RowCell")
        let row = rows[indexPath.row]
        cell.textLabel?.text = row.title
        cell.textLabel?.textColor = Theme.primaryText
        cell.textLabel?.numberOfLines = 1
        cell.detailTextLabel?.text = row.detail
        cell.detailTextLabel?.textColor = Theme.secondaryText
        cell.detailTextLabel?.numberOfLines = 1
        cell.backgroundColor = Theme.surface
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let url = rows[indexPath.row].url
        dismiss(animated: true) { [weak self] in
            self?.onSelect?(url)
        }
    }

    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
        -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            guard let self = self else {
                completion(false)
                return
            }
            if self.mode == .history {
                self.store.removeHistory(at: indexPath.row)
            } else {
                self.store.removeBookmark(at: indexPath.row)
            }
            self.reload()
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}
