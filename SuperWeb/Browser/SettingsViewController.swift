import UIKit

final class SettingsViewController: UITableViewController {

    var onChange: (() -> Void)?
    var onClearWebsiteData: (() -> Void)?
    var onUserAgentChanged: (() -> Void)?
    var onAdBlockChanged: (() -> Void)?

    private let settings = Settings.shared
    private let store = HistoryStore.shared

    private enum Row {
        case searchEngine
        case userAgent
        case appearance
        case downloadThreads
        case saveHistory
        case blockAds
        case clearHistory
        case clearWebsiteData
        case clearBookmarks
        case version
        case engine
        case downloadEngine
    }

    private enum Section: Int, CaseIterable {
        case general
        case privacy
        case about

        var title: String {
            switch self {
            case .general: return "常规"
            case .privacy: return "隐私与拦截"
            case .about: return "关于"
            }
        }

        var rows: [Row] {
            switch self {
            case .general:
                return [.searchEngine, .userAgent, .appearance, .downloadThreads]
            case .privacy:
                return [.saveHistory, .blockAds, .clearHistory, .clearWebsiteData, .clearBookmarks]
            case .about:
                return [.version, .engine, .downloadEngine]
            }
        }
    }

    override init(style: UITableView.Style) {
        super.init(style: style)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        view.backgroundColor = Theme.background
        tableView.backgroundColor = Theme.background
        tableView.separatorColor = Theme.separator
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "完成",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(done))
    }

    @objc private func done() {
        dismiss(animated: true)
    }

    // MARK: - 表格

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Section(rawValue: section)?.rows.count ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        let row = section.rows[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell")
            ?? UITableViewCell(style: .value1, reuseIdentifier: "SettingsCell")
        cell.backgroundColor = Theme.surface
        cell.textLabel?.textColor = Theme.primaryText
        cell.detailTextLabel?.textColor = Theme.secondaryText
        cell.accessoryType = .none
        cell.accessoryView = nil
        cell.selectionStyle = .default
        cell.detailTextLabel?.text = nil

        switch row {
        case .searchEngine:
            cell.textLabel?.text = "搜索引擎"
            cell.detailTextLabel?.text = settings.searchEngine.displayName
            cell.accessoryType = .disclosureIndicator

        case .userAgent:
            cell.textLabel?.text = "浏览器标识"
            cell.detailTextLabel?.text = settings.userAgent.displayName
            cell.accessoryType = .disclosureIndicator

        case .appearance:
            cell.textLabel?.text = "外观"
            cell.detailTextLabel?.text = appearanceName(settings.appearance)
            cell.accessoryType = .disclosureIndicator

        case .downloadThreads:
            cell.textLabel?.text = "下载线程"
            cell.detailTextLabel?.text = "\(settings.downloadThreads) 线程"
            cell.accessoryType = .disclosureIndicator

        case .saveHistory:
            cell.textLabel?.text = "保存浏览历史"
            cell.selectionStyle = .none
            cell.accessoryView = makeSwitch(isOn: settings.saveHistory,
                                            action: #selector(historySwitchChanged(_:)))

        case .blockAds:
            cell.textLabel?.text = "广告拦截"
            cell.selectionStyle = .none
            cell.accessoryView = makeSwitch(isOn: settings.blockAds,
                                            action: #selector(adBlockSwitchChanged(_:)))

        case .clearHistory:
            cell.textLabel?.text = "清除浏览历史"

        case .clearWebsiteData:
            cell.textLabel?.text = "清除网站数据（Cookie / 缓存）"

        case .clearBookmarks:
            cell.textLabel?.text = "清除全部书签"

        case .version:
            cell.selectionStyle = .none
            cell.textLabel?.text = "版本"
            cell.detailTextLabel?.text = "1.0.0"

        case .engine:
            cell.selectionStyle = .none
            cell.textLabel?.text = "渲染内核"
            cell.detailTextLabel?.text = "WebKit (WKWebView)"

        case .downloadEngine:
            cell.selectionStyle = .none
            cell.textLabel?.text = "下载引擎"
            cell.detailTextLabel?.text = "分段多线程（最高 64）"
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else { return }
        let row = section.rows[indexPath.row]

        switch row {
        case .searchEngine:
            chooseSearchEngine()
        case .userAgent:
            chooseUserAgent()
        case .appearance:
            chooseAppearance()
        case .downloadThreads:
            chooseThreads()
        case .clearHistory:
            confirm(title: "确定清空全部历史记录？") { [weak self] in
                self?.store.clearHistory()
            }
        case .clearWebsiteData:
            confirm(title: "确定清除全部网站数据？") { [weak self] in
                self?.onClearWebsiteData?()
            }
        case .clearBookmarks:
            confirm(title: "确定清空全部书签？") { [weak self] in
                self?.store.clearBookmarks()
            }
        case .saveHistory, .blockAds, .version, .engine, .downloadEngine:
            break
        }
    }

    // MARK: - 控件

    private func makeSwitch(isOn: Bool, action: Selector) -> UISwitch {
        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.onTintColor = Theme.accent
        toggle.addTarget(self, action: action, for: .valueChanged)
        return toggle
    }

    @objc private func historySwitchChanged(_ sender: UISwitch) {
        settings.saveHistory = sender.isOn
    }

    @objc private func adBlockSwitchChanged(_ sender: UISwitch) {
        settings.blockAds = sender.isOn
        onAdBlockChanged?()
    }

    // MARK: - 选择器

    private func chooseSearchEngine() {
        let sheet = UIAlertController(title: "搜索引擎", message: nil, preferredStyle: .actionSheet)
        for engine in SearchEngine.allCases {
            let title = engine == settings.searchEngine ? "\(engine.displayName) ✓" : engine.displayName
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.settings.searchEngine = engine
                self?.tableView.reloadData()
                self?.onChange?()
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: IndexPath(row: 0, section: Section.general.rawValue))
        }
        present(sheet, animated: true)
    }

    private func chooseUserAgent() {
        let sheet = UIAlertController(title: "浏览器标识（UA）", message: nil, preferredStyle: .actionSheet)
        for preset in UserAgentPreset.allCases {
            let title = preset == settings.userAgent ? "\(preset.displayName) ✓" : preset.displayName
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.settings.userAgent = preset
                self?.tableView.reloadData()
                self?.onUserAgentChanged?()
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: IndexPath(row: 1, section: Section.general.rawValue))
        }
        present(sheet, animated: true)
    }

    private func chooseThreads() {
        let sheet = UIAlertController(title: "下载线程（最高 64）", message: nil, preferredStyle: .actionSheet)
        for count in [8, 16, 32, 48, 64] {
            let title = count == settings.downloadThreads ? "\(count) 线程 ✓" : "\(count) 线程"
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.settings.downloadThreads = count
                self?.tableView.reloadData()
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: IndexPath(row: 3, section: Section.general.rawValue))
        }
        present(sheet, animated: true)
    }

    private func chooseAppearance() {
        let sheet = UIAlertController(title: "外观", message: nil, preferredStyle: .actionSheet)
        let options: [(String, UIUserInterfaceStyle)] = [
            ("跟随系统（自动深浅色）", .unspecified),
            ("浅色", .light),
            ("深色", .dark)
        ]
        for (name, style) in options {
            let title = style == settings.appearance ? "\(name) ✓" : name
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.settings.appearance = style
                self?.applyAppearance()
                self?.tableView.reloadData()
                self?.onChange?()
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: IndexPath(row: 2, section: Section.general.rawValue))
        }
        present(sheet, animated: true)
    }

    private func applyAppearance() {
        overrideUserInterfaceStyle = settings.appearance
        if let window = view.window {
            window.overrideUserInterfaceStyle = settings.appearance
        }
        view.backgroundColor = Theme.background
        tableView.backgroundColor = Theme.background
        tableView.reloadData()
    }

    private func appearanceName(_ style: UIUserInterfaceStyle) -> String {
        switch style {
        case .light: return "浅色"
        case .dark: return "深色"
        default: return "跟随系统"
        }
    }

    private func confirm(title: String, action: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: title, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { _ in action() })
        present(alert, animated: true)
    }
}
