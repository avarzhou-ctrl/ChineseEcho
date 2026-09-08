import Foundation
import HuggingFace
import Observation

// Publishes one app-wide model preparation lifecycle for launch, features, and Settings.
@MainActor
@Observable
final class ModelDownloadCoordinator {
    enum Phase: Equatable {
        case idle
        case checking
        case downloading
        case loading
        case ready
        case cancelled
        case failed(String)
    }

    static let shared = ModelDownloadCoordinator()

    private(set) var phase: Phase = .idle
    private(set) var fractionCompleted = 0.0
    private(set) var completedByteCount: Int64 = 0
    private(set) var totalByteCount: Int64 = 0
    private(set) var estimatedSecondsRemaining: TimeInterval?
    private(set) var cachedByteCount: Int64 = 0
    private(set) var isStatusVisible = false

    @ObservationIgnored private var preparationTask: Task<Void, Error>?
    @ObservationIgnored private var progressMonitoringTask: Task<Void, Never>?
    @ObservationIgnored private var reportedCompletedByteCount: Int64 = 0
    @ObservationIgnored private var temporaryDownloadByteCount: Int64 = 0
    @ObservationIgnored private var temporaryObservationStartDate = Date.distantFuture
    @ObservationIgnored private var lastProgressDate: Date?
    @ObservationIgnored private var lastCompletedByteCount: Int64 = 0
    @ObservationIgnored private var smoothedBytesPerSecond: Double?
    @ObservationIgnored private var suppressesCachedPreparationStatus = false

    private init() {}

    var modelName: String { LocalModelSpec.displayName }

    var isPreparing: Bool {
        phase == .checking || phase == .downloading || phase == .loading
    }

    var canRetry: Bool {
        if case .failed = phase { return true }
        return phase == .cancelled || phase == .idle
    }

    var statusTitle: String {
        switch phase {
        case .idle:
            "Local AI is not downloaded"
        case .checking:
            "Checking Local AI files"
        case .downloading:
            "Downloading Local AI"
        case .loading:
            "Loading Local AI"
        case .ready:
            "\(modelName) is available"
        case .cancelled:
            "Local AI download paused"
        case .failed:
            "Local AI needs attention"
        }
    }

    var statusDetail: String {
        switch phase {
        case .idle:
            "Download \(modelName) to enable private on-device generation."
        case .checking:
            "Looking for an existing \(modelName) download…"
        case .downloading:
            downloadDetail
        case .loading:
            "Download complete · Preparing the model in memory…"
        case .ready:
            "\(modelName) is available for private on-device generation."
        case .cancelled:
            "Downloaded files were kept so you can resume later."
        case .failed(let message):
            message
        }
    }

    var percentageText: String {
        "\(Int((fractionCompleted * 100).rounded()))%"
    }

    var cachedSizeText: String {
        Self.byteFormatter.string(fromByteCount: cachedByteCount)
    }

    var predictedTimeText: String {
        guard let estimatedSecondsRemaining else {
            return "Estimating time remaining…"
        }
        let readyDate = Date().addingTimeInterval(estimatedSecondsRemaining)
        return "\(Self.durationText(estimatedSecondsRemaining)) remaining · Ready around \(Self.readyTimeFormatter.string(from: readyDate))"
    }

    func startPreparing() {
        guard phase != .ready, preparationTask == nil else { return }
        UserDefaults.standard.set(
            LocalAIDownloadChoice.download.rawValue,
            forKey: AppPreferenceKey.localAIDownloadChoice
        )
        Task {
            try? await prepare()
        }
    }

    func prepareInstalledModelIfAvailable() {
        guard phase != .ready, preparationTask == nil else { return }
        Task {
            let isFullyCached = await Task.detached(priority: .utility) {
                ModelCacheStore.hasCompleteSelectedModel()
            }.value
            guard isFullyCached else {
                await refreshCachedByteCount()
                return
            }
            try? await prepare()
        }
    }

    func prepare() async throws {
        if phase == .ready { return }
        if let preparationTask {
            try await preparationTask.value
            return
        }

        let isFullyCached = await Task.detached(priority: .utility) {
            ModelCacheStore.hasCompleteSelectedModel()
        }.value

        resetProgressSamples()
        suppressesCachedPreparationStatus = isFullyCached
        phase = .checking
        isStatusVisible = !isFullyCached

        await Task.detached(priority: .utility) {
            ModelCacheStore.removeAbandonedTemporaryDownloads()
        }.value
        let preparationStartedAt = Date()
        temporaryObservationStartDate = preparationStartedAt

        let task = Task {
            try await LocalLanguageModel.shared.prepare { progress in
                Task { @MainActor in
                    ModelDownloadCoordinator.shared.receive(progress)
                }
            }
        }
        preparationTask = task
        startTemporaryProgressMonitoring()

        do {
            try await task.value
            stopTemporaryProgressMonitoring()
            phase = .ready
            fractionCompleted = 1
            estimatedSecondsRemaining = nil
            preparationTask = nil
            await refreshCachedByteCount()
            if suppressesCachedPreparationStatus {
                isStatusVisible = false
            } else {
                scheduleReadyConfirmationDismissal()
            }
        } catch {
            stopTemporaryProgressMonitoring()
            preparationTask = nil
            estimatedSecondsRemaining = nil
            if task.isCancelled || error is CancellationError {
                phase = .cancelled
            } else {
                phase = .failed(error.localizedDescription)
            }
            isStatusVisible = true
            await refreshCachedByteCount()
            throw error
        }
    }

