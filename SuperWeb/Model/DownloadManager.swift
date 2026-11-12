import Foundation
import UIKit
import WebKit

// MARK: - 小工具

private func fileSize(at url: URL) -> Int64 {
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
}

private func bytesText(_ bytes: Int64) -> String {
    if bytes < 1024 { return "\(bytes) B" }
    let units = ["KB", "MB", "GB", "TB"]
    var value = Double(bytes) / 1024.0
    var index = 0
    while value >= 1024.0 && index < units.count - 1 {
        value /= 1024.0
        index += 1
    }
    return String(format: "%.1f %@", value, units[index])
}

private func speedText(_ bytesPerSecond: Double) -> String {
    if bytesPerSecond <= 0 { return "—" }
    return bytesText(Int64(bytesPerSecond)) + "/s"
}

enum DownloadState: String {
    case probing
    case running
    case paused
    case finished
    case failed
    case cancelled

    var isActive: Bool {
        return self == .probing || self == .running
    }
}

// MARK: - 单个下载任务

final class DownloadJob: NSObject {

    struct Segment {
        let index: Int
        let lower: Int64
        let upper: Int64
        let fileURL: URL
    }

    let id = UUID()
    let url: URL
    let referer: URL?
    let createdAt = Date()

    var fileName: String
    var state: DownloadState = .probing
    var totalBytes: Int64 = 0
    var receivedBytes: Int64 = 0
    var speed: Double = 0
    var threadCount: Int
    var errorMessage: String?
    var destinationURL: URL?

    fileprivate var segments: [Segment] = []
    fileprivate var baselineBytes: [Int: Int64] = [:]
    fileprivate var progressBytes: [Int: Int64] = [:]
    fileprivate var session: URLSession?
    fileprivate var taskSegment: [Int: Int] = [:]
    fileprivate var runningSegments = 0
    fileprivate var tempDirectory: URL?
    fileprivate var lastSpeedSample = Date()
    fileprivate var lastSpeedBytes: Int64 = 0
    fileprivate var cookieHeader: String = ""

    init(url: URL, referer: URL?, fileName: String, threadCount: Int) {
        self.url = url
        self.referer = referer
        self.fileName = fileName
        self.threadCount = threadCount
        super.init()
    }

    var progress: Double {
        if state == .finished { return 1.0 }
        guard totalBytes > 0 else { return 0 }
        return min(1.0, max(0.0, Double(receivedBytes) / Double(totalBytes)))
    }

    var detailText: String {
        let total = totalBytes > 0 ? bytesText(totalBytes) : "未知大小"
        switch state {
        case .probing:
            return "正在解析下载地址…"
        case .running:
            return "\(bytesText(receivedBytes)) / \(total) · \(speedText(speed)) · \(threadCount) 线程"
        case .paused:
            return "已暂停 · \(bytesText(receivedBytes)) / \(total) · \(threadCount) 线程"
        case .finished:
            return "已完成 · \(bytesText(receivedBytes))"
        case .failed:
            return errorMessage ?? "下载失败"
        case .cancelled:
            return "已取消"
        }
    }

    var actionTitle: String {
        switch state {
        case .probing, .running: return "暂停"
        case .paused: return "继续"
        case .finished: return "分享"
        case .failed, .cancelled: return "重试"
        }
    }

    fileprivate func recalculate() {
        var total: Int64 = 0
        for segment in segments {
            total += (baselineBytes[segment.index] ?? 0) + (progressBytes[segment.index] ?? 0)
        }
        receivedBytes = total

        let now = Date()
        let delta = now.timeIntervalSince(lastSpeedSample)
        if delta >= 0.5 {
            speed = Double(receivedBytes - lastSpeedBytes) / delta
            lastSpeedSample = now
            lastSpeedBytes = receivedBytes
        }
    }

    fileprivate func syncFromDisk() {
        var total: Int64 = 0
        for segment in segments {
            let size = fileSize(at: segment.fileURL)
            baselineBytes[segment.index] = size
            progressBytes[segment.index] = 0
            total += size
        }
        receivedBytes = total
        speed = 0
        lastSpeedBytes = total
        lastSpeedSample = Date()
    }

    fileprivate func invalidate() {
        session?.invalidateAndCancel()
        session = nil
        taskSegment.removeAll()
        runningSegments = 0
    }
}

