import Combine
import CryptoKit
import Foundation
import SWCompression

struct LocalVoiceModelDescriptor: Equatable, Sendable {
    static let recommended = LocalVoiceModelDescriptor(
        displayName: "Supertonic 3 INT8",
        revision: "2026-05-11",
        archiveName: "sherpa-onnx-supertonic-3-tts-int8-2026-05-11.tar.bz2",
        archiveByteCount: 128_774_318,
        archiveSHA256: "82fa96f91c4ef8abaae3a14a3f4153facf88bed821d1f7331cec2700f432c427"
    )

    let displayName: String
    let revision: String
    let archiveName: String
    let archiveByteCount: Int64
    let archiveSHA256: String

    var downloadURL: URL {
        URL(
            string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/\(archiveName)"
        )!
    }

    var formattedDownloadSize: String {
        ByteCountFormatter.string(fromByteCount: archiveByteCount, countStyle: .file)
    }
}

enum LocalVoiceModelStoreError: Error, Equatable {
    case insufficientStorage
    case network
    case invalidResponse
    case invalidArchive
    case fileSystem

    var localizationKey: String {
        switch self {
        case .insufficientStorage: return "settings.neural_voice.error.storage"
        case .network: return "settings.neural_voice.error.download"
        case .invalidResponse: return "settings.neural_voice.error.response"
        case .invalidArchive: return "settings.neural_voice.error.archive"
        case .fileSystem: return "settings.neural_voice.error.file_system"
        }
    }
}

enum LocalVoiceModelStorage {
    private static let folderName = "VoiceModels"
    private static let verifiedRevisionKey = "neural.voice.model.verifiedRevision"
    private static let verificationMarkerName = ".verified-revision"
    private static let resumeDataName = ".voice-model.resume"

    static let requiredFiles: [String: Int] = [
        "duration_predictor.int8.onnx": 3_700_147,
        "text_encoder.int8.onnx": 36_416_150,
        "vector_estimator.int8.onnx": 78_400_833,
        "vocoder.int8.onnx": 25_991_073,
        "tts.json": 8_253,
        "unicode_indexer.bin": 262_144,
        "voice.bin": 517_168
    ]

    static var modelDirectoryURL: URL {
        baseDirectoryURL.appendingPathComponent(
            LocalVoiceModelDescriptor.recommended.revision,
            isDirectory: true
        )
    }

    static var archiveStagingURL: URL {
        baseDirectoryURL.appendingPathComponent(
            ".\(LocalVoiceModelDescriptor.recommended.archiveName).download",
            isDirectory: false
        )
    }

    static var resumeDataURL: URL {
        baseDirectoryURL.appendingPathComponent(resumeDataName, isDirectory: false)
    }

    private static var installStagingURL: URL {
        baseDirectoryURL.appendingPathComponent(
            ".\(LocalVoiceModelDescriptor.recommended.revision).installing",
            isDirectory: true
        )
    }

    static var isInstalled: Bool {
        hasCompleteModelFiles(in: modelDirectoryURL)
    }

    static var hasStagedArchive: Bool {
        guard let values = try? archiveStagingURL.resourceValues(forKeys: [.fileSizeKey]) else {
            return false
        }
        return Int64(values.fileSize ?? 0)
            == LocalVoiceModelDescriptor.recommended.archiveByteCount
    }

    static var hasSavedResumeData: Bool {
        guard let values = try? resumeDataURL.resourceValues(forKeys: [.fileSizeKey]) else {
            return false
        }
        return (values.fileSize ?? 0) > 0
    }

    static var installedByteCount: Int64 {
        Int64(requiredFiles.values.reduce(0, +))
    }

    private static func hasCompleteModelFiles(in directory: URL) -> Bool {
        for (name, expectedSize) in requiredFiles {
            let url = directory.appendingPathComponent(name, isDirectory: false)
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true,
                  values.fileSize == expectedSize else {
                return false
            }
        }
        return true
    }

