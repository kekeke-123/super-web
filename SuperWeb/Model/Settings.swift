import UIKit

/// 轻量设置存储，全部走 UserDefaults。
final class Settings {

    static let shared = Settings()

    private enum Key {
        static let searchEngine = "sw.searchEngine"
        static let appearance = "sw.appearance"
        static let saveHistory = "sw.saveHistory"
        static let downloadThreads = "sw.downloadThreads"
        static let userAgent = "sw.userAgent"
        static let blockAds = "sw.blockAds"
    }

    private let defaults = UserDefaults.standard

    private init() {}

    var searchEngine: SearchEngine {
        get {
            guard let raw = defaults.string(forKey: Key.searchEngine),
                  let engine = SearchEngine(rawValue: raw) else { return .bing }
            return engine
        }
        set { defaults.set(newValue.rawValue, forKey: Key.searchEngine) }
    }

    var appearance: UIUserInterfaceStyle {
        get { UIUserInterfaceStyle(rawValue: defaults.integer(forKey: Key.appearance)) ?? .unspecified }
        set { defaults.set(newValue.rawValue, forKey: Key.appearance) }
    }

    var saveHistory: Bool {
        get {
            if let stored = defaults.object(forKey: Key.saveHistory) as? Bool { return stored }
            return true
        }
        set { defaults.set(newValue, forKey: Key.saveHistory) }
    }

    /// 下载线程数：默认 32，范围 1...64。
    var downloadThreads: Int {
        get {
            let stored = defaults.integer(forKey: Key.downloadThreads)
            guard stored > 0 else { return 32 }
            return min(64, max(1, stored))
        }
        set { defaults.set(min(64, max(1, newValue)), forKey: Key.downloadThreads) }
    }

    var userAgent: UserAgentPreset {
        get { UserAgentPreset(rawValue: defaults.string(forKey: Key.userAgent) ?? "") ?? .iphone }
        set { defaults.set(newValue.rawValue, forKey: Key.userAgent) }
    }

    var blockAds: Bool {
        get {
            if let stored = defaults.object(forKey: Key.blockAds) as? Bool { return stored }
            return true
        }
        set { defaults.set(newValue, forKey: Key.blockAds) }
    }
}
