import Foundation

struct HistoryEntry: Codable {
    let url: String
    let title: String
    let date: Date
}

struct BookmarkEntry: Codable {
    let url: String
    let title: String
    let date: Date
}

/// 浏览历史与书签的本地存储（Application Support 下的两个 JSON 文件）。
final class HistoryStore {

    static let shared = HistoryStore()

    private let historyFile: URL
    private let bookmarkFile: URL
    private let maxHistoryCount = 3000

    private(set) var history: [HistoryEntry] = []
    private(set) var bookmarks: [BookmarkEntry] = []

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("SuperWeb", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        historyFile = directory.appendingPathComponent("history.json")
        bookmarkFile = directory.appendingPathComponent("bookmarks.json")
        load()
    }

    // MARK: - 历史

    func record(url: String, title: String) {
        guard !url.isEmpty else { return }
        let entry = HistoryEntry(url: url, title: title.isEmpty ? url : title, date: Date())
        history.insert(entry, at: 0)
        if history.count > maxHistoryCount {
            history.removeLast(history.count - maxHistoryCount)
        }
        save(history, to: historyFile)
    }

    func clearHistory() {
        history.removeAll()
        save(history, to: historyFile)
    }

    func removeHistory(at index: Int) {
        guard history.indices.contains(index) else { return }
        history.remove(at: index)
        save(history, to: historyFile)
    }

    // MARK: - 书签

    func isBookmarked(url: String) -> Bool {
        guard !url.isEmpty else { return false }
        return bookmarks.contains { $0.url == url }
    }

    @discardableResult
    func toggleBookmark(url: String, title: String) -> Bool {
        guard !url.isEmpty else { return false }
        if let index = bookmarks.firstIndex(where: { $0.url == url }) {
            bookmarks.remove(at: index)
            save(bookmarks, to: bookmarkFile)
            return false
        }
        bookmarks.insert(BookmarkEntry(url: url, title: title.isEmpty ? url : title, date: Date()), at: 0)
        save(bookmarks, to: bookmarkFile)
        return true
    }

    func removeBookmark(at index: Int) {
        guard bookmarks.indices.contains(index) else { return }
        bookmarks.remove(at: index)
        save(bookmarks, to: bookmarkFile)
    }

    func clearBookmarks() {
        bookmarks.removeAll()
        save(bookmarks, to: bookmarkFile)
    }

    // MARK: - 磁盘

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: historyFile),
           let decoded = try? decoder.decode([HistoryEntry].self, from: data) {
            history = decoded
        }
        if let data = try? Data(contentsOf: bookmarkFile),
           let decoded = try? decoder.decode([BookmarkEntry].self, from: data) {
            bookmarks = decoded
        }
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