    static var isVerified: Bool {
        guard isInstalled else { return false }
        let markerURL = modelDirectoryURL.appendingPathComponent(
            verificationMarkerName,
            isDirectory: false
        )
        if let marker = try? String(contentsOf: markerURL, encoding: .utf8),
           marker.trimmingCharacters(in: .whitespacesAndNewlines)
            == LocalVoiceModelDescriptor.recommended.revision {
            return true
        }
        if UserDefaults.standard.string(forKey: verifiedRevisionKey)
            == LocalVoiceModelDescriptor.recommended.revision {
            // Migrate installations created before the marker lived inside the
            // atomic model directory. The write is tiny and happens only once.
            try? Data(LocalVoiceModelDescriptor.recommended.revision.utf8)
                .write(to: markerURL, options: [.atomic])
            return true
        }

        #if targetEnvironment(simulator)
        // Development builds often receive the official extracted model by
        // copying it directly into the Simulator container. There is no archive
        // installation step to write UserDefaults, although every whitelisted
        // file and exact byte count is present. Trust that complete development
        // fixture only in Simulator; physical devices still require the marker
        // written after SHA-256 archive verification.
        return true
        #else
        return false
        #endif
    }

    static func fileURL(_ name: String) -> URL {
        modelDirectoryURL.appendingPathComponent(name, isDirectory: false)
    }

    static func prepareDirectory() throws {
        do {
            try FileManager.default.createDirectory(
                at: baseDirectoryURL,
                withIntermediateDirectories: true
            )
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var directory = baseDirectoryURL
            try directory.setResourceValues(values)
        } catch {
            throw LocalVoiceModelStoreError.fileSystem
        }
    }

    static func ensureEnoughStorage() throws {
        try prepareDirectory()
        let values = try? baseDirectoryURL.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        // Keep headroom for the compressed archive, expanded TAR and installed model.
        let required: Int64 = 520_000_000
        if let available = values?.volumeAvailableCapacityForImportantUsage,
           available < required {
            throw LocalVoiceModelStoreError.insufficientStorage
        }
    }

    static func loadResumeData() -> Data? {
        try? Data(contentsOf: resumeDataURL)
    }

    static func saveResumeData(_ data: Data?) throws {
        guard let data, !data.isEmpty else {
            try removeIfPresent(resumeDataURL)
            return
        }
        try prepareDirectory()
        try data.write(to: resumeDataURL, options: [.atomic])
    }

    static func clearResumeData() {
        try? removeIfPresent(resumeDataURL)
    }

    static func cleanupStagingFilesAfterVerifiedInstallation() {
        guard isVerified else { return }
        try? removeIfPresent(archiveStagingURL)
        try? removeIfPresent(installStagingURL)
        try? removeIfPresent(resumeDataURL)
    }

    static func validateArchive(at url: URL) throws {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              Int64(values.fileSize ?? 0)
                == LocalVoiceModelDescriptor.recommended.archiveByteCount else {
            throw LocalVoiceModelStoreError.invalidArchive
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw LocalVoiceModelStoreError.fileSystem
        }
        defer { try? handle.close() }

        var digest = SHA256()
        while autoreleasepool(invoking: {
            guard let data = try? handle.read(upToCount: 4 * 1_024 * 1_024),
                  !data.isEmpty else {
                return false
            }
            digest.update(data: data)
            return true
        }) { }

        let hash = digest.finalize().map { String(format: "%02x", $0) }.joined()
        guard hash == LocalVoiceModelDescriptor.recommended.archiveSHA256 else {
            throw LocalVoiceModelStoreError.invalidArchive
        }
    }

    static func decompressVerifiedArchive(at archiveURL: URL) throws -> Data {
        do {
            let compressed = try Data(contentsOf: archiveURL, options: .mappedIfSafe)
            return try BZip2.decompress(data: compressed)
        } catch {
            throw LocalVoiceModelStoreError.invalidArchive
        }
    }

