import Combine
import CryptoKit
import Foundation

struct BonsaiModelDescriptor: Equatable, Sendable {
    static let recommended = BonsaiModelDescriptor(
        displayName: "Bonsai 4B 1-bit",
        repository: "prism-ml/Bonsai-4B-gguf",
        revision: "78f2c2bacd0904ffaba24b4873ed975e5818354a",
        fileName: "Bonsai-4B-Q1_0.gguf",
        byteCount: 572_270_624,
        sha256: "4524b3f997f0f06444e568d1f26e2efd69effa3218c7ad3047432fb171e42168"
    )

    let displayName: String
    let repository: String
    let revision: String
    let fileName: String
    let byteCount: Int64
    let sha256: String

    var downloadURL: URL {
        URL(string: "https://huggingface.co/\(repository)/resolve/\(revision)/\(fileName)")!
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

struct BonsaiConfiguration: Equatable, Sendable {
    static let enabledKey = "bonsai.provider.enabled"
    static let migrationKey = "bonsai.provider.migratedFromOllama"
    private static let legacyOllamaEnabledKey = "ollama.provider.enabled"

    var isEnabled: Bool

    static var stored: BonsaiConfiguration {
        let defaults = UserDefaults.standard

        if !defaults.bool(forKey: migrationKey) {
            // Bonsai replaces the old Mac provider. It is enabled by default,
            // while downloading the sizeable model always remains an explicit action.
            defaults.set(true, forKey: enabledKey)
            defaults.set(false, forKey: legacyOllamaEnabledKey)
            defaults.set(true, forKey: migrationKey)
        }

        if defaults.object(forKey: enabledKey) == nil {
            defaults.set(true, forKey: enabledKey)
        }
        return BonsaiConfiguration(isEnabled: defaults.bool(forKey: enabledKey))
    }
}

enum BonsaiModelStoreError: Error, Equatable {
    case insufficientStorage
    case network
    case invalidResponse
    case invalidFile
    case fileSystem

    var localizationKey: String {
        switch self {
        case .insufficientStorage: return "bonsai.error.storage"
        case .network: return "bonsai.error.download"
        case .invalidResponse: return "bonsai.error.download_response"
        case .invalidFile: return "bonsai.error.invalid_model"
        case .fileSystem: return "bonsai.error.file_system"
        }
    }
}

enum BonsaiModelStorage {
    private static let folderName = "BonsaiModels"
    private static let verifiedRevisionKey = "bonsai.model.verifiedRevision"

    static var modelURL: URL {
        baseDirectoryURL.appendingPathComponent(BonsaiModelDescriptor.recommended.fileName, isDirectory: false)
    }

    static var stagingURL: URL {
        baseDirectoryURL.appendingPathComponent(".\(BonsaiModelDescriptor.recommended.fileName).download", isDirectory: false)
    }

    static var isInstalled: Bool {
        guard let values = try? modelURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true,
              Int64(values.fileSize ?? 0) == BonsaiModelDescriptor.recommended.byteCount,
              hasGGUFHeader(at: modelURL) else {
            return false
        }
        return true
    }

    static var isVerified: Bool {
        isInstalled
            && UserDefaults.standard.string(forKey: verifiedRevisionKey) == BonsaiModelDescriptor.recommended.revision
    }

    static func prepareDirectory() throws {
        do {
            try FileManager.default.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var directory = baseDirectoryURL
            try directory.setResourceValues(values)
        } catch {
            throw BonsaiModelStoreError.fileSystem
        }
    }

    static func ensureEnoughStorage() throws {
        try prepareDirectory()
        let values = try? baseDirectoryURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let required = BonsaiModelDescriptor.recommended.byteCount + 300_000_000
        if let available = values?.volumeAvailableCapacityForImportantUsage, available < required {
            throw BonsaiModelStoreError.insufficientStorage
        }
    }

    static func validateDownloadedFile(at url: URL) throws {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              Int64(values.fileSize ?? 0) == BonsaiModelDescriptor.recommended.byteCount,
              hasGGUFHeader(at: url) else {
            throw BonsaiModelStoreError.invalidFile
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw BonsaiModelStoreError.fileSystem
        }
        defer { try? handle.close() }

        var digest = SHA256()
        do {
            while autoreleasepool(invoking: {
                guard let data = try? handle.read(upToCount: 4 * 1_024 * 1_024), !data.isEmpty else {
                    return false
                }
                digest.update(data: data)
                return true
            }) { }
        }

        let hash = digest.finalize().map { String(format: "%02x", $0) }.joined()
        guard hash == BonsaiModelDescriptor.recommended.sha256 else {
            throw BonsaiModelStoreError.invalidFile
        }
    }

    static func installVerifiedFile(from stagingURL: URL) throws {
        do {
            try prepareDirectory()
            if FileManager.default.fileExists(atPath: modelURL.path) {
                try FileManager.default.removeItem(at: modelURL)
            }
            try FileManager.default.moveItem(at: stagingURL, to: modelURL)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var model = modelURL
            try model.setResourceValues(values)
            UserDefaults.standard.set(BonsaiModelDescriptor.recommended.revision, forKey: verifiedRevisionKey)
        } catch let error as BonsaiModelStoreError {
            throw error
        } catch {
            throw BonsaiModelStoreError.fileSystem
        }
    }

    static func removeModelAndStagingFiles() throws {
        do {
            if FileManager.default.fileExists(atPath: modelURL.path) {
                try FileManager.default.removeItem(at: modelURL)
            }
            if FileManager.default.fileExists(atPath: stagingURL.path) {
                try FileManager.default.removeItem(at: stagingURL)
            }
            UserDefaults.standard.removeObject(forKey: verifiedRevisionKey)
        } catch {
            throw BonsaiModelStoreError.fileSystem
        }
    }

    private static var baseDirectoryURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root.appendingPathComponent("Lippi", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
    }

    private static func hasGGUFHeader(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4) else { return false }
        return data == Data([0x47, 0x47, 0x55, 0x46])
    }
}

@MainActor
final class BonsaiModelStore: ObservableObject {
    enum State: Equatable {
        case missing
        case downloading
        case paused
        case verifying
        case ready
        case failed(BonsaiModelStoreError)
    }