// MARK: - 下载任务代理

extension DownloadJob: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard state == .running, let index = taskSegment[downloadTask.taskIdentifier] else { return }
        progressBytes[index] = totalBytesWritten
        recalculate()
        DownloadManager.shared.jobDidUpdate(self)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard state == .running,
              let index = taskSegment[downloadTask.taskIdentifier],
              let segment = segments.first(where: { $0.index == index }) else { return }
        let baseline = baselineBytes[index] ?? 0

        do {
            if baseline == 0 {
                try? FileManager.default.removeItem(at: segment.fileURL)
                try FileManager.default.moveItem(at: location, to: segment.fileURL)
            } else {
                let reader = try FileHandle(forReadingFrom: location)
                let writer = try FileHandle(forWritingTo: segment.fileURL)
                _ = try writer.seekToEnd()
                while let chunk = try reader.read(upToCount: 4 * 1024 * 1024), !chunk.isEmpty {
                    try writer.write(contentsOf: chunk)
                }
                try reader.close()
                try writer.close()
            }
            progressBytes[index] = max(0, fileSize(at: segment.fileURL) - baseline)
        } catch {
            fail("写入分段失败：\(error.localizedDescription)")
            return
        }

        taskSegment.removeValue(forKey: downloadTask.taskIdentifier)
        runningSegments = max(0, runningSegments - 1)
        recalculate()
        if runningSegments == 0 {
            DownloadManager.shared.jobDidFinishSegments(self)
        } else {
            DownloadManager.shared.jobDidUpdate(self)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error, state == .running else { return }
        fail(error.localizedDescription)
    }

    private func fail(_ message: String) {
        guard state == .running else { return }
        state = .failed
        errorMessage = message
        invalidate()
        DownloadManager.shared.jobDidUpdate(self)
    }
}

// MARK: - 下载管理器

final class DownloadManager {

    static let shared = DownloadManager()

    static let changedNotification = Notification.Name("SuperWebDownloadsChanged")

    private(set) var jobs: [DownloadJob] = []
    private var lastNotify = Date(timeIntervalSince1970: 0)

    private init() {}

    var activeCount: Int {
        return jobs.filter { $0.state.isActive }.count
    }

    // MARK: 对外操作