    static func installVerifiedTar(
        _ tarData: Data,
        archiveURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) throws {
        do {
            try prepareDirectory()
            try removeIfPresent(installStagingURL)
            try FileManager.default.createDirectory(
                at: installStagingURL,
                withIntermediateDirectories: true
            )

            let entries = try TarContainer.open(container: tarData)
            var installedNames = Set<String>()
            var installedBytes: Int64 = 0

            for entry in entries {
                let name = URL(fileURLWithPath: entry.info.name).lastPathComponent
                guard let expectedSize = requiredFiles[name] else { continue }
                guard let data = entry.data, data.count == expectedSize else {
                    throw LocalVoiceModelStoreError.invalidArchive
                }
                try data.write(
                    to: installStagingURL.appendingPathComponent(name, isDirectory: false),
                    // The whole directory is private staging and is moved into
                    // place only after every file validates. Avoiding a second
                    // per-file atomic copy materially reduces install time and
                    // disk writes for the 78 MB and 36 MB ONNX files.
                    options: []
                )
                installedNames.insert(name)
                installedBytes += Int64(expectedSize)
                progress(
                    min(max(Double(installedBytes) / Double(installedByteCount), 0), 1)
                )
            }

            guard installedNames == Set(requiredFiles.keys),
                  hasCompleteModelFiles(in: installStagingURL) else {
                throw LocalVoiceModelStoreError.invalidArchive
            }

            let markerURL = installStagingURL.appendingPathComponent(
                verificationMarkerName,
                isDirectory: false
            )
            try Data(LocalVoiceModelDescriptor.recommended.revision.utf8)
                .write(to: markerURL, options: [.atomic])

            try removeIfPresent(modelDirectoryURL)
            try FileManager.default.moveItem(
                at: installStagingURL,
                to: modelDirectoryURL
            )
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var modelDirectory = modelDirectoryURL
            try modelDirectory.setResourceValues(values)
            UserDefaults.standard.set(
                LocalVoiceModelDescriptor.recommended.revision,
                forKey: verifiedRevisionKey
            )
            guard isVerified else {
                throw LocalVoiceModelStoreError.invalidArchive
            }
            try removeIfPresent(archiveURL)
            clearResumeData()
        } catch let error as LocalVoiceModelStoreError {
            try? removeIfPresent(installStagingURL)
            throw error
        } catch {
            try? removeIfPresent(installStagingURL)
            throw LocalVoiceModelStoreError.invalidArchive
        }
    }

    static func removeModelAndStagingFiles() throws {
        do {
            try removeIfPresent(modelDirectoryURL)
            try removeIfPresent(archiveStagingURL)
            try removeIfPresent(installStagingURL)
            try removeIfPresent(resumeDataURL)
            UserDefaults.standard.removeObject(forKey: verifiedRevisionKey)
        } catch {
            throw LocalVoiceModelStoreError.fileSystem
        }
    }

    private static var baseDirectoryURL: URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return root.appendingPathComponent("Lippi", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
    }

    private static func removeIfPresent(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

@MainActor
final class LocalVoiceModelStore: ObservableObject {
    enum State: Equatable {
        case missing
        case downloading
        case retrying(attempt: Int, seconds: Int)
        case paused
        case verifying
        case decompressing
        case installing
        case ready
        case failed(LocalVoiceModelStoreError)
    }

    static let shared = LocalVoiceModelStore()

    @Published private(set) var state: State
    @Published private(set) var progress: Double = 0
    @Published private(set) var downloadedBytes: Int64 = 0
    @Published private(set) var totalDownloadBytes =
        LocalVoiceModelDescriptor.recommended.archiveByteCount
    @Published private(set) var downloadBytesPerSecond: Double = 0
    @Published private(set) var estimatedTimeRemaining: TimeInterval?
    @Published private(set) var phaseStartedAt = Date()
    /// A one-shot event emitted only after a freshly downloaded archive has
    /// passed verification and finished installation.
    @Published private(set) var installationReceipt: UUID?

    private var downloadTask: URLSessionDownloadTask?
    private var progressObservation: NSKeyValueObservation?
    private var resumeData: Data?
    private var isPausing = false
    private var retryTask: Task<Void, Never>?
    private var installationTask: Task<Void, Never>?
    private var automaticRetryCount = 0
    private var lastProgressBytes: Int64 = 0
    private var lastProgressDate = Date()

    private let retryDelays = [2, 5, 10, 20, 30]
    private lazy var downloadSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 60 * 60
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: configuration)
    }()