    static let shared = BonsaiModelStore()

    @Published private(set) var state: State
    @Published private(set) var progress: Double = 0

    private var downloadTask: URLSessionDownloadTask?
    private var progressObservation: NSKeyValueObservation?
    private var resumeData: Data?
    private var isPausing = false

    private init() {
        state = BonsaiModelStorage.isInstalled ? .ready : .missing
    }

    var isReady: Bool { state == .ready && BonsaiModelStorage.isInstalled }

    func refresh() {
        guard downloadTask == nil else { return }
        state = BonsaiModelStorage.isInstalled ? .ready : .missing
        if state == .ready { progress = 1 }
    }

    func startOrResumeDownload() {
        guard downloadTask == nil, state != .ready, state != .verifying else { return }

        do {
            try BonsaiModelStorage.ensureEnoughStorage()
        } catch let error as BonsaiModelStoreError {
            state = .failed(error)
            return
        } catch {
            state = .failed(.fileSystem)
            return
        }

        isPausing = false
        let task: URLSessionDownloadTask
        if let resumeData {
            task = URLSession.shared.downloadTask(withResumeData: resumeData, completionHandler: downloadCompletion)
            self.resumeData = nil
        } else {
            var request = URLRequest(url: BonsaiModelDescriptor.recommended.downloadURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 60 * 30
            task = URLSession.shared.downloadTask(with: request, completionHandler: downloadCompletion)
        }

        downloadTask = task
        progressObservation = task.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] progress, _ in
            Task { @MainActor [weak self] in
                self?.progress = min(max(progress.fractionCompleted, 0), 1)
            }
        }
        state = .downloading
        task.resume()
    }

    func pauseDownload() {
        guard let downloadTask else { return }
        isPausing = true
        downloadTask.cancel { [weak self] data in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.resumeData = data
                self.finishActiveTask()
                self.state = .paused
            }
        }
    }

    func cancelDownload() {
        isPausing = true
        downloadTask?.cancel()
        finishActiveTask()
        resumeData = nil
        progress = 0
        state = BonsaiModelStorage.isInstalled ? .ready : .missing
    }

    func deleteModel() {
        cancelDownload()
        Task { await BonsaiInferenceEngine.shared.unload() }
        do {
            try BonsaiModelStorage.removeModelAndStagingFiles()
            state = .missing
        } catch let error as BonsaiModelStoreError {
            state = .failed(error)
        } catch {
            state = .failed(.fileSystem)
        }
    }

    private lazy var downloadCompletion: @Sendable (URL?, URLResponse?, Error?) -> Void = { [weak self] temporaryURL, response, error in
        // A URLSession download URL is valid only until this callback returns.
        // Take ownership synchronously before hopping to the main actor.
        let stagedResult: Result<URL, BonsaiModelStoreError>
        if error != nil {
            stagedResult = .failure(.network)
        } else if let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let temporaryURL {
            do {
                try BonsaiModelStorage.prepareDirectory()
                if FileManager.default.fileExists(atPath: BonsaiModelStorage.stagingURL.path) {
                    try FileManager.default.removeItem(at: BonsaiModelStorage.stagingURL)
                }
                try FileManager.default.moveItem(at: temporaryURL, to: BonsaiModelStorage.stagingURL)
                stagedResult = .success(BonsaiModelStorage.stagingURL)
            } catch {
                stagedResult = .failure(.fileSystem)
            }
        } else {
            stagedResult = .failure(.invalidResponse)
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard !self.isPausing else {
                if case .success(let stagingURL) = stagedResult {
                    try? FileManager.default.removeItem(at: stagingURL)
                }
                return
            }
            self.finishActiveTask()

            switch stagedResult {
            case .failure(let error):
                self.state = .failed(error)

            case .success(let stagingURL):
                self.state = .verifying
                Task.detached(priority: .utility) {
                    do {
                        try BonsaiModelStorage.validateDownloadedFile(at: stagingURL)
                        try BonsaiModelStorage.installVerifiedFile(from: stagingURL)
                        await MainActor.run {
                            self.progress = 1
                            self.state = .ready
                        }
                    } catch let error as BonsaiModelStoreError {
                        try? BonsaiModelStorage.removeModelAndStagingFiles()
                        await MainActor.run { self.state = .failed(error) }
                    } catch {
                        try? BonsaiModelStorage.removeModelAndStagingFiles()
                        await MainActor.run { self.state = .failed(.invalidFile) }
                    }
                }
            }
        }
    }

    private func finishActiveTask() {
        progressObservation?.invalidate()
        progressObservation = nil
        downloadTask = nil
    }
}