    func start(url: URL, referer: URL? = nil, suggestedName: String? = nil) {
        var name = suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.isEmpty {
            name = url.lastPathComponent
        }
        if name.isEmpty {
            name = "download"
        }
        let threads = min(64, max(1, Settings.shared.downloadThreads))
        let job = DownloadJob(url: url, referer: referer, fileName: name, threadCount: threads)
        jobs.insert(job, at: 0)
        notify(force: true)

        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self, weak job] cookies in
            guard let self = self, let job = job else { return }
            let host = job.url.host ?? ""
            let applicable = cookies.filter { cookie in
                guard !host.isEmpty else { return true }
                let domain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
                return host == domain || host.hasSuffix("." + domain)
            }
            job.cookieHeader = applicable.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            DispatchQueue.main.async {
                self.probe(job)
            }
        }
    }

    func pause(_ job: DownloadJob) {
        guard job.state.isActive else { return }
        job.state = .paused
        job.invalidate()
        job.syncFromDisk()
        notify(force: true)
    }

    func resume(_ job: DownloadJob) {
        guard job.state == .paused || job.state == .failed || job.state == .cancelled else { return }
        if job.state == .paused, !job.segments.isEmpty {
            job.state = .probing
            notify(force: true)
            startSegments(job, reset: false)
        } else {
            retry(job)
        }
    }

    func retry(_ job: DownloadJob) {
        job.threadCount = min(64, max(1, Settings.shared.downloadThreads))
        job.state = .probing
        job.invalidate()
        job.errorMessage = nil
        job.receivedBytes = 0
        job.baselineBytes = [:]
        job.progressBytes = [:]
        job.lastSpeedBytes = 0
        job.lastSpeedSample = Date()
        notify(force: true)
        probe(job)
    }

    func cancel(_ job: DownloadJob) {
        job.state = .cancelled
        job.invalidate()
        if let temp = job.tempDirectory {
            try? FileManager.default.removeItem(at: temp)
        }
        job.tempDirectory = nil
        notify(force: true)
    }

    func remove(_ job: DownloadJob) {
        if job.state.isActive {
            cancel(job)
        }
        jobs.removeAll { $0.id == job.id }
        notify(force: true)
    }

    // MARK: 代理回调

    func jobDidUpdate(_ job: DownloadJob) {
        notify()
    }

    func jobDidFinishSegments(_ job: DownloadJob) {
        finish(job)
    }

    // MARK: 探测

    private func probe(_ job: DownloadJob) {
        var request = URLRequest(url: job.url)
        request.timeoutInterval = 30
        request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        Self.applyHeaders(to: &request, job: job)

        let task = URLSession.shared.dataTask(with: request) { [weak self, weak job] _, response, error in
            DispatchQueue.main.async {
                guard let self = self, let job = job, job.state == .probing else { return }

                if let error = error {
                    job.state = .failed
                    job.errorMessage = error.localizedDescription
                    self.notify(force: true)
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    job.state = .failed
                    job.errorMessage = "服务器没有返回有效响应"
                    self.notify(force: true)
                    return
                }
                if http.statusCode >= 400 {
                    job.state = .failed
                    job.errorMessage = "HTTP \(http.statusCode)"
                    self.notify(force: true)
                    return
                }

                var total: Int64 = -1
                var supportsRange = false
                if http.statusCode == 206 {
                    supportsRange = true
                    if let contentRange = http.value(forHTTPHeaderField: "Content-Range"),
                       let slash = contentRange.lastIndex(of: "/") {
                        let tail = contentRange[contentRange.index(after: slash)...]
                            .trimmingCharacters(in: .whitespaces)
                        total = Int64(tail) ?? -1
                    }
                } else {
                    total = http.expectedContentLength
                }

                if let disposition = http.value(forHTTPHeaderField: "Content-Disposition"),
                   let name = Self.fileName(from: disposition) {
                    job.fileName = name
                }

                job.totalBytes = total
                if !supportsRange || total <= 0 {
                    job.threadCount = 1
                }
                job.errorMessage = nil
                self.startSegments(job, reset: true)
            }
        }
        task.resume()
    }

    // MARK: 分段下载

    private func startSegments(_ job: DownloadJob, reset: Bool) {
        let fileManager = FileManager.default
        let downloads = Self.downloadsDirectory()
        try? fileManager.createDirectory(at: downloads, withIntermediateDirectories: true)

        if reset || job.destinationURL == nil {
            let destination = Self.uniqueURL(in: downloads, fileName: job.fileName)
            job.destinationURL = destination
            job.fileName = destination.lastPathComponent
            if let old = job.tempDirectory {
                try? fileManager.removeItem(at: old)
            }
            let temp = fileManager.temporaryDirectory
                .appendingPathComponent("sw-dl-\(job.id.uuidString)", isDirectory: true)
            try? fileManager.createDirectory(at: temp, withIntermediateDirectories: true)
            job.tempDirectory = temp
            job.segments = []
            job.baselineBytes = [:]
            job.progressBytes = [:]
            job.receivedBytes = 0
            job.lastSpeedBytes = 0
            job.lastSpeedSample = Date()
        }

        guard let temp = job.tempDirectory else {
            job.state = .failed
            job.errorMessage = "无法创建临时目录"
            notify(force: true)
            return
        }

        if job.segments.isEmpty {
            if job.totalBytes > 0 {
                // 每段至少 1MB，避免小文件被切成几十个请求
                let usable = max(1, Int(job.totalBytes / (1024 * 1024)))
                job.threadCount = max(1, min(job.threadCount, usable))
            }
            job.segments = Self.makeSegments(total: job.totalBytes,
                                             count: job.threadCount,
                                             tempDirectory: temp)
        }

        job.invalidate()

        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 64
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 7200
        job.session = URLSession(configuration: configuration, delegate: job, delegateQueue: .main)

        job.runningSegments = 0
        job.state = .running

        for segment in job.segments {
            let baseline = fileSize(at: segment.fileURL)
            job.baselineBytes[segment.index] = baseline
            job.progressBytes[segment.index] = 0

            if job.totalBytes > 0 {
                let segmentLength = segment.upper - segment.lower + 1
                if baseline >= segmentLength { continue }
            }

            job.runningSegments += 1
            var request = URLRequest(url: job.url)
            request.timeoutInterval = 30
            if job.totalBytes > 0 {
                let from = segment.lower + baseline
                request.setValue("bytes=\(from)-\(segment.upper)", forHTTPHeaderField: "Range")
            }
            Self.applyHeaders(to: &request, job: job)

            if let task = job.session?.downloadTask(with: request) {
                job.taskSegment[task.taskIdentifier] = segment.index
                task.resume()
            } else {
                job.runningSegments -= 1
            }
        }

        job.recalculate()
        if job.runningSegments == 0 {
            finish(job)
        } else {
            notify(force: true)
        }
    }

    private func finish(_ job: DownloadJob) {
        guard job.state == .running else { return }
        guard let destination = job.destinationURL else {
            job.state = .failed
            job.errorMessage = "缺少保存路径"
            notify(force: true)
            return
        }

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            FileManager.default.createFile(atPath: destination.path, contents: nil)
            let writer = try FileHandle(forWritingTo: destination)
            for segment in job.segments {
                guard FileManager.default.fileExists(atPath: segment.fileURL.path) else { continue }
                let reader = try FileHandle(forReadingFrom: segment.fileURL)
                while let chunk = try reader.read(upToCount: 4 * 1024 * 1024), !chunk.isEmpty {
                    try writer.write(contentsOf: chunk)
                }
                try reader.close()
            }
            try writer.close()
        } catch {
            job.state = .failed
            job.errorMessage = "合并分段失败：\(error.localizedDescription)"
            job.invalidate()
            notify(force: true)
            return
        }

        if let temp = job.tempDirectory {
            try? FileManager.default.removeItem(at: temp)
        }
        job.tempDirectory = nil

        let size = fileSize(at: destination)
        job.totalBytes = size
        job.receivedBytes = size
        job.speed = 0
        job.state = .finished
        job.invalidate()
        notify(force: true)
    }

    // MARK: 辅助

    private func notify(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastNotify) > 0.2 else { return }
        lastNotify = now
        NotificationCenter.default.post(name: DownloadManager.changedNotification, object: nil)
    }

    private static func applyHeaders(to request: inout URLRequest, job: DownloadJob) {
        request.setValue(Settings.shared.userAgent.string, forHTTPHeaderField: "User-Agent")
        if !job.cookieHeader.isEmpty {
            request.setValue(job.cookieHeader, forHTTPHeaderField: "Cookie")
        }
        if let referer = job.referer {
            request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        }
    }

    private static func makeSegments(total: Int64, count: Int, tempDirectory: URL) -> [DownloadJob.Segment] {
        if total <= 0 {
            return [DownloadJob.Segment(index: 0,
                                        lower: 0,
                                        upper: Int64.max,
                                        fileURL: tempDirectory.appendingPathComponent("part-0"))]
        }
        var result: [DownloadJob.Segment] = []
        let base = total / Int64(count)
        let extra = total % Int64(count)
        for index in 0..<count {
            let lower = base * Int64(index) + min(Int64(index), extra)
            let size = base + (Int64(index) < extra ? 1 : 0)
            result.append(DownloadJob.Segment(index: index,
                                              lower: lower,
                                              upper: lower + size - 1,
                                              fileURL: tempDirectory.appendingPathComponent("part-\(index)")))
        }
        return result
    }

    static func downloadsDirectory() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Downloads", isDirectory: true)
    }

    static func uniqueURL(in directory: URL, fileName: String) -> URL {
        let safeName = fileName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        let base = (safeName as NSString).deletingPathExtension
        let ext = (safeName as NSString).pathExtension
        var candidate = directory.appendingPathComponent(safeName)
        var index = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base) (\(index))" : "\(base) (\(index)).\(ext)"
            candidate = directory.appendingPathComponent(name)
            index += 1
        }
        return candidate
    }

    private static func fileName(from disposition: String) -> String? {
        // filename*=UTF-8''xxx 优先
        if let range = disposition.range(of: "filename*=UTF-8''", options: .caseInsensitive) {
            let raw = String(disposition[range.upperBound...])
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'; "))
            return raw.removingPercentEncoding ?? raw
        }
        if let range = disposition.range(of: "filename=", options: .caseInsensitive) {
            let raw = String(disposition[range.upperBound...])
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"; "))
            return raw.isEmpty ? nil : raw
        }
        return nil
    }
}