    private init() {
        resumeData = LocalVoiceModelStorage.loadResumeData()
        if LocalVoiceModelStorage.isVerified {
            state = .ready
            progress = 1
            downloadedBytes = totalDownloadBytes
            LocalVoiceModelStorage.cleanupStagingFilesAfterVerifiedInstallation()
        } else if LocalVoiceModelStorage.hasStagedArchive {
            state = .verifying
            progress = 0
        } else if resumeData != nil {
            state = .paused
            progress = 0
        } else {
            state = .missing
            progress = 0
        }
    }

    var isReady: Bool {
        state == .ready && LocalVoiceModelStorage.isVerified
    }

    func refresh() {
        guard downloadTask == nil, retryTask == nil, installationTask == nil else { return }
        if LocalVoiceModelStorage.isVerified {
            enter(.ready, progress: 1)
            downloadedBytes = totalDownloadBytes
            LocalVoiceModelStorage.cleanupStagingFilesAfterVerifiedInstallation()
        } else if LocalVoiceModelStorage.hasStagedArchive {
            beginVerificationAndInstallation(
                at: LocalVoiceModelStorage.archiveStagingURL
            )
        } else {
            resumeData = resumeData ?? LocalVoiceModelStorage.loadResumeData()
            enter(resumeData == nil ? .missing : .paused, progress: progress)
        }
    }

    func consumeInstallationReceipt(_ receipt: UUID) {
        guard installationReceipt == receipt else { return }
        installationReceipt = nil
    }

    /// Starts the one-time model download while the assistant keeps its
    /// textual response available. No legacy voice is substituted.
    func ensureDownloadStarted() {
        guard NeuralVoiceConfiguration.stored.isEnabled else { return }
        if LocalVoiceModelStorage.isVerified {
            enter(.ready, progress: 1)
            return
        }
        if LocalVoiceModelStorage.hasStagedArchive, installationTask == nil {
            beginVerificationAndInstallation(
                at: LocalVoiceModelStorage.archiveStagingURL
            )
            return
        }
        switch state {
        case .missing, .failed:
            startOrResumeDownload()
        case .paused, .downloading, .retrying, .verifying, .decompressing,
             .installing, .ready:
            break
        }
    }

    func startOrResumeDownload() {
        retryTask?.cancel()
        retryTask = nil
        automaticRetryCount = 0
        beginDownload()
    }

