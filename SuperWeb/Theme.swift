import UIKit

/// Super Web 的配色与图标工具。
/// 视觉上参考 Chromium / Chrome 的形态：中性灰底、蓝色强调、胶囊地址栏。
enum Theme {

    static let accent = UIColor(red: 0.102, green: 0.451, blue: 0.910, alpha: 1.0)

    static let background = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.078, green: 0.078, blue: 0.086, alpha: 1.0)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    }

    static let chrome = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.125, green: 0.125, blue: 0.137, alpha: 1.0)
            : UIColor(red: 0.969, green: 0.969, blue: 0.976, alpha: 1.0)
    }

    static let surface = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.176, green: 0.176, blue: 0.192, alpha: 1.0)
            : UIColor(red: 0.949, green: 0.949, blue: 0.961, alpha: 1.0)
    }

    static let field = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.208, green: 0.208, blue: 0.227, alpha: 1.0)
            : UIColor(red: 0.937, green: 0.937, blue: 0.945, alpha: 1.0)
    }

    static let privateField = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.184, green: 0.169, blue: 0.227, alpha: 1.0)
            : UIColor(red: 0.929, green: 0.918, blue: 0.961, alpha: 1.0)
    }

    static let primaryText = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.945, alpha: 1.0)
            : UIColor(white: 0.129, alpha: 1.0)
    }

    static let secondaryText = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.659, alpha: 1.0)
            : UIColor(white: 0.404, alpha: 1.0)
    }

    static let tertiaryText = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.478, alpha: 1.0)
            : UIColor(white: 0.620, alpha: 1.0)
    }

    static let separator = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.259, alpha: 1.0)
            : UIColor(white: 0.886, alpha: 1.0)
    }

    static func symbol(_ name: String,
                       size: CGFloat = 18,
                       weight: UIImage.SymbolWeight = .regular) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: size, weight: weight)
        return UIImage(systemName: name, withConfiguration: configuration)
    }
}