    func cancelPreparation() async {
        guard let preparationTask else { return }
        preparationTask.cancel()
        _ = await preparationTask.result
        stopTemporaryProgressMonitoring()
        self.preparationTask = nil
        estimatedSecondsRemaining = nil
        phase = .cancelled
        isStatusVisible = true
        UserDefaults.standard.set(
            LocalAIDownloadChoice.notNow.rawValue,
            forKey: AppPreferenceKey.localAIDownloadChoice
        )
        await refreshCachedByteCount()
    }

    func removeDownloadedModel() async throws {
        await cancelPreparation()
        await LocalLanguageModel.shared.unload()
        try await Task.detached(priority: .utility) {
            try ModelCacheStore.removeSelectedModel()
        }.value
        resetProgressSamples()
        cachedByteCount = 0
        phase = .idle
        isStatusVisible = false
        suppressesCachedPreparationStatus = false
        UserDefaults.standard.set(
            LocalAIDownloadChoice.notNow.rawValue,
            forKey: AppPreferenceKey.localAIDownloadChoice
        )
    }

    func refreshCachedByteCount() async {
        cachedByteCount = await Task.detached(priority: .utility) {
            ModelCacheStore.selectedModelByteCount()
        }.value
    }

    func showStatus() {
        isStatusVisible = true
    }

    func hideStatus() {
        guard !isPreparing else { return }
        isStatusVisible = false
    }

    private func receive(_ progress: Progress) {
        let total = max(progress.totalUnitCount, 0)
        let completed = max(progress.completedUnitCount, 0)
        totalByteCount = total
        if completed > reportedCompletedByteCount {
            // Ignore temporary files already represented by a newly finalized progress update.
            temporaryDownloadByteCount = 0
            temporaryObservationStartDate = Date()
        }
        reportedCompletedByteCount = min(completed, total > 0 ? total : completed)

        if total > 0 {
            updateDisplayedProgress()
        } else {
            phase = .checking
        }
        if !suppressesCachedPreparationStatus {
            isStatusVisible = true
        }
    }