    private func beginDownload() {
        if LocalVoiceModelStorage.hasStagedArchive {
            beginVerificationAndInstallation(
                at: LocalVoiceModelStorage.archiveStagingURL
            )
            return
        }
        guard downloadTask == nil,
              installationTask == nil,
              state != .ready,
              state != .verifying,
              state != .decompressing,
              state != .installing else { return }

        do {
            try LocalVoiceModelStorage.ensureEnoughStorage()
        } catch let error as LocalVoiceModelStoreError {
            state = .failed(error)
            return
        } catch {
            state = .failed(.fileSystem)
            return
        }

        isPausing = false
        let task: URLSessionDownloadTask
        resumeData = resumeData ?? LocalVoiceModelStorage.loadResumeData()
        if let resumeData, !resumeData.isEmpty {
            task = downloadSession.downloadTask(
                withResumeData: resumeData,
                completionHandler: downloadCompletion
            )
        } else {
            var request = URLRequest(
                url: LocalVoiceModelDescriptor.recommended.downloadURL
            )
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 60 * 30
            task = downloadSession.downloadTask(
                with: request,
                completionHandler: downloadCompletion
            )
        }

        downloadTask = task
        progressObservation = task.progress.observe(
            \.fractionCompleted,
            options: [.initial, .new]
        ) { [weak self] progress, _ in
            let fraction = min(max(progress.fractionCompleted, 0), 1)
            let completed = max(progress.completedUnitCount, 0)
            let total = progress.totalUnitCount
            Task { @MainActor [weak self] in
                self?.updateDownloadProgress(
                    fraction: fraction,
                    completedBytes: completed,
                    totalBytes: total
                )
            }
        }
        lastProgressBytes = downloadedBytes
        lastProgressDate = Date()
        phaseStartedAt = Date()
        state = .downloading
        task.resume()
    }

