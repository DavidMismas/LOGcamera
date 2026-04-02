@preconcurrency import AVFoundation
import Combine
import Photos
import SwiftUI
import VideoToolbox

struct FocusFeedback: Identifiable {
    let id = UUID()
    let previewPoint: CGPoint
    let isLocked: Bool
}

struct LensOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    let shortName: String
    let deviceType: AVCaptureDevice.DeviceType
    let position: AVCaptureDevice.Position
    let sortOrder: Int
}

enum CaptureColorProfile {
    case appleLog2
    case appleLog
    case unavailable

    var title: String {
        switch self {
        case .appleLog2:
            return "Apple Log 2"
        case .appleLog:
            return "Apple Log"
        case .unavailable:
            return "Log Unsupported"
        }
    }

    var colorSpace: AVCaptureColorSpace? {
        switch self {
        case .appleLog2:
            return .appleLog2
        case .appleLog:
            return .appleLog
        case .unavailable:
            return nil
        }
    }

    var priority: Int {
        switch self {
        case .appleLog2:
            return 2
        case .appleLog:
            return 1
        case .unavailable:
            return 0
        }
    }
}

enum CaptureStabilizationMode: String, CaseIterable, Identifiable {
    case off
    case standard
    case cinematic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .standard:
            return "Standard"
        case .cinematic:
            return "Cinematic"
        }
    }

    init(avMode: AVCaptureVideoStabilizationMode) {
        switch avMode {
        case .standard:
            self = .standard
        case .cinematic, .cinematicExtended, .cinematicExtendedEnhanced:
            self = .cinematic
        default:
            self = .off
        }
    }

    static func title(for avMode: AVCaptureVideoStabilizationMode) -> String {
        switch avMode {
        case .standard:
            return "Standard"
        case .cinematic:
            return "Cinematic"
        case .cinematicExtended:
            return "Cinematic Extended"
        case .cinematicExtendedEnhanced:
            return "Cinematic Enhanced"
        default:
            return "Off"
        }
    }
}

enum PreviewLookMode: String, CaseIterable, Identifiable {
    case log
    case rec709

    var id: String { rawValue }

    var title: String {
        switch self {
        case .log:
            return "Log"
        case .rec709:
            return "Rec.709"
        }
    }
}

enum ProExposureMode: String, CaseIterable, Identifiable {
    case auto
    case shutterAngle180
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .shutterAngle180:
            return "180°"
        case .manual:
            return "Manual"
        }
    }
}

final class CameraManager: NSObject, ObservableObject {
    private enum SettingsKey {
        static let selectedFrameRate = "camera.selectedFrameRate"
        static let whiteBalanceLockedDuringRecording = "camera.whiteBalanceLockedDuringRecording"
        static let exposureLockedDuringRecording = "camera.exposureLockedDuringRecording"
        static let selectedStabilizationMode = "camera.selectedStabilizationMode"
        static let recordingBitrateMbps = "camera.recordingBitrateMbps"
        static let usesCustomBitrate = "camera.usesCustomBitrate"
        static let exposureBias = "camera.exposureBias"
        static let whiteBalanceTemperature = "camera.whiteBalanceTemperature"
        static let usesManualWhiteBalance = "camera.usesManualWhiteBalance"
        static let manualFocusEnabled = "camera.manualFocusEnabled"
        static let manualFocusPosition = "camera.manualFocusPosition"
        static let previewLookMode = "camera.previewLookMode"
        static let proExposureEnabled = "camera.proExposureEnabled"
        static let proExposureMode = "camera.proExposureMode"
        static let manualShutterSpeedDenominator = "camera.manualShutterSpeedDenominator"
        static let manualISO = "camera.manualISO"
    }

    static let supportedFrameRates = [24, 25, 30, 60, 120]
    static let supportedBitratesMbps: [Double] = [30, 50, 80]

    @Published var session = AVCaptureSession()
    @Published private(set) var isAuthorized = false
    @Published private(set) var availableLenses: [LensOption] = []
    @Published private(set) var activeLensID: String?
    @Published private(set) var activeDevice: AVCaptureDevice?
    @Published private(set) var focusFeedback: FocusFeedback?
    @Published private(set) var canRecord = false
    @Published private(set) var colorProfile: CaptureColorProfile = .unavailable
    @Published private(set) var exposureBias: Float = 0
    @Published private(set) var manualFocusEnabled = false
    @Published private(set) var manualFocusPosition: Float = 0.5
    @Published private(set) var supportsManualFocus = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var recordedVideoURL: URL?
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var whiteBalanceTemperature = 5600.0
    @Published private(set) var usesManualWhiteBalance = false

    @Published var selectedFrameRate = 30 {
        didSet { UserDefaults.standard.set(selectedFrameRate, forKey: SettingsKey.selectedFrameRate) }
    }
    @Published var whiteBalanceLockedDuringRecording = true {
        didSet { UserDefaults.standard.set(whiteBalanceLockedDuringRecording, forKey: SettingsKey.whiteBalanceLockedDuringRecording) }
    }
    @Published var exposureLockedDuringRecording = true {
        didSet { UserDefaults.standard.set(exposureLockedDuringRecording, forKey: SettingsKey.exposureLockedDuringRecording) }
    }
    @Published var selectedStabilizationMode: CaptureStabilizationMode = .off {
        didSet { UserDefaults.standard.set(selectedStabilizationMode.rawValue, forKey: SettingsKey.selectedStabilizationMode) }
    }
    @Published var previewLookMode: PreviewLookMode = .log {
        didSet {
            UserDefaults.standard.set(previewLookMode.rawValue, forKey: SettingsKey.previewLookMode)
        }
    }
    @Published private(set) var recordingBitrateMbps = 30.0
    @Published private(set) var usesCustomBitrate = false
    @Published private(set) var activeStabilizationMode: CaptureStabilizationMode = .off
    @Published private(set) var activeStabilizationTitle = "Off"
    @Published private(set) var supportedStabilizationModes: [CaptureStabilizationMode] = [.off]
    @Published var proExposureEnabled = false {
        didSet { UserDefaults.standard.set(proExposureEnabled, forKey: SettingsKey.proExposureEnabled) }
    }
    @Published var proExposureMode: ProExposureMode = .auto {
        didSet { UserDefaults.standard.set(proExposureMode.rawValue, forKey: SettingsKey.proExposureMode) }
    }
    @Published private(set) var manualShutterSpeedDenominator = 60
    @Published private(set) var manualISO: Float = 100

    var exposureBiasRange: ClosedRange<Float> {
        guard let device = activeDevice else { return -2...2 }
        return device.minExposureTargetBias...device.maxExposureTargetBias
    }

    var whiteBalanceTemperatureRange: ClosedRange<Double> {
        2500...9000
    }

    var isoRange: ClosedRange<Float> {
        guard let device = activeDevice else { return 25...3200 }
        return device.activeFormat.minISO...device.activeFormat.maxISO
    }

