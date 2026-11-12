import Foundation
import WebKit

/// 广告拦截：编译一份 WKContentRuleList，注入到每个 WebView 的加载配置里。
final class AdBlocker {

    static let shared = AdBlocker()

    static let readyNotification = Notification.Name("SuperWebAdBlockReady")

    private(set) var ruleList: WKContentRuleList?
    private var isCompiling = false
    /// 已经注入过的 userContentController，避免重复添加同一条规则表。
    private var appliedControllers = Set<ObjectIdentifier>()

    private init() {}

    func prepare() {
        guard Settings.shared.blockAds, ruleList == nil, !isCompiling else { return }
        isCompiling = true
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "SuperWebAdBlock",
            encodedContentRuleList: Self.rulesJSON
        ) { [weak self] list, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isCompiling = false
                self.ruleList = list
                if list != nil {
                    NotificationCenter.default.post(name: AdBlocker.readyNotification, object: nil)
                }
            }
        }
    }

    func reset() {
        ruleList = nil
        isCompiling = false
        appliedControllers.removeAll()
    }

    func apply(to configuration: WKWebViewConfiguration) {
        guard Settings.shared.blockAds, let ruleList = ruleList else { return }
        let controller = configuration.userContentController
        let identifier = ObjectIdentifier(controller)
        guard !appliedControllers.contains(identifier) else { return }
        controller.add(ruleList)
        appliedControllers.insert(identifier)
    }

    func apply(to webView: WKWebView) {
        apply(to: webView.configuration)
    }

    /// 只拦截广告域名与明显的广告路径，尽量不误伤正文。
    private static let rulesJSON = """
    [
      {"trigger": {"url-filter": "^https?://(.*\\\\.)?doubleclick\\\\.net"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^https?://(.*\\\\.)?googlesyndication\\\\.com"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^https?://(.*\\\\.)?googleadservices\\\\.com"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^https?://(.*\\\\.)?adservice\\\\.google\\\\.com"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^https?://(.*\\\\.)?cpro\\\\.baidu\\\\.com"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^https?://(.*\\\\.)?pos\\\\.baidu\\\\.com"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^https?://(.*\\\\.)?tanx\\\\.com"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^https?://(.*\\\\.)?mmstat\\\\.com"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^https?://(.*\\\\.)?admaster\\\\.com\\\\.cn"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^https?://(.*\\\\.)?adnxs\\\\.com"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^https?://(.*\\\\.)?criteo\\\\.com"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^https?://(.*\\\\.)?taboola\\\\.com"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^https?://(.*\\\\.)?outbrain\\\\.com"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "/ads?/", "resource-type": ["image", "script", "raw"]}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "/adserver", "resource-type": ["image", "script", "raw"]}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "/popunder", "resource-type": ["script", "raw"]}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "/banner[0-9]*\\\\.(jpg|png|gif)", "resource-type": ["image"]}, "action": {"type": "block"}}
    ]
    """
}