    func pauseDownload() {
        retryTask?.cancel()
        retryTask = nil
        guard let downloadTask else {
            if case .retrying = state {
                enter(.paused, progress: progress)
            }
            return
        }
        isPausing = true
        downloadTask.cancel { [weak self] data in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let data, !data.isEmpty {
                    self.resumeData = data
                    try? LocalVoiceModelStorage.saveResumeData(data)
                }
                self.finishActiveTask()
                self.enter(.paused, progress: self.progress)
            }
        }
    }

    func cancelDownload() {
        isPausing = true
        retryTask?.cancel()
        retryTask = nil
        downloadTask?.cancel()
        finishActiveTask()
        resumeData = nil
        LocalVoiceModelStorage.clearResumeData()
        automaticRetryCount = 0
        progress = 0
        downloadedBytes = 0
        downloadBytesPerSecond = 0
        estimatedTimeRemaining = nil
        state = LocalVoiceModelStorage.isVerified ? .ready : .missing
    }

    func deleteModel() {
        cancelDownload()
        LocalNeuralVoiceProvider.shared.unload()
        do {
            try LocalVoiceModelStorage.removeModelAndStagingFiles()
            state = .missing
        } catch let error as LocalVoiceModelStoreError {
            state = .failed(error)
        } catch {
            state = .failed(.fileSystem)
        }
    }

    private lazy var downloadCompletion: @Sendable (URL?, URLResponse?, Error?) -> Void = {
        [weak self] temporaryURL, response, error in
        let urlError = error as NSError?
        // URLSession reports unusable resume data with the long-standing
        // NSURLErrorDomain code -3003, which is not surfaced by URLError.Code.
        let cannotResume = urlError?.domain == NSURLErrorDomain
            && urlError?.code == -3003
        let recoveredResumeData = (error as NSError?)?
            .userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        let stagedResult: Result<URL, LocalVoiceModelStoreError>
        if error != nil {
            stagedResult = .failure(.network)
        } else if let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let temporaryURL {
            do {
                try LocalVoiceModelStorage.prepareDirectory()
                if FileManager.default.fileExists(
                    atPath: LocalVoiceModelStorage.archiveStagingURL.path
                ) {
                    try FileManager.default.removeItem(
                        at: LocalVoiceModelStorage.archiveStagingURL
                    )
                }
                try FileManager.default.moveItem(
                    at: temporaryURL,
                    to: LocalVoiceModelStorage.archiveStagingURL
                )
                stagedResult = .success(LocalVoiceModelStorage.archiveStagingURL)
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
            if cannotResume {
                self.resumeData = nil
                LocalVoiceModelStorage.clearResumeData()
            } else if let recoveredResumeData, !recoveredResumeData.isEmpty {
                self.resumeData = recoveredResumeData
                try? LocalVoiceModelStorage.saveResumeData(recoveredResumeData)
            }

            switch stagedResult {
            case .failure(let error):
                if error == .network {
                    self.scheduleAutomaticRetry()
                } else {
                    self.enter(.failed(error), progress: self.progress)
                }

            case .success(let stagingURL):
                self.resumeData = nil
                self.automaticRetryCount = 0
                self.beginVerificationAndInstallation(at: stagingURL)
            }
        }
    }

    private func scheduleAutomaticRetry() {
        guard automaticRetryCount < retryDelays.count else {
            enter(.failed(.network), progress: progress)
            return
        }

        let delay = retryDelays[automaticRetryCount]
        automaticRetryCount += 1
        let attempt = automaticRetryCount
        retryTask?.cancel()
        phaseStartedAt = Date()

        retryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for remaining in stride(from: delay, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                self.state = .retrying(attempt: attempt, seconds: remaining)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            guard !Task.isCancelled else { return }
            self.retryTask = nil
            self.beginDownload()
        }
    }

    private func beginVerificationAndInstallation(at stagingURL: URL) {
        guard installationTask == nil else { return }
        retryTask?.cancel()
        retryTask = nil
        enter(.verifying, progress: 0)

        installationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.detached(priority: .utility) {
                    try LocalVoiceModelStorage.validateArchive(at: stagingURL)
                }.value
                guard !Task.isCancelled else { return }

                self.enter(.decompressing, progress: 0)
                let tarData = try await Task.detached(priority: .utility) {
                    try LocalVoiceModelStorage.decompressVerifiedArchive(at: stagingURL)
                }.value
                guard !Task.isCancelled else { return }

                self.enter(.installing, progress: 0)
                try await Task.detached(priority: .utility) {
                    try LocalVoiceModelStorage.installVerifiedTar(
                        tarData,
                        archiveURL: stagingURL
                    ) { value in
                        Task { @MainActor [weak self] in
                            guard let self, self.state == .installing else { return }
                            self.progress = value
                        }
                    }
                }.value

                guard LocalVoiceModelStorage.isVerified else {
                    throw LocalVoiceModelStoreError.invalidArchive
                }
                self.resumeData = nil
                self.downloadedBytes = self.totalDownloadBytes
                self.downloadBytesPerSecond = 0
                self.estimatedTimeRemaining = nil
                self.enter(.ready, progress: 1)
                self.installationReceipt = UUID()
            } catch let error as LocalVoiceModelStoreError {
                try? LocalVoiceModelStorage.removeModelAndStagingFiles()
                self.enter(.failed(error), progress: 0)
            } catch {
                try? LocalVoiceModelStorage.removeModelAndStagingFiles()
                self.enter(.failed(.invalidArchive), progress: 0)
            }
            self.installationTask = nil
        }
    }

    private func updateDownloadProgress(
        fraction: Double,
        completedBytes: Int64,
        totalBytes: Int64
    ) {
        progress = fraction
        downloadedBytes = completedBytes
        if totalBytes > 0 {
            totalDownloadBytes = totalBytes
        }

        let now = Date()
        let interval = now.timeIntervalSince(lastProgressDate)
        guard interval >= 0.65 else { return }
        let byteDelta = max(completedBytes - lastProgressBytes, 0)
        let instantaneousSpeed = Double(byteDelta) / interval
        if instantaneousSpeed > 0 {
            downloadBytesPerSecond = downloadBytesPerSecond == 0
                ? instantaneousSpeed
                : (downloadBytesPerSecond * 0.68) + (instantaneousSpeed * 0.32)
        }
        if downloadBytesPerSecond > 0 {
            estimatedTimeRemaining = Double(
                max(totalDownloadBytes - completedBytes, 0)
            ) / downloadBytesPerSecond
        }
        lastProgressBytes = completedBytes
        lastProgressDate = now
    }

    private func enter(_ newState: State, progress newProgress: Double) {
        state = newState
        progress = newProgress
        phaseStartedAt = Date()
    }

    private func finishActiveTask() {
        progressObservation?.invalidate()
        progressObservation = nil
        downloadTask = nil
    }
}
