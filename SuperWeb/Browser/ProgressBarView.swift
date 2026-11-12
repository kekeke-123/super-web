import UIKit

/// 顶部 2pt 的加载进度条。
final class ProgressBarView: UIView {

    private let bar = UIView()
    private var fraction: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
        bar.backgroundColor = Theme.accent
        addSubview(bar)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(progress: Double) {
        let clamped = CGFloat(min(max(progress, 0), 1))
        fraction = clamped
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width * fraction
        bar.frame = CGRect(x: 0, y: 0, width: width, height: bounds.height)
    }
}
