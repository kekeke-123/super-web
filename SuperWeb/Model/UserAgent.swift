import Foundation

/// 内置浏览器标识（User-Agent）预设。
enum UserAgentPreset: String, CaseIterable {
    case iphone
    case ipad
    case macbook
    case android
    case symbian
    case windows7
    case windows

    var displayName: String {
        switch self {
        case .iphone: return "iPhone"
        case .ipad: return "iPad"
        case .macbook: return "MacBook"
        case .android: return "Android"
        case .symbian: return "塞班 Symbian"
        case .windows7: return "Old Windows (Win7)"
        case .windows: return "Windows"
        }
    }

    var string: String {
        switch self {
        case .iphone:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        case .ipad:
            return "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        case .macbook:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
        case .android:
            return "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36"
        case .symbian:
            return "Mozilla/5.0 (SymbianOS/9.4; Series60/5.0 NokiaN97-1/20.0.019; Profile/MIDP-2.1 Configuration/CLDC-1.1) AppleWebKit/525 (KHTML, like Gecko) BrowserNG/7.2.0"
        case .windows7:
            return "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.112 Safari/537.36"
        case .windows:
            return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        }
    }
}