    var availableShutterSpeedDenominators: [Int] {
        let candidates = [
            24, 25, 30, 40, 48, 50, 60, 72, 80, 90, 96, 100,
            120, 125, 144, 160, 180, 192, 200, 240, 250, 288, 320,
            360, 400, 480, 500, 576, 640, 720, 800, 960, 1000, 1200,
            1600, 2000, 3200, 4000, 8000
        ]

        let frameLimitedMaxDuration = 1.0 / Double(max(selectedFrameRate, 1))
        guard let device = activeDevice else {
            return candidates.filter { (1.0 / Double($0)) <= frameLimitedMaxDuration }
        }

        let minDuration = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
        let maxDuration = min(CMTimeGetSeconds(device.activeFormat.maxExposureDuration), frameLimitedMaxDuration)
        let filtered = candidates.filter { denominator in
            let duration = 1.0 / Double(denominator)
            return duration >= minDuration && duration <= maxDuration
        }

        let ideal = idealShutterSpeedDenominator(for: selectedFrameRate)
        let combined = Set(filtered + [ideal, selectedFrameRate, manualShutterSpeedDenominator])
        return combined.sorted()
    }

    var availableISOValues: [Float] {
        let commonValues: [Float] = [
            25, 32, 40, 50, 64, 80, 100, 125, 160, 200, 250, 320,
            400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200,
            4000, 5000, 6400, 8000, 10000, 12800
        ]

        let clampedValues = commonValues.filter { isoRange.contains($0) }
        let combined = Set(clampedValues + [isoRange.lowerBound, manualISO, isoRange.upperBound])
        return combined.sorted()
    }

    var currentShutterSpeedLabel: String {
        "1/\(currentShutterSpeedDenominator)"
    }

    var currentISOValueLabel: String {
        proExposureMode == .shutterAngle180 ? "Auto" : String(format: "%.0f", manualISO)
    }

    var supportsExposureBiasAdjustment: Bool {
        !proExposureEnabled || proExposureMode == .auto
    }

    var currentShutterSpeedDenominator: Int {
        proExposureMode == .shutterAngle180 ? idealShutterSpeedDenominator(for: selectedFrameRate) : manualShutterSpeedDenominator
    }

    var colorProfileTitle: String {
        colorProfile.title
    }

    var captureSummaryText: String {
        "4K • \(selectedFrameRate) fps • HEVC • \(colorProfile.title)"
    }

    var activeLensSummary: String {
        guard let lens = availableLenses.first(where: { $0.id == activeLensID }) else {
            return "No lens selected"
        }
        return lens.displayName
    }

    var recordingTimeText: String {
        let totalSeconds = Int(recordingDuration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var recordingBitrateLabel: String {
        String(format: "%.0f Mb/s", recordingBitrateMbps)
    }

    var whiteBalanceLabel: String {
        usesManualWhiteBalance ? String(format: "%.0f K", whiteBalanceTemperature) : "Auto"
    }

    private let required4KResolution = CMVideoDimensions(width: 3840, height: 2160)
    private let sessionQueue = DispatchQueue(label: "com.logcamera.sessionQueue")
    private let feedbackDuration: TimeInterval = 2.0
    private let focusLockDelay: TimeInterval = 0.2

    private var isSessionConfigured = false
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let audioDataOutput = AVCaptureAudioDataOutput()
    private var deviceRegistry: [String: AVCaptureDevice] = [:]
    private var captureRotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var captureRotationObservation: NSKeyValueObservation?
    private var activeVideoStabilizationObservation: NSKeyValueObservation?
    private var focusFeedbackDismissWorkItem: DispatchWorkItem?
    private var pendingFocusLockWorkItem: DispatchWorkItem?
    private var statusMessageDismissWorkItem: DispatchWorkItem?
    private var recordingTimer: Timer?
    private let writerQueue = DispatchQueue(label: "com.logcamera.writerQueue")
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var currentRecordingURL: URL?
    private var isWritingSessionStarted = false
    private var recordingSourceStartTime: CMTime?
    private var exactVideoFrameCount: Int64 = 0
    private var currentCaptureRotationAngle: CGFloat = 0
    private let previewFrameSubject = PassthroughSubject<PreviewFrame, Never>()
    private var proExposureAutomationTimer: DispatchSourceTimer?

    var previewFramePublisher: AnyPublisher<PreviewFrame, Never> {
        previewFrameSubject.eraseToAnyPublisher()
    }

    override init() {
        super.init()
        restorePersistedSettings()
        checkPermissions()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            startSession()
        case .inactive, .background:
            stopSession()
        @unknown default:
            break
        }
    }

    func selectFrameRate(_ fps: Int) {
        guard Self.supportedFrameRates.contains(fps) else { return }
        selectedFrameRate = fps
        if !usesCustomBitrate {
            recordingBitrateMbps = defaultBitrateMbps(for: fps)
            UserDefaults.standard.set(recordingBitrateMbps, forKey: SettingsKey.recordingBitrateMbps)
        }
        reconfigureActiveLens()
    }

    func selectStabilizationMode(_ mode: CaptureStabilizationMode) {
        guard supportedStabilizationModes.contains(mode) else {
            presentStatusMessage("This stabilization mode is unavailable for the current lens/FPS/format.")
            return
        }
        selectedStabilizationMode = mode
        reconfigureActiveLens()
    }

    func selectPreviewLookMode(_ mode: PreviewLookMode) {
        previewLookMode = mode
    }

    func setProExposureEnabled(_ isEnabled: Bool) {
        proExposureEnabled = isEnabled
        syncExposureConfiguration()
    }

    func selectProExposureMode(_ mode: ProExposureMode) {
        proExposureMode = mode
        if mode == .shutterAngle180 {
            manualShutterSpeedDenominator = idealShutterSpeedDenominator(for: selectedFrameRate)
            UserDefaults.standard.set(manualShutterSpeedDenominator, forKey: SettingsKey.manualShutterSpeedDenominator)
        }
        syncExposureConfiguration()
    }

    func setManualShutterSpeedDenominator(_ denominator: Int) {
        let nearest = nearestShutterSpeedDenominator(to: denominator)
        manualShutterSpeedDenominator = nearest
        UserDefaults.standard.set(nearest, forKey: SettingsKey.manualShutterSpeedDenominator)
        syncExposureConfiguration()
    }

    func setManualISO(_ value: Float) {
        let clamped = min(max(value, isoRange.lowerBound), isoRange.upperBound)
        manualISO = clamped
        UserDefaults.standard.set(Double(clamped), forKey: SettingsKey.manualISO)
        syncExposureConfiguration()
    }

    func setRecordingBitrateMbps(_ value: Double) {
        guard let supportedValue = Self.supportedBitratesMbps.first(where: { abs($0 - value) < 0.001 }) else { return }
        recordingBitrateMbps = supportedValue
        usesCustomBitrate = true
        let defaults = UserDefaults.standard
        defaults.set(recordingBitrateMbps, forKey: SettingsKey.recordingBitrateMbps)
        defaults.set(usesCustomBitrate, forKey: SettingsKey.usesCustomBitrate)
    }

    func resetRecordingBitrateToDefault() {
        usesCustomBitrate = false
        recordingBitrateMbps = defaultBitrateMbps(for: selectedFrameRate)
        let defaults = UserDefaults.standard
        defaults.set(recordingBitrateMbps, forKey: SettingsKey.recordingBitrateMbps)
        defaults.set(usesCustomBitrate, forKey: SettingsKey.usesCustomBitrate)
    }

    private func syncExposureConfiguration() {
        sessionQueue.async {
            guard let device = self.videoInput?.device ?? self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                self.applyExposureConfiguration(on: device)
                device.unlockForConfiguration()
            } catch {
                self.presentStatusMessage("Exposure mode update failed.")
            }
            self.updateProExposureAutomationState()
        }
    }

