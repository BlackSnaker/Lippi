import SwiftUI

#if os(iOS)
import AVFoundation
import CoreImage
import ImageIO
import UIKit
import Vision

private enum EyeCameraAccessState: Equatable {
    case idle
    case requesting
    case authorized
    case denied
    case unavailable
    case failed
}

private struct EyeCameraSnapshot: Equatable {
    var hasFace = false
    var hasEyes = false
    var isFaceAligned = false
    var hasUsableLight = false
    var gazePoint = CGPoint(x: 0.5, y: 0.5)
    var eyeOpenness = 1.0
    var blinkCount = 0
    var fatigueScore = 0.0
    var rednessScore: Double?
    var lightLevel = 0.5

    var isReadyForExercise: Bool {
        hasFace && hasEyes && isFaceAligned && hasUsableLight
    }
}

/// Runs a deliberately lightweight, on-device Vision pipeline. Camera frames
/// are never persisted or exposed outside this object.
private final class EyeCameraAnalyzer: NSObject, ObservableObject {
    @Published private(set) var accessState: EyeCameraAccessState = .idle
    @Published private(set) var snapshot = EyeCameraSnapshot()
    @Published private(set) var isRunning = false

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "Lippi.EyeComfort.Camera", qos: .userInitiated)
    // The exercise does not need display-rate inference. A utility queue and
    // throttled frames keep the Vision work responsive without monopolizing
    // the performance cores during a break.
    private let analysisQueue = DispatchQueue(label: "Lippi.EyeComfort.Vision", qos: .utility)
    private let ciContext = CIContext(options: [
        .cacheIntermediates: false,
        .priorityRequestLow: true
    ])

    private var isConfigured = false
    private var lastAnalysisTime = 0.0
    private var analysisFrame = 0
    private var baselineOpenness: Double?
    private var baselineRedness: Double?
    private var smoothedFatigue = 0.0
    private var smoothedRedness: Double?
    private var eyesWereClosed = false
    private var eyeClosureStartedAt: CFTimeInterval?
    private var detectedBlinks = 0
    private var longClosures = 0

    func requestAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            accessState = .authorized
            configureAndStart()
        case .notDetermined:
            accessState = .requesting
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.accessState = granted ? .authorized : .denied
                    if granted { self.configureAndStart() }
                }
            }
        case .denied, .restricted:
            accessState = .denied
        @unknown default:
            accessState = .failed
        }
    }

    func resumeIfPossible() {
        guard accessState == .authorized else { return }
        configureAndStart()
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isConfigured {
                guard self.configureSession() else { return }
                self.isConfigured = true
            }

            guard !self.session.isRunning else {
                DispatchQueue.main.async { self.isRunning = true }
                return
            }

            self.resetSessionMetrics()
            self.session.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    private func configureSession() -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        defer { session.commitConfiguration() }

        // Vision only needs the RGB feed here. Prefer the regular front camera
        // so the depth system is not engaged for a short comfort exercise.
        let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)

        guard let camera,
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            publishAccess(.unavailable)
            return false
        }

        do {
            try camera.lockForConfiguration()
            let desired = CMTime(value: 1, timescale: 15)
            if camera.activeFormat.videoSupportedFrameRateRanges.contains(where: {
                $0.minFrameRate <= 15 && $0.maxFrameRate >= 15
            }) {
                camera.activeVideoMinFrameDuration = desired
                camera.activeVideoMaxFrameDuration = desired
            }
            camera.unlockForConfiguration()
        } catch {
            // The system-selected frame rate is still safe to use.
        }

        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.setSampleBufferDelegate(self, queue: analysisQueue)

        guard session.canAddOutput(output) else {
            publishAccess(.failed)
            return false
        }

        session.addOutput(output)
        return true
    }

    private func resetSessionMetrics() {
        analysisQueue.async { [weak self] in
            guard let self else { return }
            self.lastAnalysisTime = 0
            self.analysisFrame = 0
            self.baselineOpenness = nil
            self.baselineRedness = nil
            self.smoothedFatigue = 0
            self.smoothedRedness = nil
            self.eyesWereClosed = false
            self.eyeClosureStartedAt = nil
            self.detectedBlinks = 0
            self.longClosures = 0
        }
    }

    private func publishAccess(_ state: EyeCameraAccessState) {
        DispatchQueue.main.async { [weak self] in
            self?.accessState = state
            self?.isRunning = false
        }
    }

    private func publish(_ snapshot: EyeCameraSnapshot) {
        DispatchQueue.main.async { [weak self] in self?.snapshot = snapshot }
    }
}