    private func startTemporaryProgressMonitoring() {
        progressMonitoringTask?.cancel()
        progressMonitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let observationStartDate = temporaryObservationStartDate
                let byteCount = await Task.detached(priority: .utility) {
                    ModelCacheStore.temporaryDownloadByteCount(modifiedAfter: observationStartDate)
                }.value
                guard !Task.isCancelled else { return }
                temporaryDownloadByteCount = byteCount
                updateDisplayedProgress()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func stopTemporaryProgressMonitoring() {
        progressMonitoringTask?.cancel()
        progressMonitoringTask = nil
        temporaryDownloadByteCount = 0
    }

    private func updateDisplayedProgress() {
        guard totalByteCount > 0 else { return }
        let combinedByteCount = reportedCompletedByteCount + temporaryDownloadByteCount
        completedByteCount = min(max(combinedByteCount, 0), totalByteCount)
        fractionCompleted = min(max(Double(completedByteCount) / Double(totalByteCount), 0), 1)
        updateEstimatedTime(completedByteCount: completedByteCount)
        phase = reportedCompletedByteCount >= totalByteCount ? .loading : .downloading
        if !suppressesCachedPreparationStatus {
            isStatusVisible = true
        }
    }

    private func updateEstimatedTime(completedByteCount: Int64) {
        let now = Date()
        defer {
            lastProgressDate = now
            lastCompletedByteCount = completedByteCount
        }

        guard let lastProgressDate else { return }
        let elapsed = now.timeIntervalSince(lastProgressDate)
        let byteDelta = completedByteCount - lastCompletedByteCount
        guard elapsed >= 0.2, byteDelta > 0 else { return }

        let currentRate = Double(byteDelta) / elapsed
        if let smoothedBytesPerSecond {
            self.smoothedBytesPerSecond = (smoothedBytesPerSecond * 0.75) + (currentRate * 0.25)
        } else {
            smoothedBytesPerSecond = currentRate
        }

        guard let smoothedBytesPerSecond, smoothedBytesPerSecond > 0 else { return }
        estimatedSecondsRemaining = Double(max(totalByteCount - completedByteCount, 0))
            / smoothedBytesPerSecond
    }

    private var downloadDetail: String {
        guard totalByteCount > 0 else { return "Starting download…" }
        let completed = Self.byteFormatter.string(fromByteCount: completedByteCount)
        let total = Self.byteFormatter.string(fromByteCount: totalByteCount)
        return "\(completed) of \(total) · \(percentageText)"
    }

    private func resetProgressSamples() {
        fractionCompleted = 0
        completedByteCount = 0
        totalByteCount = 0
        reportedCompletedByteCount = 0
        temporaryDownloadByteCount = 0
        temporaryObservationStartDate = .distantFuture
        estimatedSecondsRemaining = nil
        lastProgressDate = nil
        lastCompletedByteCount = 0
        smoothedBytesPerSecond = nil
    }

    private func scheduleReadyConfirmationDismissal() {
        isStatusVisible = true
        Task {
            try? await Task.sleep(for: .seconds(3))
            if phase == .ready {
                isStatusVisible = false
            }
        }
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        return formatter
    }()

    private static let readyTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static func durationText(_ duration: TimeInterval) -> String {
        let seconds = max(Int(duration.rounded()), 0)
        if seconds < 60 { return "Less than 1 min" }
        let minutes = Int(ceil(Double(seconds) / 60))
        if minutes < 60 { return "About \(minutes) min" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 { return "About \(hours) hr" }
        return "About \(hours) hr \(remainingMinutes) min"
    }
}

// Resolves and manages only the selected model's Hugging Face cache directory.
nonisolated private enum ModelCacheStore {
    private static let temporaryDownloadPrefix = "CFNetworkDownload_"

    static var cacheRoot: URL {
        HuggingFace.HubCache.default.cacheDirectory
    }

    static var modelDirectory: URL {
        cacheRoot.appendingPathComponent(LocalModelSpec.cacheFolderName, isDirectory: true)
    }

    static var lockDirectory: URL {
        cacheRoot
            .appendingPathComponent(".locks", isDirectory: true)
            .appendingPathComponent(LocalModelSpec.cacheFolderName, isDirectory: true)
    }

    static func selectedModelByteCount() -> Int64 {
        let blobsDirectory = modelDirectory.appendingPathComponent("blobs", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: blobsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        return enumerator.reduce(into: Int64(0)) { total, item in
            guard let url = item as? URL,
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { return }
            total += Int64(values.fileSize ?? 0)
        }
    }

    static func hasCompleteSelectedModel() -> Bool {
        let snapshotsDirectory = modelDirectory.appendingPathComponent("snapshots", isDirectory: true)
        guard let snapshots = try? FileManager.default.contentsOfDirectory(
            at: snapshotsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        return snapshots.contains { snapshot in
            hasUsableFile(named: "config.json", in: snapshot)
                && hasUsableFile(named: "tokenizer.json", in: snapshot)
                && hasUsableModelWeights(in: snapshot)
        }
    }

    static func temporaryDownloadByteCount(modifiedAfter startDate: Date) -> Int64 {
        temporaryDownloads().reduce(into: Int64(0)) { total, item in
            guard let modifiedAt = item.modifiedAt,
                  modifiedAt >= startDate else { return }
            total += item.byteCount
        }
    }

    static func removeAbandonedTemporaryDownloads() {
        let staleBefore = Date().addingTimeInterval(-10 * 60)
        for item in temporaryDownloads() {
            guard let modifiedAt = item.modifiedAt, modifiedAt < staleBefore else { continue }
            try? FileManager.default.removeItem(at: item.url)
        }
    }

    static func removeSelectedModel() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: modelDirectory.path) {
            try fileManager.removeItem(at: modelDirectory)
        }
        if fileManager.fileExists(atPath: lockDirectory.path) {
            try fileManager.removeItem(at: lockDirectory)
        }
    }

    private static func hasUsableFile(named name: String, in directory: URL) -> Bool {
        let file = directory.appendingPathComponent(name)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
              let size = attributes[.size] as? NSNumber else {
            return false
        }
        return size.int64Value > 0
    }

    private static func hasUsableModelWeights(in directory: URL) -> Bool {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        return files.contains { file in
            file.pathExtension == "safetensors"
                && hasUsableFile(named: file.lastPathComponent, in: directory)
        }
    }

    private static func temporaryDownloads() -> [(url: URL, byteCount: Int64, modifiedAt: Date?)] {
        let keys: Set<URLResourceKey> = [
            .contentModificationDateKey,
            .fileSizeKey,
            .isRegularFileKey
        ]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: FileManager.default.temporaryDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files.compactMap { url in
            guard url.lastPathComponent.hasPrefix(temporaryDownloadPrefix),
                  url.pathExtension == "tmp",
                  let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { return nil }
            return (url, Int64(values.fileSize ?? 0), values.contentModificationDate)
        }
    }
}
