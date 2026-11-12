import UIKit
import WebKit

/// 一个标签页。WebView 按需创建，切换标签时保留页面状态。
final class Tab {

    let id = UUID()
    var title: String = ""
    var url: URL?
    var isPrivate: Bool
    var lastVisited: Date = Date()
    private(set) var webView: WKWebView?
    var observations: [NSKeyValueObservation] = []

    init(isPrivate: Bool = false, url: URL? = nil) {
        self.isPrivate = isPrivate
        self.url = url
    }

    var displayTitle: String {
        if !title.isEmpty { return title }
        if let host = url?.host, !host.isEmpty { return host }
        return "新标签页"
    }

    var displayURL: String {
        url?.absoluteString ?? "尚未访问"
    }

    func makeWebView(configuration: WKWebViewConfiguration) -> WKWebView {
        if let existing = webView { return existing }
        let created = WKWebView(frame: .zero, configuration: configuration)
        created.allowsBackForwardNavigationGestures = true
        created.allowsLinkPreview = true
        created.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView = created
        return created
    }

    func dispose() {
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
        webView?.removeFromSuperview()
        webView = nil
    }
}