extension EyeCameraAnalyzer: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastAnalysisTime >= 0.115,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        lastAnalysisTime = now
        analysisFrame += 1

        let lightLevel = averageLuma(in: pixelBuffer)
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .leftMirrored,
            options: [:]
        )

        do {
            try handler.perform([request])
            guard let face = request.results?.max(by: {
                $0.boundingBox.width < $1.boundingBox.width
            }) else {
                publish(EyeCameraSnapshot(lightLevel: lightLevel))
                return
            }
            analyze(face: face, pixelBuffer: pixelBuffer, lightLevel: lightLevel, now: now)
        } catch {
            publish(EyeCameraSnapshot(lightLevel: lightLevel))
        }
    }

    private func analyze(
        face: VNFaceObservation,
        pixelBuffer: CVPixelBuffer,
        lightLevel: Double,
        now: CFTimeInterval
    ) {
        let box = face.boundingBox
        let yaw = abs(face.yaw?.doubleValue ?? 0)
        let roll = abs(face.roll?.doubleValue ?? 0)
        let isAligned = abs(box.midX - 0.5) < 0.18
            && abs(box.midY - 0.52) < 0.24
            && box.width > 0.28
            && box.width < 0.82
            && yaw < 0.35
            && roll < 0.30
        let usableLight = lightLevel > 0.19 && lightLevel < 0.88

        guard let landmarks = face.landmarks,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else {
            publish(
                EyeCameraSnapshot(
                    hasFace: true,
                    hasEyes: false,
                    isFaceAligned: isAligned,
                    hasUsableLight: usableLight,
                    lightLevel: lightLevel
                )
            )
            return
        }

        let leftRatio = opennessRatio(for: leftEye)
        let rightRatio = opennessRatio(for: rightEye)
        let rawOpenness = max((leftRatio + rightRatio) / 2, 0.001)

        if let baselineOpenness {
            self.baselineOpenness = max(rawOpenness, baselineOpenness * 0.998)
        } else if rawOpenness > 0.08 {
            baselineOpenness = rawOpenness
        }

        let relativeOpenness = min(max(rawOpenness / max(baselineOpenness ?? rawOpenness, 0.001), 0), 1.2)
        updateBlinkState(relativeOpenness: relativeOpenness, now: now)

        let asymmetry = abs(leftRatio - rightRatio) / max(leftRatio + rightRatio, 0.001)
        let longClosureContribution = min(Double(longClosures) * 0.12, 0.36)
        let opennessContribution = min(max((0.84 - relativeOpenness) / 0.42, 0), 1) * 0.58
        let asymmetryContribution = min(asymmetry * 1.8, 1) * 0.12
        let fatigueEvidence = min(opennessContribution + longClosureContribution + asymmetryContribution, 1)
        smoothedFatigue = smoothedFatigue * 0.88 + fatigueEvidence * 0.12

        let gaze = gazePoint(
            leftEye: leftEye,
            leftPupil: landmarks.leftPupil,
            rightEye: rightEye,
            rightPupil: landmarks.rightPupil
        )

        if analysisFrame.isMultiple(of: 12), usableLight, relativeOpenness > 0.58,
           let sampled = rednessEstimate(
               pixelBuffer: pixelBuffer,
               face: face,
               leftEye: leftEye,
               rightEye: rightEye
           ) {
            if let baselineRedness {
                self.baselineRedness = min(baselineRedness * 1.002, sampled)
            } else {
                baselineRedness = sampled
            }

            let absolute = min(max((sampled - 0.075) / 0.24, 0), 1)
            let relative = min(max((sampled - (baselineRedness ?? sampled) - 0.012) / 0.11, 0), 1)
            let score = max(absolute * 0.72, relative)
            smoothedRedness = (smoothedRedness ?? score) * 0.76 + score * 0.24
        }

        publish(
            EyeCameraSnapshot(
                hasFace: true,
                hasEyes: true,
                isFaceAligned: isAligned,
                hasUsableLight: usableLight,
                gazePoint: gaze,
                eyeOpenness: relativeOpenness,
                blinkCount: detectedBlinks,
                fatigueScore: min(max(smoothedFatigue, 0), 1),
                rednessScore: smoothedRedness,
                lightLevel: lightLevel
            )
        )
    }

    private func updateBlinkState(relativeOpenness: Double, now: CFTimeInterval) {
        if relativeOpenness < 0.53 {
            if !eyesWereClosed {
                eyesWereClosed = true
                eyeClosureStartedAt = now
            }
            return
        }

        guard eyesWereClosed, relativeOpenness > 0.68 else { return }
        eyesWereClosed = false
        let duration = now - (eyeClosureStartedAt ?? now)
        eyeClosureStartedAt = nil

        if duration >= 0.07 && duration <= 1.35 {
            detectedBlinks += 1
            if duration > 0.62 { longClosures += 1 }
        }
    }

    private func opennessRatio(for eye: VNFaceLandmarkRegion2D) -> Double {
        let points = eye.normalizedPoints
        guard points.count >= 4 else { return 0 }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let width = max((xs.max() ?? 0) - (xs.min() ?? 0), 0.001)
        let height = max((ys.max() ?? 0) - (ys.min() ?? 0), 0)
        return Double(height / width)
    }

    private func gazePoint(
        leftEye: VNFaceLandmarkRegion2D,
        leftPupil: VNFaceLandmarkRegion2D?,
        rightEye: VNFaceLandmarkRegion2D,
        rightPupil: VNFaceLandmarkRegion2D?
    ) -> CGPoint {
        let estimates = [
            pupilOffset(eye: leftEye, pupil: leftPupil),
            pupilOffset(eye: rightEye, pupil: rightPupil)
        ].compactMap { $0 }

        guard !estimates.isEmpty else { return CGPoint(x: 0.5, y: 0.5) }
        let x = estimates.map(\.x).reduce(0, +) / CGFloat(estimates.count)
        let y = estimates.map(\.y).reduce(0, +) / CGFloat(estimates.count)
        let horizontal = min(max(0.5 + x * 2.6, 0.04), 0.96)
        let visionVertical = min(max(0.5 + y * 2.9, 0.04), 0.96)
        return CGPoint(x: horizontal, y: 1 - visionVertical)
    }

    private func pupilOffset(
        eye: VNFaceLandmarkRegion2D,
        pupil: VNFaceLandmarkRegion2D?
    ) -> CGPoint? {
        guard let pupilPoint = pupil?.normalizedPoints.first else { return nil }
        let points = eye.normalizedPoints
        guard !points.isEmpty else { return nil }

        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 1
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 1
        let center = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        return CGPoint(
            x: (pupilPoint.x - center.x) / max(maxX - minX, 0.001),
            y: (pupilPoint.y - center.y) / max(maxY - minY, 0.001)
        )
    }

    private func averageLuma(in pixelBuffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard CVPixelBufferGetPlaneCount(pixelBuffer) > 0,
              let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return 0.5 }
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let pointer = base.assumingMemoryBound(to: UInt8.self)
        let step = 16
        var sum: UInt64 = 0
        var count: UInt64 = 0

        for y in stride(from: 0, to: height, by: step) {
            let row = pointer.advanced(by: y * bytesPerRow)
            for x in stride(from: 0, to: width, by: step) {
                sum += UInt64(row[x])
                count += 1
            }
        }

        guard count > 0 else { return 0.5 }
        return Double(sum) / Double(count) / 255
    }

    private func rednessEstimate(
        pixelBuffer: CVPixelBuffer,
        face: VNFaceObservation,
        leftEye: VNFaceLandmarkRegion2D,
        rightEye: VNFaceLandmarkRegion2D
    ) -> Double? {
        let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(.leftMirrored)
        let rects = [leftEye, rightEye].flatMap { region -> [CGRect] in
            guard let eyeRect = absoluteRect(for: region, faceBox: face.boundingBox) else { return [] }
            let insetY = eyeRect.height * 0.22
            let strip = eyeRect.insetBy(dx: 0, dy: insetY)
            let sideWidth = strip.width * 0.30
            return [
                CGRect(x: strip.minX, y: strip.minY, width: sideWidth, height: strip.height),
                CGRect(x: strip.maxX - sideWidth, y: strip.minY, width: sideWidth, height: strip.height)
            ]
        }

        let values = rects.compactMap { normalizedRect -> Double? in
            let extent = image.extent
            let rect = CGRect(
                x: extent.minX + normalizedRect.minX * extent.width,
                y: extent.minY + normalizedRect.minY * extent.height,
                width: normalizedRect.width * extent.width,
                height: normalizedRect.height * extent.height
            ).intersection(extent)
            guard rect.width >= 2, rect.height >= 2 else { return nil }
            return redDominance(in: image, rect: rect)
        }

        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func absoluteRect(
        for region: VNFaceLandmarkRegion2D,
        faceBox: CGRect
    ) -> CGRect? {
        let points = region.normalizedPoints
        guard !points.isEmpty else { return nil }
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        return CGRect(
            x: faceBox.minX + minX * faceBox.width,
            y: faceBox.minY + minY * faceBox.height,
            width: max((maxX - minX) * faceBox.width, 0),
            height: max((maxY - minY) * faceBox.height, 0)
        )
    }

    private func redDominance(in image: CIImage, rect: CGRect) -> Double? {
        guard let filter = CIFilter(name: "CIAreaAverage") else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: rect), forKey: kCIInputExtentKey)
        guard let output = filter.outputImage else { return nil }

        var rgba = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            output,
            toBitmap: &rgba,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let red = Double(rgba[0])
        let green = Double(rgba[1])
        let blue = Double(rgba[2])
        let brightness = max((red + green + blue) / 3, 1)
        return max((red - (green + blue) / 2) / brightness, 0)
    }
}

