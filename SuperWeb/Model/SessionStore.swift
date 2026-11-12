import Foundation

/// 会话恢复：记住上次打开的标签页（不保存无痕标签）。
struct SessionTab: Codable {
    var url: String?
    var title: String
}

final class SessionStore {

    static let shared = SessionStore()

    private let fileURL: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("SuperWeb", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("session.json")
    }

    func save(tabs: [Tab], selectedIndex: Int) {
        var items: [SessionTab] = []
        var selected = 0
        for (index, tab) in tabs.enumerated() where !tab.isPrivate {
            if index <= selectedIndex { selected = items.count }
            items.append(SessionTab(url: tab.url?.absoluteString, title: tab.title))
        }
        guard !items.isEmpty else { return }
        if selected >= items.count { selected = items.count - 1 }
        let payload = SessionPayload(tabs: items, selected: max(0, selected))
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func load() -> SessionPayload? {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(SessionPayload.self, from: data),
              !payload.tabs.isEmpty else { return nil }
        return payload
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

struct SessionPayload: Codable {
    var tabs: [SessionTab]
    var selected: Int
}
