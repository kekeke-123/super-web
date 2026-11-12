import Foundation
import WebKit

/// 标签页集合与当前选中项。
final class TabManager {

    private(set) var tabs: [Tab] = []
    private(set) var selectedIndex: Int = 0
    var isPrivateMode: Bool = false

    /// 无痕标签共用一个非持久化数据存储：关掉标签即丢 Cookie。
    static let privateDataStore = WKWebsiteDataStore.nonPersistent()

    var selectedTab: Tab? {
        guard tabs.indices.contains(selectedIndex) else { return nil }
        return tabs[selectedIndex]
    }

    @discardableResult
    func addTab(isPrivate: Bool? = nil, select: Bool = true) -> Tab {
        let tab = Tab(isPrivate: isPrivate ?? isPrivateMode)
        tabs.append(tab)
        if select { selectedIndex = tabs.count - 1 }
        return tab
    }

    func select(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        selectedIndex = index
    }

    func select(_ tab: Tab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        selectedIndex = index
        tab.lastVisited = Date()
    }

    func close(_ tab: Tab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tab.dispose()
        tabs.remove(at: index)

        if tabs.isEmpty {
            tabs = [Tab(isPrivate: tab.isPrivate)]
            selectedIndex = 0
            return
        }
        if index < selectedIndex {
            selectedIndex -= 1
        } else if index == selectedIndex {
            selectedIndex = min(index, tabs.count - 1)
        }
    }

    func closeAll() {
        tabs.forEach { $0.dispose() }
        tabs = [Tab(isPrivate: isPrivateMode)]
        selectedIndex = 0
    }

    func tab(containing webView: WKWebView) -> Tab? {
        return tabs.first { $0.webView === webView }
    }

    func configuration(for tab: Tab) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = tab.isPrivate ? TabManager.privateDataStore : WKWebsiteDataStore.default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        AdBlocker.shared.apply(to: configuration)
        return configuration
    }

    func clearWebsiteData(completion: @escaping () -> Void) {
        let store = WKWebsiteDataStore.default()
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                         modifiedSince: Date(timeIntervalSince1970: 0)) {
            DispatchQueue.main.async { completion() }
        }
    }
}
