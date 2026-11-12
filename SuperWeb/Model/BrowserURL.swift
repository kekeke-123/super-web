import Foundation

/// 把地址栏里的一串文字变成真正的 URL：能当网址就访问，否则搜索。
enum BrowserURL {

    static func url(fromInput input: String, engine: SearchEngine) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 已经带协议头的，直接放行
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https", "file", "about", "data"].contains(scheme) {
            return url
        }

        // 形如 example.com、localhost:8080 的裸域名
        if looksLikeHost(trimmed), let url = URL(string: "https://" + trimmed) {
            return url
        }

        return engine.searchURL(for: trimmed)
    }

    private static func looksLikeHost(_ text: String) -> Bool {
        guard !text.contains(" ") else { return false }

        let hostPart = text.split(separator: "/").first.map(String.init) ?? text
        let hostOnly = hostPart.split(separator: ":").first.map(String.init) ?? hostPart

        if hostOnly == "localhost" { return true }
        if hostOnly.hasPrefix("localhost.") { return true }

        let pieces = hostOnly.split(separator: ".")
        guard pieces.count >= 2, pieces.allSatisfy({ !$0.isEmpty }) else { return false }

        // 全数字 → IPv4
        if pieces.allSatisfy({ $0.allSatisfy { $0.isNumber } }) { return true }

        // 末段必须是字母组成的顶级域（com / cn / org / io ...）
        guard let last = pieces.last, last.count >= 2, last.allSatisfy({ $0.isLetter }) else { return false }
        return true
    }
}
