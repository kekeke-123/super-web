import Foundation

/// 可选的搜索引擎。地址栏输入的不是网址时，交给它来搜索。
enum SearchEngine: String, CaseIterable {
    case bing
    case baidu
    case sogou
    case google
    case duckduckgo

    var displayName: String {
        switch self {
        case .bing: return "必应 Bing"
        case .baidu: return "百度"
        case .sogou: return "搜狗"
        case .google: return "Google"
        case .duckduckgo: return "DuckDuckGo"
        }
    }

    var host: String {
        switch self {
        case .bing: return "cn.bing.com"
        case .baidu: return "www.baidu.com"
        case .sogou: return "www.sogou.com"
        case .google: return "www.google.com"
        case .duckduckgo: return "duckduckgo.com"
        }
    }

    private var endpoint: String {
        switch self {
        case .bing: return "https://cn.bing.com/search"
        case .baidu: return "https://www.baidu.com/s"
        case .sogou: return "https://www.sogou.com/web"
        case .google: return "https://www.google.com/search"
        case .duckduckgo: return "https://duckduckgo.com/"
        }
    }

    private var queryKey: String {
        switch self {
        case .baidu: return "wd"
        case .sogou: return "query"
        default: return "q"
        }
    }

    func searchURL(for query: String) -> URL? {
        guard var components = URLComponents(string: endpoint) else { return nil }
        components.queryItems = [URLQueryItem(name: queryKey, value: query)]
        return components.url
    }
}