private final class EyePreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private struct EyeCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> EyePreviewUIView {
        let view = EyePreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection,
           connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        return view
    }

    func updateUIView(_ uiView: EyePreviewUIView, context: Context) {
        uiView.previewLayer.session = session
        if let connection = uiView.previewLayer.connection,
           connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}

struct EyeComfortCameraView: View {
    private enum Stage: Hashable {
        case welcome
        case calibrating
        case blinking
        case following
        case summary
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @EnvironmentObject private var store: EyeExerciseStore
    @AppStorage(L10n.storageKey) private var langRaw = AppLang.fallback.rawValue

    @StateObject private var analyzer = EyeCameraAnalyzer()
    @State private var stage: Stage = .welcome
    @State private var calibrationProgress = 0.0
    @State private var blinkBaseline = 0
    @State private var targetIndex = 0
    @State private var targetHold = 0.0
    @State private var targetElapsed = 0.0
    @State private var completedTargets = 0
    @State private var missedTargets = 0
    @State private var targetTimes: [Double] = []
    @State private var didSaveSession = false

    private let targetPoints: [CGPoint] = [
        CGPoint(x: 0.50, y: 0.50),
        CGPoint(x: 0.24, y: 0.28),
        CGPoint(x: 0.76, y: 0.28),
        CGPoint(x: 0.80, y: 0.68),
        CGPoint(x: 0.50, y: 0.78),
        CGPoint(x: 0.20, y: 0.68),
        CGPoint(x: 0.50, y: 0.50)
    ]

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop(renderMode: .force)