    func switchLens(to lensID: String) {
        guard !isRecording else { return }
        sessionQueue.async {
            guard let device = self.deviceRegistry[lensID] else { return }
            self.session.beginConfiguration()
            var shouldRefreshOutput = false
            defer {
                self.session.commitConfiguration()
                if shouldRefreshOutput {
                    self.configureOutput()
                }
            }

            if let currentInput = self.videoInput {
                self.session.removeInput(currentInput)
                self.videoInput = nil
            }

            guard self.installVideoInput(device: device) else {
                self.presentStatusMessage("Failed to activate selected lens.")
                return
            }

            self.configureDeviceForCurrentSelection()
            shouldRefreshOutput = true
        }
    }

    func setExposureBias(_ value: Float) {
        let clamped = min(max(value, exposureBiasRange.lowerBound), exposureBiasRange.upperBound)
        exposureBias = clamped
        UserDefaults.standard.set(Double(clamped), forKey: SettingsKey.exposureBias)

        sessionQueue.async {
            guard let device = self.videoInput?.device ?? self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(clamped) { _ in }
                device.unlockForConfiguration()
            } catch {
                self.presentStatusMessage("Exposure adjustment failed.")
            }
        }
    }

    private func idealShutterSpeedDenominator(for frameRate: Int) -> Int {
        max(frameRate * 2, frameRate)
    }

    private func nearestShutterSpeedDenominator(to denominator: Int) -> Int {
        availableShutterSpeedDenominators.min(by: {
            abs($0 - denominator) < abs($1 - denominator)
        }) ?? idealShutterSpeedDenominator(for: selectedFrameRate)
    }

    private func shutterDuration(for denominator: Int) -> CMTime {
        let seconds = 1.0 / Double(max(denominator, 1))
        return CMTime(seconds: seconds, preferredTimescale: 1_000_000)
    }

    private func clampedShutterDuration(for denominator: Int, device: AVCaptureDevice) -> CMTime {
        let requestedSeconds = 1.0 / Double(max(denominator, 1))
        let minSeconds = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
        let maxSeconds = min(
            CMTimeGetSeconds(device.activeFormat.maxExposureDuration),
            1.0 / Double(max(selectedFrameRate, 1))
        )
        let clampedSeconds = min(max(requestedSeconds, minSeconds), maxSeconds)
        return CMTime(seconds: clampedSeconds, preferredTimescale: 1_000_000)
    }

    private func clampedISO(_ iso: Float, for device: AVCaptureDevice) -> Float {
        min(max(iso, device.activeFormat.minISO), device.activeFormat.maxISO)
    }

    private func applyExposureConfiguration(on device: AVCaptureDevice) {
        switch (proExposureEnabled, proExposureMode) {
        case (true, .shutterAngle180):
            let duration = clampedShutterDuration(
                for: idealShutterSpeedDenominator(for: selectedFrameRate),
                device: device
            )
            device.setExposureModeCustom(
                duration: duration,
                iso: AVCaptureDevice.currentISO,
                completionHandler: nil
            )

        case (true, .manual):
            let duration = clampedShutterDuration(
                for: manualShutterSpeedDenominator,
                device: device
            )
            device.setExposureModeCustom(
                duration: duration,
                iso: clampedISO(manualISO, for: device),
                completionHandler: nil
            )

        default:
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            } else if device.isExposureModeSupported(.autoExpose) {
                device.exposureMode = .autoExpose
            }
            device.setExposureTargetBias(exposureBias) { _ in }
        }
    }

    private func updateProExposureAutomationState() {
        stopProExposureAutomation()

        guard proExposureEnabled,
              proExposureMode == .shutterAngle180,
              !isRecording,
              isSessionConfigured,
              session.isRunning else { return }

        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now() + .milliseconds(350), repeating: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            self?.adjustISOFor180DegreeExposure()
        }
        proExposureAutomationTimer = timer
        timer.resume()
    }

    private func stopProExposureAutomation() {
        proExposureAutomationTimer?.cancel()
        proExposureAutomationTimer = nil
    }

    private func adjustISOFor180DegreeExposure() {
        guard proExposureEnabled,
              proExposureMode == .shutterAngle180,
              let device = videoInput?.device ?? activeDevice else { return }

        let offset = device.exposureTargetOffset
        guard offset.isFinite, abs(offset) > 0.15 else { return }

        let currentISO = device.iso
        let correctionFactor = powf(2.0, -offset * 0.55)
        let adjustedISO = clampedISO(currentISO * correctionFactor, for: device)
        guard abs(adjustedISO - currentISO) > 1.0 else { return }

        do {
            try device.lockForConfiguration()
            let duration = clampedShutterDuration(
                for: idealShutterSpeedDenominator(for: selectedFrameRate),
                device: device
            )
            device.setExposureModeCustom(duration: duration, iso: adjustedISO, completionHandler: nil)
            device.unlockForConfiguration()
        } catch {
            presentStatusMessage("180° exposure update failed.")
        }
    }

    func setWhiteBalanceTemperature(_ value: Double) {
        let clamped = min(max(value, whiteBalanceTemperatureRange.lowerBound), whiteBalanceTemperatureRange.upperBound)
        whiteBalanceTemperature = clamped
        usesManualWhiteBalance = true
        let defaults = UserDefaults.standard
        defaults.set(whiteBalanceTemperature, forKey: SettingsKey.whiteBalanceTemperature)
        defaults.set(usesManualWhiteBalance, forKey: SettingsKey.usesManualWhiteBalance)

        sessionQueue.async {
            guard let device = self.videoInput?.device ?? self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                self.applyWhiteBalanceState(on: device)
                device.unlockForConfiguration()
            } catch {
                self.presentStatusMessage("White balance update failed.")
            }
        }
    }

    func setWhiteBalanceAuto() {
        usesManualWhiteBalance = false
        let defaults = UserDefaults.standard
        defaults.set(usesManualWhiteBalance, forKey: SettingsKey.usesManualWhiteBalance)

        sessionQueue.async {
            guard let device = self.videoInput?.device ?? self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                self.applyWhiteBalanceState(on: device)
                device.unlockForConfiguration()
            } catch {
                self.presentStatusMessage("White balance update failed.")
            }
        }
    }

    func setManualFocusEnabled(_ isEnabled: Bool) {
        manualFocusEnabled = isEnabled
        UserDefaults.standard.set(manualFocusEnabled, forKey: SettingsKey.manualFocusEnabled)
        sessionQueue.async {
            guard let device = self.videoInput?.device ?? self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                if isEnabled, device.isLockingFocusWithCustomLensPositionSupported {
                    device.setFocusModeLocked(lensPosition: self.manualFocusPosition, completionHandler: nil)
                } else if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                } else if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
            } catch {
                self.presentStatusMessage("Focus mode update failed.")
            }
        }
    }

    func setManualFocusPosition(_ position: Float) {
        let clamped = min(max(position, 0), 1)
        manualFocusPosition = clamped
        if !manualFocusEnabled {
            manualFocusEnabled = true
        }
        let defaults = UserDefaults.standard
        defaults.set(Double(manualFocusPosition), forKey: SettingsKey.manualFocusPosition)
        defaults.set(manualFocusEnabled, forKey: SettingsKey.manualFocusEnabled)

        sessionQueue.async {
            guard let device = self.videoInput?.device ?? self.activeDevice,
                  device.isLockingFocusWithCustomLensPositionSupported else { return }
            do {
                try device.lockForConfiguration()
                device.setFocusModeLocked(lensPosition: clamped, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {
                self.presentStatusMessage("Manual focus update failed.")
            }
        }
    }

    func startRecording() {
        guard !isRecording else { return }
        guard canRecord else {
            presentStatusMessage("Current lens or FPS does not support 4K HEVC Apple Log capture.")
            return
        }

        sessionQueue.async {
            guard !self.isRecording else { return }
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = false
            self.stopProExposureAutomation()
            self.prepareDeviceForRecording()

            let fileName = UUID().uuidString + ".mov"
            let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)

            do {
                try self.prepareWriter(at: fileURL)
            } catch {
                self.restoreDeviceAfterRecording()
                self.presentStatusMessage("Writer setup failed: \(error.localizedDescription)")
                return
            }

            DispatchQueue.main.async {
                self.recordedVideoURL = fileURL
                self.recordingDuration = 0
                self.isRecording = true
                self.recordingTimer?.invalidate()
                self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    self.recordingDuration += 1
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
        }

        sessionQueue.async {
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        }

        writerQueue.async {
            self.finishWriting()
        }
    }

    func focus(at point: CGPoint) {
        guard !manualFocusEnabled else { return }
        updateFocus(at: point, shouldLockAfterFocus: false)
    }

    func focusAndLock(at point: CGPoint) {
        guard !manualFocusEnabled else { return }
        updateFocus(at: point, shouldLockAfterFocus: true)
    }

    func showFocusFeedback(at previewPoint: CGPoint, isLocked: Bool) {
        let clampedPoint = CGPoint(
            x: min(max(previewPoint.x, 0), 1),
            y: min(max(previewPoint.y, 0), 1)
        )

        focusFeedbackDismissWorkItem?.cancel()

        let feedback = FocusFeedback(previewPoint: clampedPoint, isLocked: isLocked)
        focusFeedback = feedback

        let dismissWorkItem = DispatchWorkItem { [weak self] in
            guard let self, self.focusFeedback?.id == feedback.id else { return }
            self.focusFeedback = nil
        }

        focusFeedbackDismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackDuration, execute: dismissWorkItem)
    }

    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            requestAudioPermissionAndSetup()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    if granted {
                        self.requestAudioPermissionAndSetup()
                    }
                }
            }
        default:
            isAuthorized = false
        }
    }

    private func requestAudioPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized, .denied, .restricted:
            requestPhotoLibraryPermissionIfNeeded()
            setupSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async {
                    self.requestPhotoLibraryPermissionIfNeeded()
                    self.setupSessionIfNeeded()
                }
            }
        @unknown default:
            requestPhotoLibraryPermissionIfNeeded()
            setupSessionIfNeeded()
        }
    }

    private func requestPhotoLibraryPermissionIfNeeded() {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited, .denied, .restricted:
            break
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }
        @unknown default:
            break
        }
    }

    private func setupSessionIfNeeded() {
        guard !isSessionConfigured else { return }
        sessionQueue.async {
            guard !self.isSessionConfigured else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .inputPriority
            self.session.automaticallyConfiguresCaptureDeviceForWideColor = false

            let options = self.discoverLenses()

            guard let defaultLens = Self.defaultLensOption(from: options),
                  let device = self.deviceRegistry[defaultLens.id],
                  self.installVideoInput(device: device) else {
                self.presentStatusMessage("No compatible camera lenses found.")
                self.session.commitConfiguration()
                return
            }

            self.installAudioInputIfPossible()

            self.installDataOutputsIfPossible()

            self.configureDeviceForCurrentSelection()
            self.configureOutput()

            self.session.commitConfiguration()
            self.isSessionConfigured = true
            self.session.startRunning()
            self.configureOutput()
        }
    }

    private func discoverLenses() -> [LensOption] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInUltraWideCamera,
                .builtInWideAngleCamera,
                .builtInTelephotoCamera,
                .builtInDualCamera,
                .builtInDualWideCamera,
                .builtInTripleCamera,
                .builtInTrueDepthCamera
            ],
            mediaType: .video,
            position: .unspecified
        )

        let allDevices = discoverySession.devices
        let physicalDevices = allDevices.filter { !$0.isVirtualDevice }
        let devices = physicalDevices.isEmpty ? allDevices : physicalDevices

        let optionPairs = devices.compactMap { device -> (LensOption, AVCaptureDevice)? in
            guard let option = Self.makeLensOption(for: device) else { return nil }
            return (option, device)
        }

        let options = optionPairs.map(\.0)
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.displayName < rhs.displayName
                }
                return lhs.sortOrder < rhs.sortOrder
            }

        deviceRegistry = Dictionary(uniqueKeysWithValues: optionPairs.map { ($0.0.id, $0.1) })

        DispatchQueue.main.async {
            self.availableLenses = options
        }

        return options
    }

    private static func makeLensOption(for device: AVCaptureDevice) -> LensOption? {
        switch (device.position, device.deviceType) {
        case (.back, .builtInUltraWideCamera):
            return LensOption(
                id: device.uniqueID,
                displayName: "Ultra Wide",
                shortName: "Ultra Wide",
                deviceType: device.deviceType,
                position: device.position,
                sortOrder: 0
            )
        case (.back, .builtInWideAngleCamera):
            return LensOption(
                id: device.uniqueID,
                displayName: "Wide",
                shortName: "Wide",
                deviceType: device.deviceType,
                position: device.position,
                sortOrder: 1
            )
        case (.back, .builtInTelephotoCamera):
            return LensOption(
                id: device.uniqueID,
                displayName: "Tele",
                shortName: "Tele",
                deviceType: device.deviceType,
                position: device.position,
                sortOrder: 2
            )
        case (.front, .builtInTrueDepthCamera), (.front, .builtInWideAngleCamera):
            return LensOption(
                id: device.uniqueID,
                displayName: "Front",
                shortName: "Front",
                deviceType: device.deviceType,
                position: device.position,
                sortOrder: 10
            )
        case (.back, .builtInDualWideCamera):
            return LensOption(
                id: device.uniqueID,
                displayName: "Wide",
                shortName: "Wide",
                deviceType: device.deviceType,
                position: device.position,
                sortOrder: 3
            )
        case (.back, .builtInDualCamera):
            return LensOption(
                id: device.uniqueID,
                displayName: "Wide",
                shortName: "Wide",
                deviceType: device.deviceType,
                position: device.position,
                sortOrder: 4
            )
        case (.back, .builtInTripleCamera):
            return LensOption(
                id: device.uniqueID,
                displayName: "Wide",
                shortName: "Wide",
                deviceType: device.deviceType,
                position: device.position,
                sortOrder: 5
            )
        default:
            return nil
        }
    }

    private static func defaultLensOption(from options: [LensOption]) -> LensOption? {
        options.first(where: { $0.deviceType == .builtInWideAngleCamera && $0.position == .back }) ??
        options.first(where: { $0.position == .back }) ??
        options.first
    }

    private func installVideoInput(device: AVCaptureDevice) -> Bool {
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { return false }
            session.addInput(input)
            videoInput = input
            DispatchQueue.main.async {
                self.activeDevice = device
                self.activeLensID = device.uniqueID
                self.supportsManualFocus = device.isLockingFocusWithCustomLensPositionSupported
                self.manualFocusPosition = device.lensPosition
                if !device.isLockingFocusWithCustomLensPositionSupported {
                    self.manualFocusEnabled = false
                }
            }
            setupCaptureRotationCoordinator(for: device)
            return true
        } catch {
            return false
        }
    }

    private func installAudioInputIfPossible() {
        guard audioInput == nil,
              let device = AVCaptureDevice.default(for: .audio) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { return }
            session.addInput(input)
            audioInput = input
        } catch {
            presentStatusMessage("Audio input unavailable.")
        }
    }

    private func installDataOutputsIfPossible() {
        if session.canAddOutput(videoDataOutput) {
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            session.addOutput(videoDataOutput)
            configureVideoDataOutputPixelFormat()
            videoDataOutput.setSampleBufferDelegate(self, queue: writerQueue)
        }

        if session.canAddOutput(audioDataOutput) {
            audioDataOutput.setSampleBufferDelegate(self, queue: writerQueue)
            session.addOutput(audioDataOutput)
        }
    }

    private func configureVideoDataOutputPixelFormat() {
        let availableFormats = Set(videoDataOutput.availableVideoPixelFormatTypes)

        let preferredFormats: [OSType] = [
            kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
            kCVPixelFormatType_420YpCbCr10BiPlanarFullRange,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]

        let fallbackFormats: [OSType] = [
            kCVPixelFormatType_32BGRA
        ]

        guard let selectedFormat = (preferredFormats + fallbackFormats).first(where: { availableFormats.contains($0) }) else {
            return
        }

        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: selectedFormat
        ]
    }

    private func reconfigureActiveLens() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.configureDeviceForCurrentSelection()
            self.session.commitConfiguration()
            self.configureOutput()
        }
    }

    private func configureDeviceForCurrentSelection() {
        guard let device = videoInput?.device ?? activeDevice else { return }

        do {
            let selection = try selectBestFormat(for: device, targetFrameRate: selectedFrameRate)

            try device.lockForConfiguration()
            device.activeFormat = selection.format
            let frameDuration = CMTime(value: 1, timescale: CMTimeScale(selectedFrameRate))
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration
            if let colorSpace = selection.profile.colorSpace {
                device.activeColorSpace = colorSpace
            }
            if device.isFocusModeSupported(.continuousAutoFocus) && !manualFocusEnabled {
                device.focusMode = .continuousAutoFocus
            }
            applyWhiteBalanceState(on: device)
            applyExposureConfiguration(on: device)
            if manualFocusEnabled && device.isLockingFocusWithCustomLensPositionSupported {
                device.setFocusModeLocked(lensPosition: manualFocusPosition, completionHandler: nil)
            }
            device.unlockForConfiguration()

            updateSupportedStabilizationModes(for: selection.format)
            updateProExposureAutomationState()

            DispatchQueue.main.async {
                self.activeDevice = device
                self.activeLensID = device.uniqueID
                self.supportsManualFocus = device.isLockingFocusWithCustomLensPositionSupported
                self.colorProfile = selection.profile
                self.canRecord = true
                self.manualISO = self.clampedISO(self.manualISO, for: device)
                self.manualShutterSpeedDenominator = self.nearestShutterSpeedDenominator(to: self.manualShutterSpeedDenominator)
            }
        } catch let error as CameraConfigurationError {
            DispatchQueue.main.async {
                self.colorProfile = .unavailable
                self.canRecord = false
            }
            presentStatusMessage(error.message)
        } catch {
            DispatchQueue.main.async {
                self.colorProfile = .unavailable
                self.canRecord = false
            }
            presentStatusMessage("Camera configuration failed.")
        }
    }

    private func selectBestFormat(for device: AVCaptureDevice, targetFrameRate: Int) throws -> FormatSelection {
        let matchingFormats = device.formats.compactMap { format -> FormatSelection? in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            guard dimensions.width == required4KResolution.width,
                  dimensions.height == required4KResolution.height else {
                return nil
            }

            let supportsFrameRate = format.videoSupportedFrameRateRanges.contains {
                $0.minFrameRate <= Double(targetFrameRate) && Double(targetFrameRate) <= $0.maxFrameRate
            }
            guard supportsFrameRate else { return nil }

            let profile = bestProfile(for: format)
            guard profile != .unavailable else { return nil }

            let maxFrameRate = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
            let preferredStabilizationMode = preferredStabilizationAVMode(for: format)
            let supportsSelectedStabilization = selectedStabilizationMode == .off ||
                preferredStabilizationMode != .off

            guard supportsSelectedStabilization else { return nil }

            return FormatSelection(
                format: format,
                profile: profile,
                maxFrameRate: maxFrameRate,
                supportsSelectedStabilization: supportsSelectedStabilization,
                preferredStabilizationMode: preferredStabilizationMode,
                stabilizationStrength: stabilizationStrength(for: preferredStabilizationMode)
            )
        }

        guard let selection = matchingFormats.sorted(by: { lhs, rhs in
            if selectedStabilizationMode != .off,
               lhs.stabilizationStrength != rhs.stabilizationStrength {
                return lhs.stabilizationStrength > rhs.stabilizationStrength
            }
            if lhs.profile.priority == rhs.profile.priority {
                return lhs.maxFrameRate > rhs.maxFrameRate
            }
            return lhs.profile.priority > rhs.profile.priority
        }).first else {
            throw CameraConfigurationError(
                message: "Selected lens does not support 4K \(targetFrameRate) fps in Apple Log."
            )
        }

        return selection
    }

    private func bestProfile(for format: AVCaptureDevice.Format) -> CaptureColorProfile {
        let colorSpaces = supportedColorSpaces(for: format)
        if colorSpaces.contains(.appleLog2) {
            return .appleLog2
        }
        if colorSpaces.contains(.appleLog) {
            return .appleLog
        }
        return .unavailable
    }

    private func supportedColorSpaces(for format: AVCaptureDevice.Format) -> [AVCaptureColorSpace] {
        (format.supportedColorSpaces as NSArray).compactMap { rawValue in
            if let colorSpace = rawValue as? AVCaptureColorSpace {
                return colorSpace
            }
            if let number = rawValue as? NSNumber {
                return AVCaptureColorSpace(rawValue: number.intValue)
            }
            return nil
        }
    }

    private func configureOutput() {
        if let connection = videoDataOutput.connection(with: .video) {
            applyPreviewConnectionConfiguration(connection)
            observeActiveStabilizationMode(on: connection)
            refreshActiveStabilizationMode(from: connection)
        }
        DispatchQueue.main.async {
            self.canRecord = self.colorProfile != .unavailable
        }
    }

    func applyPreviewConnectionConfiguration(_ connection: AVCaptureConnection) {
        let captureDevice = videoInput?.device ?? activeDevice

        if connection.isVideoMirroringSupported {
            if connection.automaticallyAdjustsVideoMirroring {
                connection.automaticallyAdjustsVideoMirroring = false
            }
            connection.isVideoMirrored = captureDevice?.position == .front
        }

        if connection.isVideoStabilizationSupported {
            let preferredMode = preferredStabilizationAVMode(for: captureDevice?.activeFormat)
            connection.preferredVideoStabilizationMode = preferredMode
        }
    }

    private func preferredStabilizationAVMode(for format: AVCaptureDevice.Format?) -> AVCaptureVideoStabilizationMode {
        guard let format else { return .off }

        switch selectedStabilizationMode {
        case .off:
            return .off
        case .standard:
            return format.isVideoStabilizationModeSupported(.standard) ? .standard : .off
        case .cinematic:
            if format.isVideoStabilizationModeSupported(.cinematicExtendedEnhanced) {
                return .cinematicExtendedEnhanced
            }
            if format.isVideoStabilizationModeSupported(.cinematicExtended) {
                return .cinematicExtended
            }
            if format.isVideoStabilizationModeSupported(.cinematic) {
                return .cinematic
            }
            return .off
        }
    }

    private func refreshActiveStabilizationMode(from connection: AVCaptureConnection) {
        sessionQueue.asyncAfter(deadline: .now() + 0.15) {
            let activeAVMode = connection.activeVideoStabilizationMode
            let activeMode = CaptureStabilizationMode(avMode: activeAVMode)
            DispatchQueue.main.async {
                self.activeStabilizationMode = activeMode
                self.activeStabilizationTitle = CaptureStabilizationMode.title(for: activeAVMode)
                if self.selectedStabilizationMode != .off,
                   activeMode == .off {
                    self.presentStatusMessage("Selected stabilization is not active for the current lens/FPS/format.")
                }
            }
        }
    }

    private func observeActiveStabilizationMode(on connection: AVCaptureConnection) {
        activeVideoStabilizationObservation?.invalidate()
        activeVideoStabilizationObservation = connection.observe(
            \.activeVideoStabilizationMode,
            options: [.initial, .new]
        ) { [weak self] connection, _ in
            let activeAVMode = connection.activeVideoStabilizationMode
            let activeMode = CaptureStabilizationMode(avMode: activeAVMode)
            DispatchQueue.main.async {
                self?.activeStabilizationMode = activeMode
                self?.activeStabilizationTitle = CaptureStabilizationMode.title(for: activeAVMode)
            }
        }
    }

    private func stabilizationStrength(for mode: AVCaptureVideoStabilizationMode) -> Int {
        switch mode {
        case .cinematicExtendedEnhanced:
            return 4
        case .cinematicExtended:
            return 3
        case .cinematic:
            return 2
        case .standard:
            return 1
        default:
            return 0
        }
    }

    private func updateSupportedStabilizationModes(for format: AVCaptureDevice.Format) {
        var modes: [CaptureStabilizationMode] = [.off]

        if format.isVideoStabilizationModeSupported(.standard) {
            modes.append(.standard)
        }

        if format.isVideoStabilizationModeSupported(.cinematic) ||
            format.isVideoStabilizationModeSupported(.cinematicExtended) ||
            format.isVideoStabilizationModeSupported(.cinematicExtendedEnhanced) {
            modes.append(.cinematic)
        }

        DispatchQueue.main.async {
            self.supportedStabilizationModes = modes
            if !modes.contains(self.selectedStabilizationMode) {
                self.selectedStabilizationMode = .off
            }
        }
    }

    private func recommendedBitrate() -> Int {
        Int(recordingBitrateMbps * 1_000_000)
    }

    private func defaultBitrateMbps(for fps: Int) -> Double {
        switch fps {
        case 120:
            return 80
        case 60:
            return 50
        default:
            return 30
        }
    }

    private func prepareWriter(at fileURL: URL) throws {
        cleanupWriterState()

        let writer = try AVAssetWriter(outputURL: fileURL, fileType: .mov)
        let videoSettings = try makeVideoWriterSettings()
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoSettings
        )
        videoInput.expectsMediaDataInRealTime = true
        videoInput.transform = captureTransform(
            for: currentCaptureRotationAngle,
            sourceDimensions: activeVideoDimensions()
        )

        guard writer.canAdd(videoInput) else {
            throw CameraConfigurationError(message: "Cannot attach video writer input.")
        }
        writer.add(videoInput)

        var configuredAudioInput: AVAssetWriterInput?
        if let audioSettings = makeAudioWriterSettings() {
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = true
            if writer.canAdd(audioInput) {
                writer.add(audioInput)
                configuredAudioInput = audioInput
            }
        }

        assetWriter = writer
        videoWriterInput = videoInput
        audioWriterInput = configuredAudioInput
        currentRecordingURL = fileURL
        isWritingSessionStarted = false
    }

    private func makeVideoWriterSettings() throws -> [String: Any] {
        let dimensions = activeVideoDimensions()
        guard dimensions.width > 0, dimensions.height > 0 else {
            throw CameraConfigurationError(message: "No active video format is available for HEVC recording.")
        }
        return [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(dimensions.width),
            AVVideoHeightKey: Int(dimensions.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: recommendedBitrate(),
                AVVideoExpectedSourceFrameRateKey: selectedFrameRate,
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel as String
            ]
        ]
    }

    private func makeAudioWriterSettings() -> [String: Any]? {
        audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov)
    }

    private func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              let writer = assetWriter,
              let videoInput = videoWriterInput else { return }

        guard startWritingIfNeeded(with: writer, sampleBuffer: sampleBuffer) else { return }

        guard writer.status == .writing, videoInput.isReadyForMoreMediaData else { return }
        guard let retimedSampleBuffer = retimedVideoSampleBuffer(from: sampleBuffer) else { return }
        if !videoInput.append(retimedSampleBuffer) {
            handleWriterFailureIfNeeded(writer.error)
        }
    }

    private func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              let writer = assetWriter,
              let audioInput = audioWriterInput,
              isWritingSessionStarted else { return }

        guard writer.status == .writing, audioInput.isReadyForMoreMediaData else { return }
        guard let retimedSampleBuffer = retimedAudioSampleBuffer(from: sampleBuffer) else { return }
        if !audioInput.append(retimedSampleBuffer) {
            handleWriterFailureIfNeeded(writer.error)
        }
    }

    private func startWritingIfNeeded(with writer: AVAssetWriter, sampleBuffer: CMSampleBuffer) -> Bool {
        guard !isWritingSessionStarted else { return true }

        if writer.status == .failed {
            handleWriterFailureIfNeeded(writer.error)
            return false
        }

        if writer.status == .writing {
            return true
        }

        guard writer.status == .unknown else {
            handleWriterFailureIfNeeded(writer.error ?? CameraConfigurationError(message: "HEVC writer entered an invalid state."))
            return false
        }

        guard writer.startWriting() else {
            handleWriterFailureIfNeeded(writer.error ?? CameraConfigurationError(message: "AVAssetWriter could not start HEVC recording."))
            return false
        }

        recordingSourceStartTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        exactVideoFrameCount = 0
        writer.startSession(atSourceTime: .zero)
        isWritingSessionStarted = true
        return true
    }

    private func retimedVideoSampleBuffer(from sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(selectedFrameRate))
        let presentationTime = CMTime(value: exactVideoFrameCount, timescale: CMTimeScale(selectedFrameRate))
        exactVideoFrameCount += 1

        var timingInfo = CMSampleTimingInfo(
            duration: frameDuration,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )

        var retimedSampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &retimedSampleBuffer
        )

        guard status == noErr else {
            presentStatusMessage("Video timing normalization failed.")
            return nil
        }

        return retimedSampleBuffer
    }

    private func retimedAudioSampleBuffer(from sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        guard let recordingSourceStartTime else { return sampleBuffer }

        var timingCount = 0
        guard CMSampleBufferGetSampleTimingInfoArray(
            sampleBuffer,
            entryCount: 0,
            arrayToFill: nil,
            entriesNeededOut: &timingCount
        ) == noErr,
        timingCount > 0 else {
            return sampleBuffer
        }

        var timingInfo = Array(
            repeating: CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .invalid, decodeTimeStamp: .invalid),
            count: timingCount
        )

        guard CMSampleBufferGetSampleTimingInfoArray(
            sampleBuffer,
            entryCount: timingCount,
            arrayToFill: &timingInfo,
            entriesNeededOut: &timingCount
        ) == noErr else {
            return sampleBuffer
        }

        for index in timingInfo.indices {
            if timingInfo[index].presentationTimeStamp.isValid {
                timingInfo[index].presentationTimeStamp = CMTimeSubtract(
                    timingInfo[index].presentationTimeStamp,
                    recordingSourceStartTime
                )
            }

            if timingInfo[index].decodeTimeStamp.isValid {
                timingInfo[index].decodeTimeStamp = CMTimeSubtract(
                    timingInfo[index].decodeTimeStamp,
                    recordingSourceStartTime
                )
            }
        }

        if let firstPTS = timingInfo.first?.presentationTimeStamp,
           firstPTS.isValid,
           firstPTS < .zero {
            return nil
        }

        var retimedSampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: timingCount,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &retimedSampleBuffer
        )

        guard status == noErr else { return nil }
        return retimedSampleBuffer
    }

    private func finishWriting() {
        guard let writer = assetWriter else {
            restoreDeviceAfterRecording()
            return
        }

        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()
        let outputURL = currentRecordingURL

        writer.finishWriting { [weak self] in
            guard let self else { return }
            let error = self.assetWriter?.error
            self.restoreDeviceAfterRecording()
            self.cleanupWriterState()

            if let error {
                self.presentStatusMessage("Recording failed: \(error.localizedDescription)")
                return
            }

            guard let outputURL else { return }
            self.saveRecordingToPhotoLibrary(outputURL)
        }
    }

    private func cleanupWriterState() {
        assetWriter = nil
        videoWriterInput = nil
        audioWriterInput = nil
        currentRecordingURL = nil
        isWritingSessionStarted = false
        recordingSourceStartTime = nil
        exactVideoFrameCount = 0
    }

    private func handleWriterFailureIfNeeded(_ error: Error?) {
        guard let error else { return }

        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
        }

        cleanupWriterState()
        restoreDeviceAfterRecording()
        presentStatusMessage("Recording failed: \(error.localizedDescription)")
    }

    private func prepareDeviceForRecording() {
        guard let device = videoInput?.device ?? activeDevice else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if usesManualWhiteBalance {
                applyManualWhiteBalance(on: device)
            } else if whiteBalanceLockedDuringRecording, device.isWhiteBalanceModeSupported(.locked) {
                device.whiteBalanceMode = .locked
            }

            if proExposureEnabled, proExposureMode == .shutterAngle180 {
                // In 180 mode the preview path is already driving a custom shutter
                // with auto-ISO assistance. At record start we only stop that ISO
                // automation and keep the exact current exposure to avoid a visible
                // ISO jump in the first recorded frames.
            } else if proExposureEnabled {
                applyExposureConfiguration(on: device)
            } else if exposureLockedDuringRecording, device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
            } else if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            if manualFocusEnabled, device.isLockingFocusWithCustomLensPositionSupported {
                device.setFocusModeLocked(lensPosition: manualFocusPosition, completionHandler: nil)
            }
        } catch {
            presentStatusMessage("Unable to lock camera controls for recording.")
        }
    }

    private func restoreDeviceAfterRecording() {
        guard let device = videoInput?.device ?? activeDevice else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            applyWhiteBalanceState(on: device)

            applyExposureConfiguration(on: device)

            if manualFocusEnabled, device.isLockingFocusWithCustomLensPositionSupported {
                device.setFocusModeLocked(lensPosition: manualFocusPosition, completionHandler: nil)
            } else if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
        } catch {
            presentStatusMessage("Unable to restore camera controls after recording.")
        }

        updateProExposureAutomationState()
    }

    private func applyWhiteBalanceState(on device: AVCaptureDevice) {
        if usesManualWhiteBalance {
            applyManualWhiteBalance(on: device)
        } else if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        } else if device.isWhiteBalanceModeSupported(.autoWhiteBalance) {
            device.whiteBalanceMode = .autoWhiteBalance
        }
    }

    private func applyManualWhiteBalance(on device: AVCaptureDevice) {
        guard device.isWhiteBalanceModeSupported(.locked) else { return }

        let values = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
            temperature: Float(whiteBalanceTemperature),
            tint: 0
        )
        var gains = device.deviceWhiteBalanceGains(for: values)
        gains = normalizedWhiteBalanceGains(gains, for: device)
        device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
    }

    private func normalizedWhiteBalanceGains(_ gains: AVCaptureDevice.WhiteBalanceGains,
                                             for device: AVCaptureDevice) -> AVCaptureDevice.WhiteBalanceGains {
        AVCaptureDevice.WhiteBalanceGains(
            redGain: min(max(gains.redGain, 1.0), device.maxWhiteBalanceGain),
            greenGain: min(max(gains.greenGain, 1.0), device.maxWhiteBalanceGain),
            blueGain: min(max(gains.blueGain, 1.0), device.maxWhiteBalanceGain)
        )
    }

    private func restorePersistedSettings() {
        let defaults = UserDefaults.standard

        if let savedFrameRate = defaults.object(forKey: SettingsKey.selectedFrameRate) as? Int,
           Self.supportedFrameRates.contains(savedFrameRate) {
            selectedFrameRate = savedFrameRate
        }

        if let rawStabilization = defaults.string(forKey: SettingsKey.selectedStabilizationMode),
           let stabilization = CaptureStabilizationMode(rawValue: rawStabilization) {
            selectedStabilizationMode = stabilization
        }

        if let rawPreviewMode = defaults.string(forKey: SettingsKey.previewLookMode) {
            if rawPreviewMode == "normal" {
                previewLookMode = .rec709
                defaults.set(PreviewLookMode.rec709.rawValue, forKey: SettingsKey.previewLookMode)
            } else if let previewMode = PreviewLookMode(rawValue: rawPreviewMode) {
                previewLookMode = previewMode
            }
        }

        if defaults.object(forKey: SettingsKey.proExposureEnabled) != nil {
            proExposureEnabled = defaults.bool(forKey: SettingsKey.proExposureEnabled)
        }

        if let rawProMode = defaults.string(forKey: SettingsKey.proExposureMode),
           let mode = ProExposureMode(rawValue: rawProMode) {
            proExposureMode = mode
        }

        if defaults.object(forKey: SettingsKey.whiteBalanceLockedDuringRecording) != nil {
            whiteBalanceLockedDuringRecording = defaults.bool(forKey: SettingsKey.whiteBalanceLockedDuringRecording)
        }

        if defaults.object(forKey: SettingsKey.exposureLockedDuringRecording) != nil {
            exposureLockedDuringRecording = defaults.bool(forKey: SettingsKey.exposureLockedDuringRecording)
        }

        if let savedExposureBias = defaults.object(forKey: SettingsKey.exposureBias) as? Double {
            exposureBias = Float(savedExposureBias)
        }

        if let savedWhiteBalanceTemperature = defaults.object(forKey: SettingsKey.whiteBalanceTemperature) as? Double {
            whiteBalanceTemperature = savedWhiteBalanceTemperature
        }

        if defaults.object(forKey: SettingsKey.usesManualWhiteBalance) != nil {
            usesManualWhiteBalance = defaults.bool(forKey: SettingsKey.usesManualWhiteBalance)
        }

        if defaults.object(forKey: SettingsKey.manualFocusEnabled) != nil {
            manualFocusEnabled = defaults.bool(forKey: SettingsKey.manualFocusEnabled)
        }

        if let savedManualFocusPosition = defaults.object(forKey: SettingsKey.manualFocusPosition) as? Double {
            manualFocusPosition = Float(savedManualFocusPosition)
        }

        if let savedShutterDenominator = defaults.object(forKey: SettingsKey.manualShutterSpeedDenominator) as? Int {
            manualShutterSpeedDenominator = savedShutterDenominator
        } else {
            manualShutterSpeedDenominator = idealShutterSpeedDenominator(for: selectedFrameRate)
        }

        if let savedISO = defaults.object(forKey: SettingsKey.manualISO) as? Double {
            manualISO = Float(savedISO)
        }

        usesCustomBitrate = defaults.bool(forKey: SettingsKey.usesCustomBitrate)
        if usesCustomBitrate,
           let savedBitrate = defaults.object(forKey: SettingsKey.recordingBitrateMbps) as? Double,
           Self.supportedBitratesMbps.contains(where: { abs($0 - savedBitrate) < 0.001 }) {
            recordingBitrateMbps = savedBitrate
        } else {
            recordingBitrateMbps = defaultBitrateMbps(for: selectedFrameRate)
        }
    }

    private func updateFocus(at point: CGPoint, shouldLockAfterFocus: Bool) {
        sessionQueue.async {
            self.pendingFocusLockWorkItem?.cancel()
            guard let device = self.videoInput?.device ?? self.activeDevice else { return }

            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                }

                if !self.proExposureEnabled && device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                }

                if shouldLockAfterFocus {
                    if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                    }
                    if !self.proExposureEnabled && device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    }
                } else {
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                    if !self.proExposureEnabled && device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                }

                device.isSubjectAreaChangeMonitoringEnabled = !shouldLockAfterFocus

                guard shouldLockAfterFocus else { return }

                let lockWorkItem = DispatchWorkItem { [weak self] in
                    self?.lockFocusAndExposure()
                }
                self.pendingFocusLockWorkItem = lockWorkItem
                self.sessionQueue.asyncAfter(deadline: .now() + self.focusLockDelay, execute: lockWorkItem)
            } catch {
                self.presentStatusMessage("Tap-to-focus failed.")
            }
        }
    }

    private func lockFocusAndExposure() {
        pendingFocusLockWorkItem = nil
        guard let device = videoInput?.device ?? activeDevice else { return }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isLockingFocusWithCustomLensPositionSupported {
                device.setFocusModeLocked(lensPosition: device.lensPosition, completionHandler: nil)
                DispatchQueue.main.async {
                    self.manualFocusPosition = device.lensPosition
                }
            } else if device.isFocusModeSupported(.locked) {
                device.focusMode = .locked
            }

            if !proExposureEnabled && device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
            }
            device.isSubjectAreaChangeMonitoringEnabled = false
        } catch {
            presentStatusMessage("Lock focus failed.")
        }
    }

    private func setupCaptureRotationCoordinator(for device: AVCaptureDevice) {
        captureRotationObservation?.invalidate()
        captureRotationObservation = nil

        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        captureRotationCoordinator = coordinator
        applyCaptureRotation(coordinator.videoRotationAngleForHorizonLevelCapture)

        captureRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture,
            options: [.new]
        ) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            self?.sessionQueue.async {
                self?.applyCaptureRotation(angle)
            }
        }
    }

    private func applyCaptureRotation(_ angle: CGFloat) {
        currentCaptureRotationAngle = angle
    }

    private func captureTransform(for angle: CGFloat, sourceDimensions: CMVideoDimensions) -> CGAffineTransform {
        let normalizedAngle = Int(angle.rounded()) % 360
        let width = CGFloat(sourceDimensions.width)
        let height = CGFloat(sourceDimensions.height)

        switch normalizedAngle {
        case 90:
            return CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: height, ty: 0)
        case 180:
            return CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: width, ty: height)
        case 270:
            return CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: width)
        default:
            return .identity
        }
    }

    private func activeVideoDimensions() -> CMVideoDimensions {
        guard let formatDescription = (videoInput?.device ?? activeDevice)?.activeFormat.formatDescription else {
            return CMVideoDimensions(width: 0, height: 0)
        }
        return CMVideoFormatDescriptionGetDimensions(formatDescription)
    }

    private func startSession() {
        sessionQueue.async {
            guard self.isSessionConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
            self.configureOutput()
            self.updateProExposureAutomationState()
        }
    }

    private func stopSession() {
        sessionQueue.async {
            self.stopProExposureAutomation()
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func presentStatusMessage(_ message: String) {
        DispatchQueue.main.async {
            self.statusMessageDismissWorkItem?.cancel()
            self.statusMessage = message

            let dismissWorkItem = DispatchWorkItem { [weak self] in
                guard let self, self.statusMessage == message else { return }
                self.statusMessage = nil
            }

            self.statusMessageDismissWorkItem = dismissWorkItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: dismissWorkItem)
        }
    }

    private func publishPreviewFrame(from sampleBuffer: CMSampleBuffer) {
        guard colorProfile != .unavailable,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        previewFrameSubject.send(
            PreviewFrame(
                pixelBuffer: pixelBuffer,
                profile: colorProfile,
                yCbCrMatrix: previewYCbCrMatrix(for: pixelBuffer),
                isFullRange: isFullRangePixelBuffer(pixelBuffer)
            )
        )
    }

    private func previewYCbCrMatrix(for pixelBuffer: CVPixelBuffer) -> PreviewYCbCrMatrix {
        guard let attachment = CVBufferCopyAttachment(
            pixelBuffer,
            kCVImageBufferYCbCrMatrixKey,
            nil
        ) else {
            return .rec709
        }

        if CFEqual(attachment, kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
            return .rec601
        }

        return .rec709
    }

    private func isFullRangePixelBuffer(_ pixelBuffer: CVPixelBuffer) -> Bool {
        switch CVPixelBufferGetPixelFormatType(pixelBuffer) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
            return true
        default:
            return false
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        if output === self.videoDataOutput {
            self.publishPreviewFrame(from: sampleBuffer)
            self.appendVideoSampleBuffer(sampleBuffer)
        } else if output === self.audioDataOutput {
            self.appendAudioSampleBuffer(sampleBuffer)
        }
    }
}

extension CameraManager {
    fileprivate func saveRecordingToPhotoLibrary(_ fileURL: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                self.presentStatusMessage("Video was recorded but Photos access is not allowed.")
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            } completionHandler: { success, error in
                if let error {
                    self.presentStatusMessage("Could not save video: \(error.localizedDescription)")
                    return
                }

                if success {
                    self.presentStatusMessage("Saved to Photos.")
                }
            }
        }
    }
}

private struct FormatSelection {
    let format: AVCaptureDevice.Format
    let profile: CaptureColorProfile
    let maxFrameRate: Double
    let supportsSelectedStabilization: Bool
    let preferredStabilizationMode: AVCaptureVideoStabilizationMode
    let stabilizationStrength: Int
}

private struct CameraConfigurationError: Error {
    let message: String
}
