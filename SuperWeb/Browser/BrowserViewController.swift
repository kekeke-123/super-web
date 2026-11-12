import UIKit
import UniformTypeIdentifiers
import WebKit

final class BrowserViewController: UIViewController {

    // MARK: - 依赖

    private let tabs = TabManager()
    private let store = HistoryStore.shared
    private let settings = Settings.shared

    // MARK: - 视图

    private let contentView = UIView()
    private let topBar = UIView()
    private let menuButton = UIButton(type: .system)
    private let addressBar = AddressBarView()
    private let progressBar = ProgressBarView()
    private let toolbar = BrowserToolbar()
    private let startPage = StartPageView()
    private let errorView = ErrorView()

    private var failedURL: URL?
    private var pendingExternalURL: URL?
    private var observers: [NSObjectProtocol] = []

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        buildLayout()
        connectActions()
        applyAppearance()

        restoreSessionIfNeeded()
        observeSystemEvents()

        if let pending = pendingExternalURL {
            pendingExternalURL = nil
            openExternalURL(pending)
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return overrideUserInterfaceStyle == .light ? .darkContent : .lightContent
    }

    // MARK: - 布局

    private func buildLayout() {
        let chromeViews: [UIView] = [contentView, topBar, progressBar, toolbar, startPage, errorView]
        chromeViews.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        addressBar.translatesAutoresizingMaskIntoConstraints = false

        topBar.backgroundColor = Theme.chrome
        menuButton.setImage(Theme.symbol("line.3.horizontal", size: 17, weight: .medium), for: .normal)
        menuButton.tintColor = Theme.primaryText

        topBar.addSubview(menuButton)
        topBar.addSubview(addressBar)

        let safe = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: safe.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 50),

            menuButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 8),
            menuButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 34),
            menuButton.heightAnchor.constraint(equalToConstant: 34),

            addressBar.leadingAnchor.constraint(equalTo: menuButton.trailingAnchor, constant: 6),
            addressBar.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -12),
            addressBar.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            addressBar.heightAnchor.constraint(equalToConstant: 40),

            progressBar.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 2),

            contentView.topAnchor.constraint(equalTo: progressBar.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),

            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 50),

            startPage.topAnchor.constraint(equalTo: contentView.topAnchor),
            startPage.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            startPage.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            startPage.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            errorView.topAnchor.constraint(equalTo: contentView.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func connectActions() {
        menuButton.addTarget(self, action: #selector(showMenu), for: .touchUpInside)
        addressBar.textField.delegate = self
        addressBar.onReloadOrStop = { [weak self] in self?.reloadOrStop() }

        toolbar.onBack = { [weak self] in self?.goBack() }
        toolbar.onForward = { [weak self] in self?.goForward() }
        toolbar.onShare = { [weak self] in self?.sharePage() }
        toolbar.onBookmark = { [weak self] in self?.toggleBookmark() }
        toolbar.onTabs = { [weak self] in self?.showTabs() }

        startPage.onOpenURL = { [weak self] url in
            self?.load(url, in: self?.tabs.selectedTab)
        }
        errorView.onRetry = { [weak self] in self?.retry() }
    }

    private func applyAppearance() {
        overrideUserInterfaceStyle = settings.appearance
        view.backgroundColor = Theme.background
        topBar.backgroundColor = Theme.chrome
        toolbar.backgroundColor = Theme.chrome
        refreshChrome()
    }

    // MARK: - 会话恢复与外部文件

    private func restoreSessionIfNeeded() {
        if let session = SessionStore.shared.load() {
            for item in session.tabs {
                let tab = tabs.addTab(isPrivate: false, select: false)
                tab.title = item.title
                if let string = item.url {
                    tab.url = URL(string: string)
                }
            }
            if !tabs.tabs.isEmpty {
                tabs.select(at: min(max(0, session.selected), tabs.tabs.count - 1))
            }
        }

        if tabs.tabs.isEmpty {
            tabs.addTab(select: true)
        }

        for tab in tabs.tabs {
            guard let url = tab.url else { continue }
            load(url, in: tab)
        }
        if let selected = tabs.selectedTab {
            show(tab: selected)
        }
    }

    private func persistSession() {
        SessionStore.shared.save(tabs: tabs.tabs, selectedIndex: tabs.selectedIndex)
    }

    private func observeSystemEvents() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                            object: nil,
                                            queue: .main) { [weak self] _ in
            self?.persistSession()
        })
        observers.append(center.addObserver(forName: UIApplication.willTerminateNotification,
                                            object: nil,
                                            queue: .main) { [weak self] _ in
            self?.persistSession()
        })
        observers.append(center.addObserver(forName: AdBlocker.readyNotification,
                                            object: nil,
                                            queue: .main) { [weak self] _ in
            self?.applyAdBlockToOpenTabs()
        })
    }

    /// 由分享面板 /「文件」App「用 Super Web 打开」进来。
    func openExternalFile(_ url: URL) {
        guard isViewLoaded else {
            pendingExternalURL = url
            return
        }
        openExternalURL(url)
    }

    private func openExternalURL(_ url: URL) {
        let tab = tabs.addTab(isPrivate: false, select: true)
        show(tab: tab)
        load(url, in: tab)
        persistSession()
    }

    // MARK: - 标签与 WebView

    private func show(tab: Tab) {
        failedURL = nil
        errorView.hide()
        if let webView = tab.webView {
            attach(webView)
            startPage.isHidden = true
        } else {
            detachWebViews()
            startPage.isHidden = false
        }
        refreshChrome()
    }

    private func attach(_ webView: WKWebView) {
        if webView.superview === contentView {
            contentView.bringSubviewToFront(webView)
            return
        }
        detachWebViews()
        webView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: contentView.topAnchor),
            webView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func detachWebViews() {
        contentView.subviews.forEach { $0.removeFromSuperview() }
    }

    private func ensureWebView(for tab: Tab) {
        guard tab.webView == nil else { return }
        let webView = tab.makeWebView(configuration: tabs.configuration(for: tab))
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.customUserAgent = settings.userAgent.string
        AdBlocker.shared.apply(to: webView)
        observe(webView, tab: tab)
    }

    private func observe(_ webView: WKWebView, tab: Tab) {
        tab.observations.append(webView.observe(\.title, options: [.new]) { [weak self, weak tab] webView, _ in
            guard let self = self, let tab = tab else { return }
            tab.title = webView.title ?? ""
            if tab === self.tabs.selectedTab {
                DispatchQueue.main.async { self.refreshChrome() }
            }
        })

        tab.observations.append(webView.observe(\.isLoading, options: [.new]) { [weak self, weak tab] _, _ in
            guard let self = self, let tab = tab, tab === self.tabs.selectedTab else { return }
            DispatchQueue.main.async { self.refreshChrome() }
        })

        tab.observations.append(webView.observe(\.estimatedProgress, options: [.new]) { [weak self, weak tab] webView, _ in
            guard let self = self, let tab = tab, tab === self.tabs.selectedTab else { return }
            DispatchQueue.main.async {
                self.progressBar.set(progress: webView.estimatedProgress)
                self.progressBar.alpha = webView.isLoading ? 1.0 : 0.0
            }
        })
    }

    private func load(_ url: URL, in tab: Tab?) {
        guard let tab = tab else { return }
        ensureWebView(for: tab)
        guard let webView = tab.webView else { return }
        tab.url = url
        tab.title = ""
        errorView.hide()
        attach(webView)
        startPage.isHidden = true
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
        refreshChrome()
    }

    // MARK: - 界面状态

    private func refreshChrome() {
        guard let tab = tabs.selectedTab else { return }
        let webView = tab.webView
        let isLoading = webView?.isLoading ?? false

        addressBar.update(isSecure: tab.url?.scheme == "https",
                          isLoading: isLoading,
                          isPrivate: tab.isPrivate)

        if !addressBar.textField.isFirstResponder {
            addressBar.textField.text = tab.url?.absoluteString ?? ""
        }

        if let webView = webView {
            progressBar.set(progress: webView.estimatedProgress)
            progressBar.alpha = isLoading ? 1.0 : 0.0
        } else {
            progressBar.set(progress: 0)
            progressBar.alpha = 0
        }

        toolbar.update(canGoBack: webView?.canGoBack ?? false,
                       canGoForward: webView?.canGoForward ?? false,
                       isBookmarked: store.isBookmarked(url: tab.url?.absoluteString ?? ""),
                       tabCount: tabs.tabs.count,
                       isPrivate: tab.isPrivate)

        startPage.isHidden = webView != nil
    }

    // MARK: - 导航动作

    private func goBack() {
        guard let webView = tabs.selectedTab?.webView, webView.canGoBack else { return }
        webView.goBack()
        refreshChrome()
    }

    private func goForward() {
        guard let webView = tabs.selectedTab?.webView, webView.canGoForward else { return }
        webView.goForward()
        refreshChrome()
    }

    private func reloadOrStop() {
        guard let tab = tabs.selectedTab, let webView = tab.webView else { return }
        if webView.isLoading {
            webView.stopLoading()
        } else if let url = tab.url {
            webView.load(URLRequest(url: url))
        } else {
            webView.reload()
        }
        refreshChrome()
    }

    private func retry() {
        errorView.hide()
        if let url = failedURL {
            load(url, in: tabs.selectedTab)
        } else {
            tabs.selectedTab?.webView?.reload()
        }
    }

    private func submitAddressBar() {
        let text = addressBar.textField.text ?? ""
        guard let url = BrowserURL.url(fromInput: text, engine: settings.searchEngine) else {
            addressBar.textField.resignFirstResponder()
            return
        }
        addressBar.textField.resignFirstResponder()
        load(url, in: tabs.selectedTab)
    }

    // MARK: - 菜单

    @objc private func showMenu() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "新建标签页", style: .default) { [weak self] _ in
            self?.newTab(isPrivate: false)
        })
        sheet.addAction(UIAlertAction(title: "新建无痕标签页", style: .default) { [weak self] _ in
            self?.newTab(isPrivate: true)
        })
        sheet.addAction(UIAlertAction(title: "下载（\(DownloadManager.shared.jobs.count)）",
                                      style: .default) { [weak self] _ in
            self?.showDownloads()
        })
        sheet.addAction(UIAlertAction(title: "保存当前页为 HTML", style: .default) { [weak self] _ in
            self?.savePageAsHTML()
        })
        sheet.addAction(UIAlertAction(title: "打开本地 HTML 文件", style: .default) { [weak self] _ in
            self?.openLocalHTML()
        })
        sheet.addAction(UIAlertAction(title: "浏览器标识：\(settings.userAgent.displayName)",
                                      style: .default) { [weak self] _ in
            self?.chooseUserAgent()
        })
        sheet.addAction(UIAlertAction(title: "书签", style: .default) { [weak self] _ in
            self?.showBookmarks()
        })
        sheet.addAction(UIAlertAction(title: "历史记录", style: .default) { [weak self] _ in
            self?.showHistory()
        })
        sheet.addAction(UIAlertAction(title: "设置", style: .default) { [weak self] _ in
            self?.showSettings()
        })
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = menuButton
            popover.sourceRect = menuButton.bounds
        }
        present(sheet, animated: true)
    }

    private func newTab(isPrivate: Bool, loading url: URL? = nil) {
        let tab = tabs.addTab(isPrivate: isPrivate, select: true)
        tabs.isPrivateMode = isPrivate
        show(tab: tab)
        if let url = url {
            load(url, in: tab)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.addressBar.textField.becomeFirstResponder()
            }
        }
        persistSession()
    }

    private func sharePage() {
        guard let url = tabs.selectedTab?.url else { return }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = toolbar
            popover.sourceRect = toolbar.bounds
        }
        present(controller, animated: true)
    }

    private func toggleBookmark() {
        guard let tab = tabs.selectedTab, let url = tab.url?.absoluteString else { return }
        store.toggleBookmark(url: url, title: tab.displayTitle)
        refreshChrome()
    }

    private func startDownload(url: URL, referer: URL?) {
        DownloadManager.shared.start(url: url, referer: referer)
        if presentedViewController == nil {
            showDownloads()
        }
    }

    private func showDownloads() {
        let controller = DownloadsViewController(style: .plain)
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .pageSheet
        present(navigation, animated: true)
    }

    private func savePageAsHTML() {
        guard let tab = tabs.selectedTab, let webView = tab.webView else {
            presentMessage("当前页面还不能保存")
            return
        }
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                self.presentMessage("保存失败：\(error.localizedDescription)")
                return
            }
            guard let html = result as? String, !html.isEmpty else {
                self.presentMessage("这个页面没有可保存的 HTML")
                return
            }

            let directory = DownloadManager.downloadsDirectory()
                .deletingLastPathComponent()
                .appendingPathComponent("Saved Pages", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let fileName = Self.safeFileName(tab.displayTitle) + ".html"
            let fileURL = DownloadManager.uniqueURL(in: directory, fileName: fileName)
            do {
                try ("<!DOCTYPE html>\n" + html).write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                self.presentMessage("写入失败：\(error.localizedDescription)")
                return
            }

            let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            if let popover = controller.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = self.view.bounds
            }
            self.present(controller, animated: true)
        }
    }

    private static func safeFileName(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Untitled" : trimmed
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r")
        let cleaned = base.components(separatedBy: invalid).joined(separator: "_")
        return String(cleaned.prefix(60))
    }

    private func openLocalHTML() {
        var types: [UTType] = []
        for ext in ["html", "htm"] {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }
        if types.isEmpty {
            types = [.text]
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func presentMessage(_ text: String) {
        let alert = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default, handler: nil))
        present(alert, animated: true)
    }

    private func chooseUserAgent() {
        let sheet = UIAlertController(title: "浏览器标识（UA）", message: nil, preferredStyle: .actionSheet)
        for preset in UserAgentPreset.allCases {
            let title = preset == settings.userAgent ? "\(preset.displayName) ✓" : preset.displayName
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.settings.userAgent = preset
                self.applyUserAgent()
                self.tabs.selectedTab?.webView?.reload()
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = menuButton
            popover.sourceRect = menuButton.bounds
        }
        present(sheet, animated: true)
    }

    private func applyUserAgent() {
        let string = settings.userAgent.string
        for tab in tabs.tabs {
            tab.webView?.customUserAgent = string
        }
    }

    private func applyAdBlockToOpenTabs() {
        for tab in tabs.tabs {
            if let webView = tab.webView {
                AdBlocker.shared.apply(to: webView)
            }
        }
    }

    private func refreshAdBlock() {
        for tab in tabs.tabs {
            tab.webView?.configuration.userContentController.removeAllContentRuleLists()
        }
        AdBlocker.shared.reset()
        if settings.blockAds {
            AdBlocker.shared.prepare()
            applyAdBlockToOpenTabs()
        }
        tabs.selectedTab?.webView?.reload()
    }

    private func showTabs() {
        let controller = TabGridViewController(tabs: tabs)
        controller.onSelect = { [weak self] tab in
            guard let self = self else { return }
            self.dismiss(animated: true) {
                self.tabs.select(tab)
                if let selected = self.tabs.selectedTab {
                    self.show(tab: selected)
                }
                self.persistSession()
            }
        }
        controller.onClose = { [weak self] tab in
            guard let self = self else { return }
            self.tabs.close(tab)
            if let selected = self.tabs.selectedTab {
                self.show(tab: selected)
            }
            self.persistSession()
        }
        controller.onNewTab = { [weak self] isPrivate in
            guard let self = self else { return }
            self.dismiss(animated: true) {
                self.newTab(isPrivate: isPrivate)
            }
        }
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }

    private func showHistory() {
        let controller = BrowseListViewController(mode: .history)
        controller.onSelect = { [weak self] urlString in
            guard let self = self, let url = URL(string: urlString) else { return }
            self.load(url, in: self.tabs.selectedTab)
        }
        presentNavigation(controller)
    }

    private func showBookmarks() {
        let controller = BrowseListViewController(mode: .bookmarks)
        controller.onSelect = { [weak self] urlString in
            guard let self = self, let url = URL(string: urlString) else { return }
            self.load(url, in: self.tabs.selectedTab)
        }
        presentNavigation(controller)
    }

    private func showSettings() {
        let controller = SettingsViewController(style: .insetGrouped)
        controller.onChange = { [weak self] in
            self?.applyAppearance()
        }
        controller.onUserAgentChanged = { [weak self] in
            guard let self = self else { return }
            self.applyUserAgent()
            self.tabs.selectedTab?.webView?.reload()
        }
        controller.onAdBlockChanged = { [weak self] in
            self?.refreshAdBlock()
        }
        controller.onClearWebsiteData = { [weak self] in
            guard let self = self else { return }
            self.tabs.clearWebsiteData {
                self.refreshChrome()
            }
        }
        presentNavigation(controller)
    }

    private func presentNavigation(_ controller: UIViewController) {
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .pageSheet
        present(navigation, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension BrowserViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let beginning = textField.beginningOfDocument
        let end = textField.endOfDocument
        textField.selectedTextRange = textField.textRange(from: beginning, to: end)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submitAddressBar()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.text = tabs.selectedTab?.url?.absoluteString ?? ""
    }
}