                Group {
                    switch stage {
                    case .welcome:
                        welcomeView
                    case .calibrating, .blinking, .following:
                        liveSessionView
                    case .summary:
                        summaryView
                    }
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985)))
            }
            .navigationTitle(s("eye.camera.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(s("eye.camera.close")) { dismiss() }
                }
            }
        }
        .task(id: stage) {
            guard stage == .calibrating || stage == .blinking || stage == .following else { return }
            while !Task.isCancelled {
                await MainActor.run { advanceExercise() }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                if stage != .welcome && stage != .summary { analyzer.resumeIfPossible() }
            } else {
                analyzer.stop()
            }
        }
        .onDisappear { analyzer.stop() }
    }

    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: 18) {
                welcomeHero
                privacyCard
                disclaimerCard
                Color.clear.frame(height: 24)
            }
            .lippiContentColumn()
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var welcomeHero: some View {
        GlassCard(padding: 20, cornerRadius: 32, style: .full, forceSystemGlass: false) {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(DS.brandSoftGradient)
                        .frame(width: 138, height: 138)
                        .blur(radius: reduceTransparency ? 0 : 10)

                    Circle()
                        .stroke(DS.accent.opacity(0.20), lineWidth: 12)
                        .frame(width: 108, height: 108)

                    Image(safeSystemName: "eye.circle.fill", fallback: "eye.fill")
                        .font(.system(size: 58, weight: .medium, design: .rounded))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(DS.accent)
                }
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(s("eye.camera.welcome_title"))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(DS.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(s("eye.camera.welcome_subtitle"))
                        .font(.body)
                        .foregroundStyle(DS.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    capabilityChip("camera.viewfinder", s("eye.camera.chip_tracking"))
                    capabilityChip("eye.fill", s("eye.camera.chip_comfort"))
                    capabilityChip("lock.fill", s("eye.camera.chip_private"))
                }

                Button {
                    withAnimation(reduceMotion ? nil : DS.motionState) {
                        stage = .calibrating
                    }
                    analyzer.requestAccessAndStart()
                } label: {
                    Label(s("eye.camera.start"), systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .primary, allowsMultiline: true, forceSystemGlass: true))
            }
        }
    }

    private func capabilityChip(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 6) {
            Image(safeSystemName: icon, fallback: "circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.accent)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 66)
        .padding(.horizontal, 6)
        .background(DS.glassFill(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.10), lineWidth: 1))
    }

    private var privacyCard: some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            HStack(alignment: .top, spacing: 13) {
                Image(safeSystemName: "iphone.and.arrow.forward", fallback: "lock.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x30D158))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: 0x30D158).opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(s("eye.camera.privacy_title"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text(s("eye.camera.privacy_body"))
                        .font(.footnote)
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(safeSystemName: "cross.case.fill", fallback: "info.circle.fill")
                .foregroundStyle(Color(hex: 0xFF9F0A))
            Text(s("eye.camera.disclaimer"))
                .font(.caption)
                .foregroundStyle(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private var liveSessionView: some View {
        VStack(spacing: 14) {
            cameraCanvas
                .frame(maxHeight: .infinity)

            liveMetrics
            liveControls
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var cameraCanvas: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.black.opacity(0.92))

                if analyzer.accessState == .authorized {
                    EyeCameraPreview(session: analyzer.session)
                        .overlay(
                            LinearGradient(
                                colors: [.black.opacity(0.38), .clear, .black.opacity(0.56)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    permissionStateView
                }

                faceGuide

                if stage == .blinking {
                    blinkOrb
                } else if stage == .following {
                    trackingTarget(in: proxy.size)
                }

                VStack {
                    liveStatusPill
                    Spacer()
                    instructionPanel
                }
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(DS.glassStroke(0.18), lineWidth: 1))
        }
    }

    private var faceGuide: some View {
        Ellipse()
            .stroke(
                analyzer.snapshot.isFaceAligned ? Color.green.opacity(0.72) : Color.white.opacity(0.58),
                style: StrokeStyle(lineWidth: 1.5, dash: analyzer.snapshot.isFaceAligned ? [] : [8, 8])
            )
            .frame(width: 220, height: 300)
            .shadow(color: analyzer.snapshot.isFaceAligned ? .green.opacity(0.24) : .clear, radius: 12)
            .animation(reduceMotion ? nil : DS.motionState, value: analyzer.snapshot.isFaceAligned)
            .accessibilityHidden(true)
    }

    private var blinkOrb: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x64D2FF).opacity(0.22))
                .frame(width: 96, height: 96)
                .blur(radius: 8)
            Image(safeSystemName: "eye.fill", fallback: "eye")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.white)
                .scaleEffect(analyzer.snapshot.eyeOpenness < 0.58 ? 0.78 : 1)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: analyzer.snapshot.eyeOpenness)
        .accessibilityHidden(true)
    }

    private func trackingTarget(in size: CGSize) -> some View {
        let point = currentTarget
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.84), lineWidth: 3)
                .frame(width: 62, height: 62)
            Circle()
                .trim(from: 0, to: targetHold)
                .stroke(DS.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 72, height: 72)
            Circle()
                .fill(DS.brand)
                .frame(width: 28, height: 28)
                .shadow(color: DS.accent.opacity(0.55), radius: 14)
        }
        .position(x: point.x * size.width, y: point.y * size.height)
        .animation(reduceMotion ? nil : .spring(duration: 0.48, bounce: 0.12), value: targetIndex)
        .accessibilityLabel(Text(s("eye.camera.target")))
    }

    private var liveStatusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusTone)
                .frame(width: 8, height: 8)
            Text(statusTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.black.opacity(reduceTransparency ? 0.78 : 0.36), in: Capsule())
        .lippiSystemGlass(in: Capsule(), tint: statusTone.opacity(0.16), forceSystemGlass: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var instructionPanel: some View {
        VStack(spacing: 7) {
            Text(instructionTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(instructionSubtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(.black.opacity(reduceTransparency ? 0.82 : 0.34), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            tint: DS.accent.opacity(0.08),
            forceSystemGlass: true
        )
    }

    @ViewBuilder
    private var permissionStateView: some View {
        VStack(spacing: 14) {
            Image(safeSystemName: permissionIcon, fallback: "camera.fill")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            Text(permissionTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if analyzer.accessState == .denied {
                Button(s("eye.camera.open_settings")) { openSettings() }
                    .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true, forceSystemGlass: true))
            }
        }
        .padding(28)
    }

    private var liveMetrics: some View {
        HStack(spacing: 10) {
            metricPill(
                icon: "eye.fill",
                value: opennessValue,
                title: s("eye.camera.metric_openness"),
                tone: Color(hex: 0x64D2FF)
            )
            metricPill(
                icon: "drop.fill",
                value: rednessValue,
                title: s("eye.camera.metric_redness"),
                tone: rednessTone
            )
            metricPill(
                icon: "moon.zzz.fill",
                value: fatigueValue,
                title: s("eye.camera.metric_fatigue"),
                tone: fatigueTone
            )
        }
    }

    private func metricPill(icon: String, value: String, title: String, tone: Color) -> some View {
        VStack(spacing: 5) {
            Image(safeSystemName: icon, fallback: "circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption2)
                .foregroundStyle(DS.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(DS.glassFill(0.06), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(DS.glassStroke(0.11), lineWidth: 1))
    }

    private var liveControls: some View {
        LippiGlassEffectGroup(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    analyzer.stop()
                    dismiss()
                } label: {
                    Label(s("eye.camera.later"), systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true, forceSystemGlass: true))

                if stage == .calibrating && analyzer.accessState == .denied {
                    Button(s("eye.camera.open_settings")) { openSettings() }
                        .buttonStyle(LippiButtonStyle(kind: .primary, compact: true, forceSystemGlass: true))
                }
            }
        }
    }

    private var summaryView: some View {
        ScrollView {
            VStack(spacing: 18) {
                GlassCard(padding: 20, cornerRadius: 32, style: .full, forceSystemGlass: false) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(summaryTone.opacity(0.14))
                                .frame(width: 104, height: 104)
                            Image(safeSystemName: "checkmark.seal.fill", fallback: "checkmark.circle.fill")
                                .font(.system(size: 56, weight: .medium))
                                .foregroundStyle(summaryTone)
                        }

                        Text(s("eye.camera.summary_title"))
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundStyle(DS.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(summaryMessage)
                            .font(.body)
                            .foregroundStyle(DS.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            summaryMetric("scope", "\(completedTargets)/\(targetPoints.count)", s("eye.camera.summary_accuracy"))
                            summaryMetric("eye.fill", "\(max(analyzer.snapshot.blinkCount - blinkBaseline, 0))", s("eye.camera.summary_blinks"))
                            summaryMetric("heart.text.square.fill", comfortValue, s("eye.camera.summary_comfort"))
                        }

                        Button {
                            dismiss()
                        } label: {
                            Text(s("eye.camera.done"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LippiButtonStyle(kind: .primary, forceSystemGlass: true))
                    }
                }

                disclaimerCard
                Color.clear.frame(height: 24)
            }
            .lippiContentColumn()
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func summaryMetric(_ icon: String, _ value: String, _ title: String) -> some View {
        VStack(spacing: 6) {
            Image(safeSystemName: icon, fallback: "circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.accent)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(DS.textPrimary)
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(DS.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 86)
        .background(DS.glassFill(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(DS.glassStroke(0.10), lineWidth: 1))
    }

    private func advanceExercise() {
        guard analyzer.accessState == .authorized else { return }
        let snapshot = analyzer.snapshot

        switch stage {
        case .calibrating:
            if snapshot.isReadyForExercise {
                calibrationProgress = min(calibrationProgress + 0.055, 1)
            } else {
                calibrationProgress = max(calibrationProgress - 0.08, 0)
            }
            if calibrationProgress >= 1 {
                blinkBaseline = snapshot.blinkCount
                withAnimation(reduceMotion ? nil : DS.motionState) { stage = .blinking }
            }

        case .blinking:
            guard snapshot.isReadyForExercise else { return }
            if snapshot.blinkCount - blinkBaseline >= 3 {
                targetIndex = 0
                targetHold = 0
                targetElapsed = 0
                withAnimation(reduceMotion ? nil : DS.motionState) { stage = .following }
            }

        case .following:
            guard snapshot.isReadyForExercise else {
                targetHold = max(targetHold - 0.08, 0)
                return
            }

            targetElapsed += 0.1
            let distance = hypot(
                snapshot.gazePoint.x - currentTarget.x,
                snapshot.gazePoint.y - currentTarget.y
            )
            if distance < 0.27 && snapshot.eyeOpenness > 0.55 {
                targetHold = min(targetHold + 0.14, 1)
            } else {
                targetHold = max(targetHold - 0.07, 0)
            }

            if targetHold >= 1 {
                completedTargets += 1
                targetTimes.append(targetElapsed)
                moveToNextTarget()
            } else if targetElapsed >= 5.5 {
                missedTargets += 1
                moveToNextTarget()
            }

        case .welcome, .summary:
            break
        }
    }

    private func moveToNextTarget() {
        if targetIndex + 1 >= targetPoints.count {
            completeSession()
            return
        }
        targetIndex += 1
        targetHold = 0
        targetElapsed = 0
        DS.hapticSoft()
    }

    private func completeSession() {
        guard !didSaveSession else { return }
        didSaveSession = true
        let average = targetTimes.isEmpty ? nil : targetTimes.reduce(0, +) / Double(targetTimes.count)
        store.addSession(
            EyeSessionHistory(
                mode: .tracking,
                hits: completedTargets,
                misses: missedTargets,
                total: targetPoints.count,
                avgReaction: average,
                bestReaction: targetTimes.min(),
                bestStreak: completedTargets
            )
        )
        analyzer.stop()
        withAnimation(reduceMotion ? nil : DS.motionState) { stage = .summary }
    }

    private var currentTarget: CGPoint {
        targetPoints[min(max(targetIndex, 0), targetPoints.count - 1)]
    }

    private var statusTitle: String {
        let snapshot = analyzer.snapshot
        if analyzer.accessState == .requesting { return s("eye.camera.status_requesting") }
        if !snapshot.hasFace { return s("eye.camera.status_no_face") }
        if !snapshot.isFaceAligned { return s("eye.camera.status_align") }
        if !snapshot.hasUsableLight { return s("eye.camera.status_light") }
        return s("eye.camera.status_ready")
    }

    private var statusTone: Color {
        analyzer.snapshot.isReadyForExercise ? Color(hex: 0x30D158) : Color(hex: 0xFF9F0A)
    }

    private var instructionTitle: String {
        switch stage {
        case .calibrating: return s("eye.camera.calibration_title")
        case .blinking: return s("eye.camera.blink_title")
        case .following: return s("eye.camera.follow_title")
        case .welcome, .summary: return ""
        }
    }

    private var instructionSubtitle: String {
        switch stage {
        case .calibrating:
            return L10n.fmt("eye.camera.calibration_progress", lang, Int((calibrationProgress * 100).rounded()))
        case .blinking:
            return L10n.fmt("eye.camera.blink_progress", lang, min(max(analyzer.snapshot.blinkCount - blinkBaseline, 0), 3), 3)
        case .following:
            return L10n.fmt("eye.camera.follow_progress", lang, min(targetIndex + 1, targetPoints.count), targetPoints.count)
        case .welcome, .summary:
            return ""
        }
    }

    private var permissionIcon: String {
        switch analyzer.accessState {
        case .denied: return "camera.fill.badge.xmark"
        case .unavailable, .failed: return "exclamationmark.triangle.fill"
        case .idle, .requesting, .authorized: return "camera.fill"
        }
    }

    private var permissionTitle: String {
        switch analyzer.accessState {
        case .requesting: return s("eye.camera.permission_requesting")
        case .denied: return s("eye.camera.permission_denied")
        case .unavailable: return s("eye.camera.permission_unavailable")
        case .failed: return s("eye.camera.permission_failed")
        case .idle, .authorized: return s("eye.camera.permission_preparing")
        }
    }

    private var opennessValue: String {
        guard analyzer.snapshot.hasEyes else { return "—" }
        return analyzer.snapshot.eyeOpenness >= 0.72 ? s("eye.camera.value_good") : s("eye.camera.value_blink")
    }

    private var rednessValue: String {
        guard analyzer.snapshot.hasUsableLight,
              let value = analyzer.snapshot.rednessScore else { return "—" }
        if value < 0.38 { return s("eye.camera.value_calm") }
        if value < 0.68 { return s("eye.camera.value_attention") }
        return s("eye.camera.value_pause")
    }

    private var rednessTone: Color {
        guard let value = analyzer.snapshot.rednessScore else { return DS.textTertiary }
        if value < 0.38 { return Color(hex: 0x30D158) }
        if value < 0.68 { return Color(hex: 0xFF9F0A) }
        return Color(hex: 0xFF453A)
    }

    private var fatigueValue: String {
        let value = analyzer.snapshot.fatigueScore
        if value < 0.34 { return s("eye.camera.value_low") }
        if value < 0.68 { return s("eye.camera.value_medium") }
        return s("eye.camera.value_high")
    }

    private var fatigueTone: Color {
        let value = analyzer.snapshot.fatigueScore
        if value < 0.34 { return Color(hex: 0x30D158) }
        if value < 0.68 { return Color(hex: 0xFF9F0A) }
        return Color(hex: 0xFF453A)
    }

    private var summaryTone: Color {
        analyzer.snapshot.fatigueScore < 0.68 ? Color(hex: 0x30D158) : Color(hex: 0xFF9F0A)
    }

    private var summaryMessage: String {
        let redness = analyzer.snapshot.rednessScore ?? 0
        let fatigue = analyzer.snapshot.fatigueScore
        if fatigue >= 0.68 || redness >= 0.68 { return s("eye.camera.summary_rest") }
        if fatigue >= 0.34 || redness >= 0.38 { return s("eye.camera.summary_gentle") }
        return s("eye.camera.summary_good")
    }

    private var comfortValue: String {
        let score = max(analyzer.snapshot.fatigueScore, analyzer.snapshot.rednessScore ?? 0)
        if score < 0.34 { return s("eye.camera.value_good") }
        if score < 0.68 { return s("eye.camera.value_attention") }
        return s("eye.camera.value_pause")
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
#else
struct EyeComfortCameraView: View {
    var body: some View { EmptyView() }
}
#endif