// MARK: - WKNavigationDelegate

extension BrowserViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard let tab = tabs.tab(containing: webView) else { return }
        tab.url = webView.url ?? tab.url
        errorView.hide()
        if tab === tabs.selectedTab { refreshChrome() }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if !navigationResponse.canShowMIMEType, let url = navigationResponse.response.url {
            decisionHandler(.cancel)
            startDownload(url: url, referer: webView.url)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let tab = tabs.tab(containing: webView) else { return }
        tab.url = webView.url
        tab.title = webView.title ?? ""

        if !tab.isPrivate,
           settings.saveHistory,
           let url = webView.url,
           let scheme = url.scheme,
           scheme.hasPrefix("http") {
            store.record(url: url.absoluteString, title: tab.title)
        }

        errorView.hide()
        if tab === tabs.selectedTab { refreshChrome() }
        persistSession()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleFailure(error, in: webView)
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        handleFailure(error, in: webView)
    }

    private func handleFailure(_ error: Error, in webView: WKWebView) {
        guard let tab = tabs.tab(containing: webView), tab === tabs.selectedTab else { return }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return }
        failedURL = tab.url
        errorView.show(message: nsError.localizedDescription)
        progressBar.alpha = 0
        refreshChrome()
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.shouldPerformDownload, let url = navigationAction.request.url {
            decisionHandler(.cancel)
            startDownload(url: url, referer: webView.url)
            return
        }

        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
            decisionHandler(.allow)
            return
        }

        if ["http", "https", "about", "file", "data", "blob"].contains(scheme) {
            decisionHandler(.allow)
            return
        }

        // tel: / mailto: / itms-apps: 之类的交给系统
        if ["tel", "mailto", "sms", "maps", "itms-apps", "itms-services"].contains(scheme) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        decisionHandler(.cancel)
    }
}

// MARK: - WKUIDelegate

extension BrowserViewController: WKUIDelegate {

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        // target="_blank" 的链接：开一个新标签
        if let url = navigationAction.request.url {
            let isPrivate = tabs.selectedTab?.isPrivate ?? false
            newTab(isPrivate: isPrivate, loading: url)
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        guard presentedViewController == nil else {
            completionHandler()
            return
        }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        guard presentedViewController == nil else {
            completionHandler(false)
            return
        }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        guard presentedViewController == nil else {
            completionHandler(defaultText)
            return
        }
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = defaultText
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak alert] _ in
            completionHandler(alert?.textFields?.first?.text)
        })
        present(alert, animated: true)
    }
}

extension BrowserViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        openExternalURL(url)
    }
}
