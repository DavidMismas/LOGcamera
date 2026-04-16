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
    let selectorID: String
    let deviceUniqueID: String
    let displayName: String
    let shortName: String
    let selectorTitle: String
    let deviceType: AVCaptureDevice.DeviceType
    let position: AVCaptureDevice.Position
    let zoomFactor: CGFloat
    let sortOrder: Int
    let cycleOrder: Int
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

enum CaptureMode: String, CaseIterable, Identifiable {
    case video
    case photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .video:
            return "Video"
        case .photo:
            return "Photo"
        }
    }

    var switchButtonTitle: String {
        switch self {
        case .video:
            return "PHOTO"
        case .photo:
            return "VIDEO"
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

enum PhotoProExposureMode: String, CaseIterable, Identifiable {
    case auto
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .manual:
            return "Manual"
        }
    }
}

enum VideoRecordingCodec: String, CaseIterable, Identifiable {
    case hevc
    case proResLT
    case proResHQ

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hevc:
            return "HEVC"
        case .proResLT:
            return "ProRes LT"
        case .proResHQ:
            return "ProRes HQ"
        }
    }

    var codecType: AVVideoCodecType {
        switch self {
        case .hevc:
            return .hevc
        case .proResLT:
            return AVVideoCodecType(rawValue: "apcs")
        case .proResHQ:
            return AVVideoCodecType(rawValue: "apch")
        }
    }

    var supportsManualBitrate: Bool {
        self == .hevc
    }
}

enum PhotoCompanionFormat: String, CaseIterable, Identifiable {
    case dngOnly
    case dngPlusHEIC
    case dngPlusJPEG

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dngOnly:
            return "DNG"
        case .dngPlusHEIC:
            return "DNG + HEIC"
        case .dngPlusJPEG:
            return "DNG + JPEG"
        }
    }

    var processedFileType: AVFileType? {
        switch self {
        case .dngOnly:
            return nil
        case .dngPlusHEIC:
            return .heic
        case .dngPlusJPEG:
            return .jpg
        }
    }

    var processedCodecType: AVVideoCodecType? {
        switch self {
        case .dngOnly:
            return nil
        case .dngPlusHEIC:
            return .hevc
        case .dngPlusJPEG:
            return .jpeg
        }
    }
}

enum PhotoResolutionOption: String, CaseIterable, Identifiable {
    case full
    case twelveMP

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full:
            return "Full"
        case .twelveMP:
            return "12 MP"
        }
    }
}

final class CameraManager: NSObject, ObservableObject {
    private enum SettingsKey {
        static let captureMode = "camera.captureMode"
        static let defaultCaptureMode = "camera.defaultCaptureMode"
        static let selectedFrameRate = "camera.selectedFrameRate"
        static let whiteBalanceLockedDuringRecording = "camera.whiteBalanceLockedDuringRecording"
        static let exposureLockedDuringRecording = "camera.exposureLockedDuringRecording"
        static let selectedStabilizationMode = "camera.selectedStabilizationMode"
        static let selectedVideoCodec = "camera.selectedVideoCodec"
        static let recordingBitrateMbps = "camera.recordingBitrateMbps"
        static let usesCustomBitrate = "camera.usesCustomBitrate"
        static let exposureBias = "camera.exposureBias"
        static let videoWhiteBalanceTemperature = "camera.whiteBalanceTemperature"
        static let videoUsesManualWhiteBalance = "camera.usesManualWhiteBalance"
        static let photoWhiteBalanceTemperature = "camera.photoWhiteBalanceTemperature"
        static let photoUsesManualWhiteBalance = "camera.photoUsesManualWhiteBalance"
        static let manualFocusEnabled = "camera.manualFocusEnabled"
        static let manualFocusPosition = "camera.manualFocusPosition"
        static let photoCompanionFormat = "camera.photoCompanionFormat"
        static let photoResolutionOption = "camera.photoResolutionOption"
        static let previewLookMode = "camera.previewLookMode"
        static let zebraEnabled = "camera.zebraEnabled"
        static let proExposureEnabled = "camera.proExposureEnabled"
        static let proExposureMode = "camera.proExposureMode"
        static let manualShutterSpeedDenominator = "camera.manualShutterSpeedDenominator"
        static let manualISO = "camera.manualISO"
        static let photoProExposureEnabled = "camera.photoProExposureEnabled"
        static let photoProExposureMode = "camera.photoProExposureMode"
        static let photoManualShutterSpeedDenominator = "camera.photoManualShutterSpeedDenominator"
        static let photoManualISO = "camera.photoManualISO"
    }

    static let supportedFrameRates = [24, 25, 30, 60, 120]
    static let supportedBitratesMbps: [Double] = [30, 50, 80]

    @Published var session = AVCaptureSession()
    @Published private(set) var isAuthorized = false
    @Published private(set) var availableLenses: [LensOption] = []
    @Published private(set) var activeLensID: String?
    @Published private(set) var activeDevice: AVCaptureDevice?
    @Published private(set) var focusFeedback: FocusFeedback?
    @Published private(set) var isFocusExposureLocked = false
    @Published private(set) var canRecord = false
    @Published private(set) var canCapturePhoto = false
    @Published private(set) var colorProfile: CaptureColorProfile = .unavailable
    @Published private(set) var exposureBias: Float = 0
    @Published private(set) var manualFocusEnabled = false
    @Published private(set) var manualFocusPosition: Float = 0.5
    @Published private(set) var supportsManualFocus = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var recordedVideoURL: URL?
    @Published private(set) var isRecording = false
    @Published private(set) var isPhotoCaptureInProgress = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var videoWhiteBalanceTemperature = 5600.0
    @Published private(set) var videoUsesManualWhiteBalance = false
    @Published private(set) var photoWhiteBalanceTemperature = 5600.0
    @Published private(set) var photoUsesManualWhiteBalance = false
    @Published private(set) var appleProRAWSupported = false
    @Published private(set) var appleProRAWEnabled = false
    @Published var photoCompanionFormat: PhotoCompanionFormat = .dngOnly {
        didSet { UserDefaults.standard.set(photoCompanionFormat.rawValue, forKey: SettingsKey.photoCompanionFormat) }
    }
    @Published var photoResolutionOption: PhotoResolutionOption = .full {
        didSet { UserDefaults.standard.set(photoResolutionOption.rawValue, forKey: SettingsKey.photoResolutionOption) }
    }

    @Published var captureMode: CaptureMode = .video {
        didSet { UserDefaults.standard.set(captureMode.rawValue, forKey: SettingsKey.captureMode) }
    }
    @Published var defaultCaptureMode: CaptureMode = .video {
        didSet { UserDefaults.standard.set(defaultCaptureMode.rawValue, forKey: SettingsKey.defaultCaptureMode) }
    }
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
    @Published var selectedVideoCodec: VideoRecordingCodec = .hevc {
        didSet { UserDefaults.standard.set(selectedVideoCodec.rawValue, forKey: SettingsKey.selectedVideoCodec) }
    }
    @Published var previewLookMode: PreviewLookMode = .log {
        didSet {
            UserDefaults.standard.set(previewLookMode.rawValue, forKey: SettingsKey.previewLookMode)
        }
    }
    @Published var zebraEnabled = false {
        didSet { UserDefaults.standard.set(zebraEnabled, forKey: SettingsKey.zebraEnabled) }
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
    @Published var photoProExposureEnabled = false {
        didSet { UserDefaults.standard.set(photoProExposureEnabled, forKey: SettingsKey.photoProExposureEnabled) }
    }
    @Published var photoProExposureMode: PhotoProExposureMode = .auto {
        didSet { UserDefaults.standard.set(photoProExposureMode.rawValue, forKey: SettingsKey.photoProExposureMode) }
    }
    @Published private(set) var photoManualShutterSpeedDenominator = 125
    @Published private(set) var photoManualISO: Float = 100

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
        let candidates = photoShutterSpeedCandidates(for: captureMode)
        guard let device = activeDevice else { return candidates }

        let minDuration = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
        let maxDuration: Double
        switch captureMode {
        case .video:
            maxDuration = min(
                CMTimeGetSeconds(device.activeFormat.maxExposureDuration),
                1.0 / Double(max(selectedFrameRate, 1))
            )
        case .photo:
            maxDuration = CMTimeGetSeconds(device.activeFormat.maxExposureDuration)
        }

        let filtered = candidates.filter { denominator in
            let duration = 1.0 / Double(denominator)
            return duration >= minDuration && duration <= maxDuration
        }

        switch captureMode {
        case .video:
            let ideal = idealShutterSpeedDenominator(for: selectedFrameRate)
            let combined = Set(filtered + [ideal, selectedFrameRate, manualShutterSpeedDenominator])
            return combined.sorted()
        case .photo:
            let combined = Set(filtered + [photoManualShutterSpeedDenominator])
            return combined.sorted()
        }
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
        switch captureMode {
        case .video:
            return proExposureMode == .shutterAngle180 ? "Auto" : String(format: "%.0f", manualISO)
        case .photo:
            return String(format: "%.0f", photoManualISO)
        }
    }

    var supportsExposureBiasAdjustment: Bool {
        switch captureMode {
        case .video:
            return !proExposureEnabled || proExposureMode == .auto
        case .photo:
            return !photoProExposureEnabled
        }
    }

    var isCurrentProExposureEnabled: Bool {
        captureMode == .photo ? photoProExposureEnabled : proExposureEnabled
    }

    var currentShutterSpeedDenominator: Int {
        switch captureMode {
        case .video:
            return proExposureMode == .shutterAngle180
                ? idealShutterSpeedDenominator(for: selectedFrameRate)
                : manualShutterSpeedDenominator
        case .photo:
            return photoManualShutterSpeedDenominator
        }
    }

    var colorProfileTitle: String {
        colorProfile.title
    }

    var captureSummaryText: String {
        switch captureMode {
        case .video:
            return "4K • \(selectedFrameRate) fps • \(selectedVideoCodec.title) • \(colorProfile.title)"
        case .photo:
            return appleProRAWEnabled ? "ProRAW DNG" : "ProRAW Unavailable"
        }
    }

    var photoBadgeTitle: String {
        guard appleProRAWEnabled else { return "RAW Off" }

        switch photoCompanionFormat {
        case .dngOnly:
            return "ProRAW"
        case .dngPlusHEIC:
            return "ProRAW + HEIC"
        case .dngPlusJPEG:
            return "ProRAW + JPG"
        }
    }

    var activeLensSummary: String {
        guard let lens = lensOptions.first(where: { $0.id == activeLensID }) else {
            return "No lens selected"
        }
        return lens.displayName
    }

    var lensPickerOptions: [LensOption] {
        var seenSelectorIDs = Set<String>()
        return availableLenses.filter { lens in
            seenSelectorIDs.insert(lens.selectorID).inserted
        }
    }

    var activeLensSelectorID: String? {
        lensOptions.first(where: { $0.id == activeLensID })?.selectorID
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

    var allowsCustomBitrate: Bool {
        selectedVideoCodec.supportsManualBitrate
    }

    var previewAspectRatio: CGFloat {
        captureMode == .photo ? (3.0 / 4.0) : (9.0 / 16.0)
    }

    var canTriggerCapture: Bool {
        switch captureMode {
        case .video:
            return canRecord || isRecording
        case .photo:
            return canCapturePhoto && !isPhotoCaptureInProgress
        }
    }

    var isCaptureBusy: Bool {
        isRecording || isPhotoCaptureInProgress
    }

    var whiteBalanceLabel: String {
        usesManualWhiteBalance(for: captureMode) ? String(format: "%.0f K", whiteBalanceTemperature) : "Auto"
    }

    var whiteBalanceTemperature: Double {
        switch captureMode {
        case .video:
            return videoWhiteBalanceTemperature
        case .photo:
            return photoWhiteBalanceTemperature
        }
    }

    var usesManualWhiteBalance: Bool {
        switch captureMode {
        case .video:
            return videoUsesManualWhiteBalance
        case .photo:
            return photoUsesManualWhiteBalance
        }
    }

    private func whiteBalanceTemperature(for mode: CaptureMode) -> Double {
        switch mode {
        case .video:
            return videoWhiteBalanceTemperature
        case .photo:
            return photoWhiteBalanceTemperature
        }
    }

    private func usesManualWhiteBalance(for mode: CaptureMode) -> Bool {
        switch mode {
        case .video:
            return videoUsesManualWhiteBalance
        case .photo:
            return photoProExposureEnabled && photoUsesManualWhiteBalance
        }
    }

    private let required4KResolution = CMVideoDimensions(width: 3840, height: 2160)
    private let sessionQueue = DispatchQueue(label: "com.logcamera.sessionQueue")
    private let feedbackDuration: TimeInterval = 2.0
    private let focusLockDelay: TimeInterval = 0.2
    private let autoExposureSettleMaximumDuration: TimeInterval = 0.75
    private let autoExposureSettleOffsetThreshold: Float = 0.12
    private let defaultAutoExposureRectOfInterest = CGRect(x: 0.18, y: 0.18, width: 0.64, height: 0.64)
    private let tappedAutoExposureRectSize: CGFloat = 0.28

    private var isSessionConfigured = false
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let audioDataOutput = AVCaptureAudioDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var deviceRegistry: [String: AVCaptureDevice] = [:]
    private var lensOptions: [LensOption] = []
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
    private var pendingRecordingLeadInStartTime: CMTime?
    private var currentCaptureRotationAngle: CGFloat = 0
    private let previewFrameSubject = PassthroughSubject<PreviewFrame, Never>()
    private var proExposureAutomationTimer: DispatchSourceTimer?
    private var activePhotoProcessors: [Int64: PhotoCaptureProcessor] = [:]

    var previewFramePublisher: AnyPublisher<PreviewFrame, Never> {
        previewFrameSubject.eraseToAnyPublisher()
    }

    override init() {
        super.init()
        restorePersistedSettings()
        purgeTemporaryCaptureFiles()
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
        guard captureMode == .photo || supportedStabilizationModes.contains(mode) else {
            return
        }
        selectedStabilizationMode = mode
        if captureMode == .video {
            reconfigureActiveLens()
        }
    }

    func selectVideoCodec(_ codec: VideoRecordingCodec) {
        selectedVideoCodec = codec
    }

    func selectDefaultCaptureMode(_ mode: CaptureMode) {
        defaultCaptureMode = mode
    }

    func selectPhotoCompanionFormat(_ format: PhotoCompanionFormat) {
        photoCompanionFormat = format
    }

    func selectPhotoResolutionOption(_ option: PhotoResolutionOption) {
        photoResolutionOption = option
        if isSessionConfigured {
            reconfigureActiveLens()
        }
    }

    func selectPreviewLookMode(_ mode: PreviewLookMode) {
        previewLookMode = mode
    }

    func setProExposureEnabled(_ isEnabled: Bool) {
        if captureMode == .photo {
            photoProExposureEnabled = isEnabled
            if isEnabled, photoProExposureMode != .manual {
                photoProExposureMode = .manual
            }
        } else {
            proExposureEnabled = isEnabled
        }
        syncExposureConfiguration()
        if captureMode == .photo {
            syncWhiteBalanceConfiguration(mode: .photo)
        }
    }

    func selectProExposureMode(_ mode: ProExposureMode) {
        proExposureMode = mode
        if mode == .shutterAngle180 {
            manualShutterSpeedDenominator = idealShutterSpeedDenominator(for: selectedFrameRate)
            UserDefaults.standard.set(manualShutterSpeedDenominator, forKey: SettingsKey.manualShutterSpeedDenominator)
        }
        syncExposureConfiguration()
    }

    func selectPhotoProExposureMode(_ mode: PhotoProExposureMode) {
        photoProExposureMode = mode
        syncExposureConfiguration()
    }

    func setManualShutterSpeedDenominator(_ denominator: Int) {
        let nearest = nearestShutterSpeedDenominator(to: denominator)
        if captureMode == .photo {
            photoManualShutterSpeedDenominator = nearest
            UserDefaults.standard.set(nearest, forKey: SettingsKey.photoManualShutterSpeedDenominator)
        } else {
            manualShutterSpeedDenominator = nearest
            UserDefaults.standard.set(nearest, forKey: SettingsKey.manualShutterSpeedDenominator)
        }
        syncExposureConfiguration()
    }

    func setManualISO(_ value: Float) {
        let clamped = min(max(value, isoRange.lowerBound), isoRange.upperBound)
        if captureMode == .photo {
            photoManualISO = clamped
            UserDefaults.standard.set(Double(clamped), forKey: SettingsKey.photoManualISO)
        } else {
            manualISO = clamped
            UserDefaults.standard.set(Double(clamped), forKey: SettingsKey.manualISO)
        }
        syncExposureConfiguration()
    }

    func setRecordingBitrateMbps(_ value: Double) {
        guard allowsCustomBitrate else { return }
        guard let supportedValue = Self.supportedBitratesMbps.first(where: { abs($0 - value) < 0.001 }) else { return }
        recordingBitrateMbps = supportedValue
        usesCustomBitrate = true
        let defaults = UserDefaults.standard
        defaults.set(recordingBitrateMbps, forKey: SettingsKey.recordingBitrateMbps)
        defaults.set(usesCustomBitrate, forKey: SettingsKey.usesCustomBitrate)
    }

    func resetRecordingBitrateToDefault() {
        guard allowsCustomBitrate else { return }
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

    private func syncWhiteBalanceConfiguration(mode: CaptureMode? = nil) {
        sessionQueue.async {
            guard let device = self.videoInput?.device ?? self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                self.applyWhiteBalanceState(on: device, mode: mode)
                device.unlockForConfiguration()
            } catch {
                self.presentStatusMessage("White balance update failed.")
            }
        }
    }

    func switchLens(to lensID: String) {
        guard !isCaptureBusy else { return }
        sessionQueue.async {
            guard let lens = self.lensOptions.first(where: { $0.id == lensID }),
                  let device = self.deviceRegistry[lensID] else { return }
            self.session.beginConfiguration()
            var shouldRefreshOutput = false
            defer {
                self.session.commitConfiguration()
                if shouldRefreshOutput {
                    self.configureOutput()
                }
            }

            if self.videoInput?.device.uniqueID == lens.deviceUniqueID {
                self.configureDeviceForCurrentSelection(inConfiguration: true, preferredLens: lens)
                shouldRefreshOutput = true
                return
            }

            if let currentInput = self.videoInput {
                self.session.removeInput(currentInput)
                self.videoInput = nil
            }

            guard self.installVideoInput(device: device) else {
                self.presentStatusMessage("Failed to activate selected lens.")
                return
            }

            self.configureDeviceForCurrentSelection(inConfiguration: true, preferredLens: lens)
            shouldRefreshOutput = true
        }
    }

    func handleLensPickerTap(selectorID: String) {
        guard !isCaptureBusy else { return }

        let matchingOptions = lensOptions
            .filter { $0.selectorID == selectorID }
            .sorted { lhs, rhs in
                if lhs.cycleOrder == rhs.cycleOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.cycleOrder < rhs.cycleOrder
            }

        guard let firstOption = matchingOptions.first else { return }

        if let activeLensID,
           let activeIndex = matchingOptions.firstIndex(where: { $0.id == activeLensID }) {
            let nextIndex = (activeIndex + 1) % matchingOptions.count
            switchLens(to: matchingOptions[nextIndex].id)
            return
        }

        switchLens(to: firstOption.id)
    }

    func lensPickerTitle(for lens: LensOption) -> String {
        guard let activeLens = lensOptions.first(where: { $0.id == activeLensID }),
              activeLens.selectorID == lens.selectorID else {
            return lens.selectorTitle
        }
        return activeLens.selectorTitle
    }

    func switchCaptureMode() {
        guard !isCaptureBusy else { return }
        let nextMode: CaptureMode = captureMode == .video ? .photo : .video
        captureMode = nextMode
        sessionQueue.async {
            self.stopProExposureAutomation()
            guard self.isSessionConfigured else { return }
            let currentDevice = self.videoInput?.device ?? self.activeDevice
            self.session.beginConfiguration()
            self.session.sessionPreset = nextMode == .photo ? .photo : .inputPriority
            if let currentInput = self.videoInput {
                self.session.removeInput(currentInput)
                self.videoInput = nil
            }
            if let currentDevice {
                guard self.installVideoInput(device: currentDevice) else {
                    self.presentStatusMessage("Failed to reconfigure camera for \(nextMode.title.lowercased()) mode.")
                    self.session.commitConfiguration()
                    return
                }
            }
            self.configureDeviceForCurrentSelection(inConfiguration: true)
            self.session.commitConfiguration()
            self.configureOutput()
        }
    }

    func triggerPrimaryCapture() {
        switch captureMode {
        case .video:
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        case .photo:
            capturePhoto()
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

    private func photoShutterSpeedCandidates(for mode: CaptureMode) -> [Int] {
        switch mode {
        case .video:
            return [
                24, 25, 30, 40, 48, 50, 60, 72, 80, 90, 96, 100,
                120, 125, 144, 160, 180, 192, 200, 240, 250, 288, 320,
                360, 400, 480, 500, 576, 640, 720, 800, 960, 1000, 1200,
                1600, 2000, 3200, 4000, 8000
            ]
        case .photo:
            return [
                2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 24, 25, 30, 40, 48, 50,
                60, 72, 80, 90, 96, 100, 120, 125, 144, 160, 180, 192, 200,
                240, 250, 288, 320, 360, 400, 480, 500, 576, 640, 720, 800,
                960, 1000, 1200, 1600, 2000, 3200, 4000, 8000
            ]
        }
    }

    private func clampedShutterDuration(for denominator: Int,
                                        device: AVCaptureDevice,
                                        captureMode: CaptureMode? = nil) -> CMTime {
        let requestedSeconds = 1.0 / Double(max(denominator, 1))
        let minSeconds = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
        let targetMode = captureMode ?? self.captureMode
        let formatMaxSeconds = CMTimeGetSeconds(device.activeFormat.maxExposureDuration)
        let maxSeconds: Double

        switch targetMode {
        case .video:
            maxSeconds = min(
                formatMaxSeconds,
                1.0 / Double(max(selectedFrameRate, 1))
            )
        case .photo:
            maxSeconds = formatMaxSeconds
        }

        let clampedSeconds = min(max(requestedSeconds, minSeconds), maxSeconds)
        return CMTime(seconds: clampedSeconds, preferredTimescale: 1_000_000)
    }

    private func clampedISO(_ iso: Float, for device: AVCaptureDevice) -> Float {
        min(max(iso, device.activeFormat.minISO), device.activeFormat.maxISO)
    }

    private func applyExposureConfiguration(on device: AVCaptureDevice) {
        switch captureMode {
        case .video where proExposureEnabled && proExposureMode == .shutterAngle180:
            let duration = clampedShutterDuration(
                for: idealShutterSpeedDenominator(for: selectedFrameRate),
                device: device
            )
            device.setExposureModeCustom(
                duration: duration,
                iso: AVCaptureDevice.currentISO,
                completionHandler: nil
            )

        case .video where proExposureEnabled && proExposureMode == .manual:
            let duration = clampedShutterDuration(
                for: manualShutterSpeedDenominator,
                device: device
            )
            device.setExposureModeCustom(
                duration: duration,
                iso: clampedISO(manualISO, for: device),
                completionHandler: nil
            )

        case .photo where photoProExposureEnabled && photoProExposureMode == .manual:
            let duration = clampedShutterDuration(
                for: photoManualShutterSpeedDenominator,
                device: device
            )
            device.setExposureModeCustom(
                duration: duration,
                iso: clampedISO(photoManualISO, for: device),
                completionHandler: nil
            )

        default:
            applyDefaultAutoExposureRegion(on: device)
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            } else if device.isExposureModeSupported(.autoExpose) {
                device.exposureMode = .autoExpose
            }
            device.setExposureTargetBias(exposureBias) { _ in }
        }
    }

    private func photoManualExposureValues(for device: AVCaptureDevice) -> (duration: CMTime, iso: Float)? {
        guard captureMode == .photo, photoProExposureEnabled else { return nil }

        let duration = clampedShutterDuration(
            for: photoManualShutterSpeedDenominator,
            device: device,
            captureMode: .photo
        )
        let iso = clampedISO(photoManualISO, for: device)
        return (duration, iso)
    }

    private func preparePhotoExposureForCapture(on device: AVCaptureDevice,
                                                completion: @escaping () -> Void) {
        guard let manualExposure = photoManualExposureValues(for: device) else {
            completion()
            return
        }

        let currentDurationSeconds = CMTimeGetSeconds(device.exposureDuration)
        let targetDurationSeconds = CMTimeGetSeconds(manualExposure.duration)
        let durationMatches = abs(currentDurationSeconds - targetDurationSeconds) < 0.0005
        let isoMatches = abs(device.iso - manualExposure.iso) < 0.5

        guard device.exposureMode != .custom || !durationMatches || !isoMatches else {
            completion()
            return
        }

        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: manualExposure.duration, iso: manualExposure.iso) { [weak self] _ in
                self?.sessionQueue.async {
                    completion()
                }
            }
            device.unlockForConfiguration()
        } catch {
            presentStatusMessage("Photo exposure lock failed.")
            completion()
        }
    }

    private func preparePhotoWhiteBalanceForCapture(on device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            applyWhiteBalanceState(on: device, mode: .photo)
            device.unlockForConfiguration()
        } catch {
            presentStatusMessage("Photo white balance update failed.")
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

    private func lockCurrentExposureForRecording(on device: AVCaptureDevice) {
        let duration = device.exposureDuration
        let iso = clampedISO(device.iso, for: device)
        device.setExposureModeCustom(duration: duration, iso: iso, completionHandler: nil)
    }

    private func applyDefaultAutoExposureRegion(on device: AVCaptureDevice) {
        guard !isFocusExposureLocked else { return }

        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
        }
        if device.isExposureRectOfInterestSupported {
            device.exposureRectOfInterest = defaultAutoExposureRectOfInterest
        }
    }

    private func autoExposureRect(around point: CGPoint) -> CGRect {
        let halfSize = tappedAutoExposureRectSize / 2
        let originX = min(max(point.x - halfSize, 0), 1 - tappedAutoExposureRectSize)
        let originY = min(max(point.y - halfSize, 0), 1 - tappedAutoExposureRectSize)
        return CGRect(
            x: originX,
            y: originY,
            width: tappedAutoExposureRectSize,
            height: tappedAutoExposureRectSize
        )
    }

    func setWhiteBalanceTemperature(_ value: Double) {
        let mode = captureMode
        let clamped = min(max(value, whiteBalanceTemperatureRange.lowerBound), whiteBalanceTemperatureRange.upperBound)
        let defaults = UserDefaults.standard
        switch mode {
        case .video:
            videoWhiteBalanceTemperature = clamped
            videoUsesManualWhiteBalance = true
            defaults.set(videoWhiteBalanceTemperature, forKey: SettingsKey.videoWhiteBalanceTemperature)
            defaults.set(videoUsesManualWhiteBalance, forKey: SettingsKey.videoUsesManualWhiteBalance)
        case .photo:
            photoWhiteBalanceTemperature = clamped
            photoUsesManualWhiteBalance = true
            defaults.set(photoWhiteBalanceTemperature, forKey: SettingsKey.photoWhiteBalanceTemperature)
            defaults.set(photoUsesManualWhiteBalance, forKey: SettingsKey.photoUsesManualWhiteBalance)
        }

        sessionQueue.async {
            guard let device = self.videoInput?.device ?? self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                self.applyWhiteBalanceState(on: device, mode: mode)
                device.unlockForConfiguration()
            } catch {
                self.presentStatusMessage("White balance update failed.")
            }
        }
    }

    func setWhiteBalanceAuto() {
        let mode = captureMode
        let defaults = UserDefaults.standard
        switch mode {
        case .video:
            videoUsesManualWhiteBalance = false
            defaults.set(videoUsesManualWhiteBalance, forKey: SettingsKey.videoUsesManualWhiteBalance)
        case .photo:
            photoUsesManualWhiteBalance = false
            defaults.set(photoUsesManualWhiteBalance, forKey: SettingsKey.photoUsesManualWhiteBalance)
        }

        sessionQueue.async {
            guard let device = self.videoInput?.device ?? self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                self.applyWhiteBalanceState(on: device, mode: mode)
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
        guard captureMode == .video else { return }
        guard !isRecording else { return }
        guard canRecord else {
            presentStatusMessage("Current lens or FPS does not support 4K video capture with the current settings.")
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

    func capturePhoto() {
        guard captureMode == .photo else { return }
        guard !isPhotoCaptureInProgress else { return }
        guard canCapturePhoto else {
            presentStatusMessage("ProRAW capture is unavailable for the current lens.")
            return
        }

        sessionQueue.async {
            guard !self.isPhotoCaptureInProgress else { return }
            guard let settings = self.makePhotoSettings() else {
                self.presentStatusMessage("Could not configure ProRAW capture.")
                return
            }
            guard let device = self.videoInput?.device ?? self.activeDevice else {
                self.presentStatusMessage("Camera unavailable.")
                return
            }

            self.preparePhotoWhiteBalanceForCapture(on: device)
            self.preparePhotoExposureForCapture(on: device) {
                settings.photoQualityPrioritization = .quality
                if let connection = self.photoOutput.connection(with: .video),
                   connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = (self.videoInput?.device ?? self.activeDevice)?.position == .front
                }

                let captureID = settings.uniqueID
                let processor = PhotoCaptureProcessor(processedFileType: settings.processedFileType) { [weak self] captureResult in
                    guard let self else { return }
                    self.sessionQueue.async {
                        self.activePhotoProcessors[captureID] = nil
                    }
                    DispatchQueue.main.async {
                        self.isPhotoCaptureInProgress = false
                    }

                    guard let captureResult else {
                        self.presentStatusMessage("RAW capture failed.")
                        return
                    }

                    self.saveCapturedPhotoToPhotoLibrary(captureResult)
                }

                self.activePhotoProcessors[captureID] = processor
                DispatchQueue.main.async {
                    self.isPhotoCaptureInProgress = true
                }
                self.photoOutput.capturePhoto(with: settings, delegate: processor)
            }
        }
    }

    private func preferredAppleProRAWPixelFormatForCapture() -> OSType? {
        guard #available(iOS 14.3, *) else { return nil }
        guard photoOutput.isAppleProRAWEnabled else { return nil }
        return photoOutput.availableRawPhotoPixelFormatTypes.first(where: AVCapturePhotoOutput.isAppleProRAWPixelFormat)
    }

    private func makePhotoSettings() -> AVCapturePhotoSettings? {
        guard let rawPixelType = preferredAppleProRAWPixelFormatForCapture() else { return nil }
        let processedConfiguration: ProcessedPhotoCaptureConfiguration?

        switch photoCompanionFormat {
        case .dngOnly:
            processedConfiguration = nil
        default:
            guard let configuration = processedPhotoCaptureConfiguration(for: photoCompanionFormat) else {
                presentStatusMessage("\(photoCompanionFormat.title) is unavailable on the current device.")
                return nil
            }
            processedConfiguration = configuration
        }

        let settings: AVCapturePhotoSettings
        if photoProExposureEnabled,
           let device = videoInput?.device ?? activeDevice,
           let manualExposure = photoManualExposureValues(for: device) {
            let bracketSetting = AVCaptureManualExposureBracketedStillImageSettings.manualExposureSettings(
                exposureDuration: manualExposure.duration,
                iso: manualExposure.iso
            )

            if let processedConfiguration {
                settings = AVCapturePhotoBracketSettings(
                    rawPixelFormatType: rawPixelType,
                    rawFileType: .dng,
                    processedFormat: processedConfiguration.format,
                    processedFileType: processedConfiguration.fileType,
                    bracketedSettings: [bracketSetting]
                )
            } else {
                settings = AVCapturePhotoBracketSettings(
                    rawPixelFormatType: rawPixelType,
                    rawFileType: .dng,
                    processedFormat: nil,
                    processedFileType: nil,
                    bracketedSettings: [bracketSetting]
                )
            }
        } else if let processedConfiguration {
            settings = AVCapturePhotoSettings(
                rawPixelFormatType: rawPixelType,
                rawFileType: .dng,
                processedFormat: processedConfiguration.format,
                processedFileType: processedConfiguration.fileType
            )
        } else {
            settings = AVCapturePhotoSettings(
                rawPixelFormatType: rawPixelType,
                rawFileType: .dng,
                processedFormat: nil,
                processedFileType: nil
            )
        }

        if let device = videoInput?.device ?? activeDevice,
           let preferredDimensions = preferredPhotoDimensions(for: device) {
            if photoOutput.maxPhotoDimensions.width != preferredDimensions.width ||
                photoOutput.maxPhotoDimensions.height != preferredDimensions.height {
                photoOutput.maxPhotoDimensions = preferredDimensions
            }
            settings.maxPhotoDimensions = preferredDimensions
        }

        return settings
    }

    private func processedPhotoCaptureConfiguration(for format: PhotoCompanionFormat) -> ProcessedPhotoCaptureConfiguration? {
        guard let fileType = format.processedFileType,
              let codecType = format.processedCodecType else { return nil }

        guard photoOutput.availablePhotoFileTypes.contains(fileType),
              photoOutput.supportedPhotoCodecTypes(for: fileType).contains(codecType) else {
            return nil
        }

        return ProcessedPhotoCaptureConfiguration(
            format: [
                AVVideoCodecKey: codecType,
                AVVideoCompressionPropertiesKey: [
                    AVVideoQualityKey: 1.0
                ]
            ],
            fileType: fileType
        )
    }

    func focus(at point: CGPoint) {
        guard !manualFocusEnabled else { return }
        DispatchQueue.main.async {
            self.isFocusExposureLocked = false
        }
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
            self.session.sessionPreset = self.captureMode == .photo ? .photo : .inputPriority
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

            self.installPhotoOutputIfPossible()
            self.installDataOutputsIfPossible()

            self.configureDeviceForCurrentSelection(inConfiguration: true)
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

        let uniqueDevices = Dictionary(grouping: devices, by: \.deviceType).compactMap { $0.value.first }
        let options = buildLensOptions(from: uniqueDevices)
        lensOptions = options
        deviceRegistry = Dictionary(
            uniqueKeysWithValues: options.compactMap { option in
                guard let device = uniqueDevices.first(where: { $0.uniqueID == option.deviceUniqueID }) else { return nil }
                return (option.id, device)
            }
        )

        DispatchQueue.main.async {
            self.availableLenses = options
        }

        return options
    }

    private func buildLensOptions(from devices: [AVCaptureDevice]) -> [LensOption] {
        let ultraDevice = devices.first(where: { $0.position == .back && $0.deviceType == .builtInUltraWideCamera })
        let wideDevice = devices.first(where: { $0.position == .back && $0.deviceType == .builtInWideAngleCamera })
        let teleDevice = devices.first(where: { $0.position == .back && $0.deviceType == .builtInTelephotoCamera })

        var options: [LensOption] = []

        if let ultraDevice {
            let selectorID = "\(ultraDevice.uniqueID)-14"
            options.append(
                LensOption(
                    id: selectorID,
                    selectorID: selectorID,
                    deviceUniqueID: ultraDevice.uniqueID,
                    displayName: "14",
                    shortName: "14",
                    selectorTitle: "14",
                    deviceType: ultraDevice.deviceType,
                    position: ultraDevice.position,
                    zoomFactor: 1.0,
                    sortOrder: 50,
                    cycleOrder: 0
                )
            )
        }

        if let wideDevice {
            let wideSelectorID = "\(wideDevice.uniqueID)-24-cycle"
            options.append(
                LensOption(
                    id: "\(wideDevice.uniqueID)-24",
                    selectorID: wideSelectorID,
                    deviceUniqueID: wideDevice.uniqueID,
                    displayName: "24",
                    shortName: "24",
                    selectorTitle: "24",
                    deviceType: wideDevice.deviceType,
                    position: wideDevice.position,
                    zoomFactor: 1.0,
                    sortOrder: 100,
                    cycleOrder: 0
                )
            )

            if wideDevice.activeFormat.videoMaxZoomFactor >= (28.0 / 24.0) {
                options.append(
                    LensOption(
                        id: "\(wideDevice.uniqueID)-28",
                        selectorID: wideSelectorID,
                        deviceUniqueID: wideDevice.uniqueID,
                        displayName: "28",
                        shortName: "28",
                        selectorTitle: "28",
                        deviceType: wideDevice.deviceType,
                        position: wideDevice.position,
                        zoomFactor: 28.0 / 24.0,
                        sortOrder: 100,
                        cycleOrder: 1
                    )
                )
            }

            if wideDevice.activeFormat.videoMaxZoomFactor >= (35.0 / 24.0) {
                options.append(
                    LensOption(
                        id: "\(wideDevice.uniqueID)-35",
                        selectorID: wideSelectorID,
                        deviceUniqueID: wideDevice.uniqueID,
                        displayName: "35",
                        shortName: "35",
                        selectorTitle: "35",
                        deviceType: wideDevice.deviceType,
                        position: wideDevice.position,
                        zoomFactor: 35.0 / 24.0,
                        sortOrder: 100,
                        cycleOrder: 2
                    )
                )
            }

            if wideDevice.activeFormat.videoMaxZoomFactor >= 2.0 {
                let fiftySelectorID = "\(wideDevice.uniqueID)-50"
                options.append(
                    LensOption(
                        id: fiftySelectorID,
                        selectorID: fiftySelectorID,
                        deviceUniqueID: wideDevice.uniqueID,
                        displayName: "50",
                        shortName: "50",
                        selectorTitle: "50",
                        deviceType: wideDevice.deviceType,
                        position: wideDevice.position,
                        zoomFactor: 50.0 / 24.0,
                        sortOrder: 200,
                        cycleOrder: 0
                    )
                )
            }
        }

        if let teleDevice {
            let teleScale = teleDisplayZoomFactor(for: teleDevice, relativeTo: wideDevice)
            let teleBaseFocalLength = teleFocalLength(for: teleScale)
            let teleLabel = String(teleBaseFocalLength)
            let selectorID = "\(teleDevice.uniqueID)-\(teleLabel)-cycle"
            options.append(
                LensOption(
                    id: "\(teleDevice.uniqueID)-\(teleLabel)",
                    selectorID: selectorID,
                    deviceUniqueID: teleDevice.uniqueID,
                    displayName: teleLabel,
                    shortName: teleLabel,
                    selectorTitle: teleLabel,
                    deviceType: teleDevice.deviceType,
                    position: teleDevice.position,
                    zoomFactor: 1.0,
                    sortOrder: teleScale * 100,
                    cycleOrder: 0
                )
            )

            if teleDevice.activeFormat.videoMaxZoomFactor >= 1.5 {
                let firstCropFocalLength = teleCropFocalLength(baseFocalLength: teleBaseFocalLength, multiplier: 1.5)
                let firstCropLabel = String(firstCropFocalLength)
                options.append(
                    LensOption(
                        id: "\(teleDevice.uniqueID)-\(firstCropLabel)",
                        selectorID: selectorID,
                        deviceUniqueID: teleDevice.uniqueID,
                        displayName: firstCropLabel,
                        shortName: firstCropLabel,
                        selectorTitle: firstCropLabel,
                        deviceType: teleDevice.deviceType,
                        position: teleDevice.position,
                        zoomFactor: 1.5,
                        sortOrder: teleScale * 100,
                        cycleOrder: 1
                    )
                )
            }

            if teleDevice.activeFormat.videoMaxZoomFactor >= 2.0 {
                let secondCropFocalLength = teleCropFocalLength(baseFocalLength: teleBaseFocalLength, multiplier: 2.0)
                let secondCropLabel = String(secondCropFocalLength)
                options.append(
                    LensOption(
                        id: "\(teleDevice.uniqueID)-\(secondCropLabel)",
                        selectorID: selectorID,
                        deviceUniqueID: teleDevice.uniqueID,
                        displayName: secondCropLabel,
                        shortName: secondCropLabel,
                        selectorTitle: secondCropLabel,
                        deviceType: teleDevice.deviceType,
                        position: teleDevice.position,
                        zoomFactor: 2.0,
                        sortOrder: teleScale * 100,
                        cycleOrder: 2
                    )
                )
            }
        }

        if options.isEmpty, let fallbackDevice = wideDevice ?? devices.first(where: { $0.position == .back }) ?? devices.first {
            let selectorID = "\(fallbackDevice.uniqueID)-24"
            options.append(
                LensOption(
                    id: selectorID,
                    selectorID: selectorID,
                    deviceUniqueID: fallbackDevice.uniqueID,
                    displayName: "24",
                    shortName: "24",
                    selectorTitle: "24",
                    deviceType: fallbackDevice.deviceType,
                    position: fallbackDevice.position,
                    zoomFactor: 1.0,
                    sortOrder: 100,
                    cycleOrder: 0
                )
            )
        }

        return options.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                if lhs.selectorID == rhs.selectorID {
                    return lhs.cycleOrder < rhs.cycleOrder
                }
                return lhs.selectorTitle < rhs.selectorTitle
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private func teleDisplayZoomFactor(for teleDevice: AVCaptureDevice, relativeTo wideDevice: AVCaptureDevice?) -> Int {
        if #available(iOS 18.0, *) {
            let multiplier = teleDevice.displayVideoZoomFactorMultiplier
            if multiplier.isFinite, multiplier >= 2.5 {
                return min(max(Int(multiplier.rounded()), 3), 9)
            }
        }

        guard let wideDevice else { return 5 }
        let wideFOV = Double(wideDevice.activeFormat.videoFieldOfView)
        let teleFOV = Double(teleDevice.activeFormat.videoFieldOfView)
        guard wideFOV > 0, teleFOV > 0 else { return 5 }
        let ratio = wideFOV / teleFOV
        return min(max(Int(ratio.rounded()), 3), 5)
    }

    private func teleFocalLength(for teleScale: Int) -> Int {
        switch teleScale {
        case 3:
            return 70
        case 4:
            return 100
        case 5:
            return 120
        default:
            return teleScale * 24
        }
    }

    private func teleCropFocalLength(baseFocalLength: Int, multiplier: Double) -> Int {
        Int((Double(baseFocalLength) * multiplier).rounded())
    }

    private static func defaultLensOption(from options: [LensOption]) -> LensOption? {
        options.first(where: { $0.deviceType == .builtInWideAngleCamera && $0.position == .back && abs($0.zoomFactor - 1.0) < 0.01 }) ??
        options.first(where: { $0.position == .back }) ??
        options.first
    }

    private func installVideoInput(device: AVCaptureDevice) -> Bool {
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if #available(iOS 12.0, *) {
                input.unifiedAutoExposureDefaultsEnabled = true
            }
            guard session.canAddInput(input) else { return false }
            session.addInput(input)
            videoInput = input
            DispatchQueue.main.async {
                self.activeDevice = device
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

    private func installPhotoOutputIfPossible() {
        guard session.canAddOutput(photoOutput) else { return }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
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
            self.configureDeviceForCurrentSelection(inConfiguration: true)
            self.session.commitConfiguration()
            self.configureOutput()
        }
    }

    private func configureDeviceForCurrentSelection(mode: CaptureMode? = nil,
                                                    inConfiguration: Bool = false,
                                                    preferredLens: LensOption? = nil) {
        guard let device = videoInput?.device ?? activeDevice else { return }
        let targetMode = mode ?? captureMode
        let resolvedLens = resolvedLensOption(for: device, preferredLens: preferredLens)
        let targetZoomFactor = resolvedLens?.zoomFactor ?? 1.0

        do {
            if targetMode == .photo {
                guard let photoFormat = selectBestPhotoFormat(for: device) else {
                    throw CameraConfigurationError(message: "Selected lens does not support ProRAW capture.")
                }

                try device.lockForConfiguration()
                device.activeFormat = photoFormat
                device.activeVideoMinFrameDuration = .invalid
                device.activeVideoMaxFrameDuration = .invalid
                if let photoColorSpace = preferredPhotoColorSpace(for: photoFormat) {
                    device.activeColorSpace = photoColorSpace
                }
                if device.isFocusModeSupported(.continuousAutoFocus) && !manualFocusEnabled {
                    device.focusMode = .continuousAutoFocus
                }
                applyWhiteBalanceState(on: device, mode: targetMode)
                applyExposureConfiguration(on: device)
                if manualFocusEnabled && device.isLockingFocusWithCustomLensPositionSupported {
                    device.setFocusModeLocked(lensPosition: manualFocusPosition, completionHandler: nil)
                }
                device.videoZoomFactor = min(targetZoomFactor, device.activeFormat.videoMaxZoomFactor)
                device.unlockForConfiguration()

                updatePhotoOutputConfiguration(for: device, inConfiguration: inConfiguration)
                updateSupportedStabilizationModes(for: device.activeFormat)

                DispatchQueue.main.async {
                    self.activeDevice = device
                    self.activeLensID = resolvedLens?.id
                    self.supportsManualFocus = device.isLockingFocusWithCustomLensPositionSupported
                    self.colorProfile = .unavailable
                    self.canRecord = false
                    self.manualISO = self.clampedISO(self.manualISO, for: device)
                    self.manualShutterSpeedDenominator = self.nearestShutterSpeedDenominator(to: self.manualShutterSpeedDenominator)
                    self.photoManualISO = self.clampedISO(self.photoManualISO, for: device)
                    self.photoManualShutterSpeedDenominator = self.nearestShutterSpeedDenominator(to: self.photoManualShutterSpeedDenominator)
                }
                return
            }

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
            applyWhiteBalanceState(on: device, mode: targetMode)
            applyExposureConfiguration(on: device)
            if manualFocusEnabled && device.isLockingFocusWithCustomLensPositionSupported {
                device.setFocusModeLocked(lensPosition: manualFocusPosition, completionHandler: nil)
            }
            device.videoZoomFactor = min(targetZoomFactor, device.activeFormat.videoMaxZoomFactor)
            device.unlockForConfiguration()

            updatePhotoOutputConfiguration(for: device, inConfiguration: inConfiguration)
            updateSupportedStabilizationModes(for: selection.format)
            updateProExposureAutomationState()

            DispatchQueue.main.async {
                self.activeDevice = device
                self.activeLensID = resolvedLens?.id
                self.supportsManualFocus = device.isLockingFocusWithCustomLensPositionSupported
                self.colorProfile = selection.profile
                self.canRecord = true
                self.manualISO = self.clampedISO(self.manualISO, for: device)
                self.manualShutterSpeedDenominator = self.nearestShutterSpeedDenominator(to: self.manualShutterSpeedDenominator)
                self.photoManualISO = self.clampedISO(self.photoManualISO, for: device)
                self.photoManualShutterSpeedDenominator = self.nearestShutterSpeedDenominator(to: self.photoManualShutterSpeedDenominator)
            }
        } catch let error as CameraConfigurationError {
            DispatchQueue.main.async {
                self.colorProfile = .unavailable
                self.canRecord = false
                self.canCapturePhoto = false
                self.appleProRAWEnabled = false
            }
            presentStatusMessage(error.message)
        } catch {
            DispatchQueue.main.async {
                self.colorProfile = .unavailable
                self.canRecord = false
                self.canCapturePhoto = false
                self.appleProRAWEnabled = false
            }
            presentStatusMessage("Camera configuration failed.")
        }
    }

    private func resolvedLensOption(for device: AVCaptureDevice, preferredLens: LensOption? = nil) -> LensOption? {
        if let preferredLens, preferredLens.deviceUniqueID == device.uniqueID {
            return preferredLens
        }

        if let activeLensID,
           let activeLens = lensOptions.first(where: { $0.id == activeLensID && $0.deviceUniqueID == device.uniqueID }) {
            return activeLens
        }

        return Self.defaultLensOption(from: lensOptions.filter { $0.deviceUniqueID == device.uniqueID })
    }

    private func selectBestPhotoFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        device.formats
            .filter { !$0.supportedMaxPhotoDimensions.isEmpty }
            .sorted { lhs, rhs in
                if lhs.isHighestPhotoQualitySupported != rhs.isHighestPhotoQualitySupported {
                    return lhs.isHighestPhotoQualitySupported && !rhs.isHighestPhotoQualitySupported
                }

                if lhs.isHighPhotoQualitySupported != rhs.isHighPhotoQualitySupported {
                    return lhs.isHighPhotoQualitySupported && !rhs.isHighPhotoQualitySupported
                }

                let lhsPhotoPixels = maximumPhotoPixelCount(for: lhs)
                let rhsPhotoPixels = maximumPhotoPixelCount(for: rhs)
                if lhsPhotoPixels != rhsPhotoPixels {
                    return lhsPhotoPixels > rhsPhotoPixels
                }

                let lhsVideoDimensions = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
                let rhsVideoDimensions = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
                let lhsVideoPixels = Int64(lhsVideoDimensions.width) * Int64(lhsVideoDimensions.height)
                let rhsVideoPixels = Int64(rhsVideoDimensions.width) * Int64(rhsVideoDimensions.height)
                return lhsVideoPixels > rhsVideoPixels
            }
            .first
    }

    private func maximumPhotoPixelCount(for format: AVCaptureDevice.Format) -> Int64 {
        format.supportedMaxPhotoDimensions.reduce(into: Int64.zero) { best, dimensions in
            let pixelCount = Int64(dimensions.width) * Int64(dimensions.height)
            if pixelCount > best {
                best = pixelCount
            }
        }
    }

    private func updatePhotoOutputConfiguration(for device: AVCaptureDevice, inConfiguration: Bool) {
        if let dimensions = preferredPhotoDimensions(for: device) {
            let current = photoOutput.maxPhotoDimensions
            if current.width != dimensions.width || current.height != dimensions.height {
                photoOutput.maxPhotoDimensions = dimensions
            }
        }

        guard #available(iOS 14.3, *) else {
            DispatchQueue.main.async {
                self.appleProRAWSupported = false
                self.appleProRAWEnabled = false
                self.canCapturePhoto = false
            }
            return
        }

        let supported = photoOutput.isAppleProRAWSupported
        if photoOutput.isAppleProRAWEnabled != supported {
            if inConfiguration {
                photoOutput.isAppleProRAWEnabled = supported
            } else {
                session.beginConfiguration()
                photoOutput.isAppleProRAWEnabled = supported
                session.commitConfiguration()
            }
        }

        let enabled = supported && preferredAppleProRAWPixelFormatForCapture() != nil
        DispatchQueue.main.async {
            self.appleProRAWSupported = supported
            self.appleProRAWEnabled = enabled
            self.canCapturePhoto = enabled
        }
    }

    private func preferredPhotoDimensions(for device: AVCaptureDevice) -> CMVideoDimensions? {
        let valid = device.activeFormat.supportedMaxPhotoDimensions.filter { $0.width > 0 && $0.height > 0 }
        guard !valid.isEmpty else { return nil }

        switch photoResolutionOption {
        case .full:
            return valid.max { lhs, rhs in
                Int64(lhs.width) * Int64(lhs.height) < Int64(rhs.width) * Int64(rhs.height)
            }

        case .twelveMP:
            let targetPixels: Int64 = 12_500_000
            let preferredBelowTarget = valid
                .filter { Int64($0.width) * Int64($0.height) <= targetPixels }
                .max { lhs, rhs in
                    Int64(lhs.width) * Int64(lhs.height) < Int64(rhs.width) * Int64(rhs.height)
                }

            if let preferredBelowTarget {
                return preferredBelowTarget
            }

            return valid.min { lhs, rhs in
                let lhsPixels = Int64(lhs.width) * Int64(lhs.height)
                let rhsPixels = Int64(rhs.width) * Int64(rhs.height)
                return abs(lhsPixels - 12_000_000) < abs(rhsPixels - 12_000_000)
            }
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

    private func preferredPhotoColorSpace(for format: AVCaptureDevice.Format) -> AVCaptureColorSpace? {
        let colorSpaces = supportedColorSpaces(for: format)
        if colorSpaces.contains(.P3_D65) {
            return .P3_D65
        }
        if colorSpaces.contains(.sRGB) {
            return .sRGB
        }
        return colorSpaces.first
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

    private func configureOutput(mode: CaptureMode? = nil) {
        let targetMode = mode ?? captureMode
        if let connection = videoDataOutput.connection(with: .video) {
            applyPreviewConnectionConfiguration(connection)
            observeActiveStabilizationMode(on: connection)
            refreshActiveStabilizationMode(from: connection)
        }
        DispatchQueue.main.async {
            self.canRecord = targetMode == .video && self.colorProfile != .unavailable
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
        guard writer.canApply(outputSettings: videoSettings, forMediaType: .video) else {
            throw CameraConfigurationError(message: "\(selectedVideoCodec.title) is unavailable for the current recording configuration.")
        }
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
            throw CameraConfigurationError(message: "No active video format is available for \(selectedVideoCodec.title) recording.")
        }

        var settings: [String: Any] = [
            AVVideoCodecKey: selectedVideoCodec.codecType,
            AVVideoWidthKey: Int(dimensions.width),
            AVVideoHeightKey: Int(dimensions.height)
        ]

        if selectedVideoCodec.supportsManualBitrate {
            settings[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: recommendedBitrate(),
                AVVideoExpectedSourceFrameRateKey: selectedFrameRate,
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel as String
            ]
        }

        return settings
    }

    private func makeAudioWriterSettings() -> [String: Any]? {
        audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov)
    }

    private func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              let writer = assetWriter,
              let videoInput = videoWriterInput else { return }

        if shouldDelayRecordingStart(for: sampleBuffer) {
            return
        }

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
            handleWriterFailureIfNeeded(writer.error ?? CameraConfigurationError(message: "\(selectedVideoCodec.title) writer entered an invalid state."))
            return false
        }

        guard writer.startWriting() else {
            handleWriterFailureIfNeeded(writer.error ?? CameraConfigurationError(message: "AVAssetWriter could not start \(selectedVideoCodec.title) recording."))
            return false
        }

        recordingSourceStartTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        pendingRecordingLeadInStartTime = nil
        exactVideoFrameCount = 0
        writer.startSession(atSourceTime: .zero)
        isWritingSessionStarted = true
        return true
    }

    private func shouldDelayRecordingStart(for sampleBuffer: CMSampleBuffer) -> Bool {
        guard !isWritingSessionStarted,
              captureMode == .video,
              !proExposureEnabled,
              !exposureLockedDuringRecording,
              !isFocusExposureLocked,
              let device = videoInput?.device ?? activeDevice else {
            pendingRecordingLeadInStartTime = nil
            return false
        }

        let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if pendingRecordingLeadInStartTime == nil {
            pendingRecordingLeadInStartTime = sampleTime
        }

        guard let leadInStartTime = pendingRecordingLeadInStartTime else { return false }
        let elapsed = CMTimeGetSeconds(CMTimeSubtract(sampleTime, leadInStartTime))
        let exposureOffset = abs(device.exposureTargetOffset)

        guard elapsed.isFinite else { return false }

        if exposureOffset.isFinite,
           exposureOffset > autoExposureSettleOffsetThreshold,
           elapsed < autoExposureSettleMaximumDuration {
            return true
        }

        pendingRecordingLeadInStartTime = nil
        return false
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
                if let outputURL {
                    self.removeTemporaryCaptureFile(at: outputURL)
                }
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
        pendingRecordingLeadInStartTime = nil
    }

    private func handleWriterFailureIfNeeded(_ error: Error?) {
        guard let error else { return }
        let failedRecordingURL = currentRecordingURL

        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
        }

        cleanupWriterState()
        restoreDeviceAfterRecording()
        if let failedRecordingURL {
            removeTemporaryCaptureFile(at: failedRecordingURL)
        }
        presentStatusMessage("Recording failed: \(error.localizedDescription)")
    }

    private func purgeTemporaryCaptureFiles() {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let removableExtensions = Set(["mov", "dng", "heic", "jpg", "jpeg"])

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in urls where removableExtensions.contains(url.pathExtension.lowercased()) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func removeTemporaryCaptureFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func prepareDeviceForRecording() {
        guard let device = videoInput?.device ?? activeDevice else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if usesManualWhiteBalance(for: .video) {
                applyManualWhiteBalance(on: device, mode: .video)
            } else if whiteBalanceLockedDuringRecording, device.isWhiteBalanceModeSupported(.locked) {
                device.whiteBalanceMode = .locked
            }

            if proExposureEnabled, proExposureMode == .shutterAngle180 {
                // In 180 mode the preview path is already driving a custom shutter
                // with auto-ISO assistance. At record start we only stop that ISO
                // automation. If recording exposure lock is enabled, explicitly
                // freeze the current duration and ISO so Pro recording keeps the
                // exposure state selected in preview.
                if exposureLockedDuringRecording {
                    lockCurrentExposureForRecording(on: device)
                }
            } else if proExposureEnabled {
                applyExposureConfiguration(on: device)
            } else if exposureLockedDuringRecording {
                // Preserve the preview exposure exactly when recording lock is on.
                lockCurrentExposureForRecording(on: device)
            } else {
                // In auto mode keep preview exposure behavior unchanged.
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

            applyWhiteBalanceState(on: device, mode: .video)

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

    private func applyWhiteBalanceState(on device: AVCaptureDevice, mode: CaptureMode? = nil) {
        let targetMode = mode ?? captureMode
        if usesManualWhiteBalance(for: targetMode) {
            applyManualWhiteBalance(on: device, mode: targetMode)
        } else if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        } else if device.isWhiteBalanceModeSupported(.autoWhiteBalance) {
            device.whiteBalanceMode = .autoWhiteBalance
        }
    }

    private func applyManualWhiteBalance(on device: AVCaptureDevice, mode: CaptureMode? = nil) {
        guard device.isWhiteBalanceModeSupported(.locked) else { return }
        let targetMode = mode ?? captureMode

        let values = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
            temperature: Float(whiteBalanceTemperature(for: targetMode)),
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

        if let rawDefaultCaptureMode = defaults.string(forKey: SettingsKey.defaultCaptureMode),
           let persistedDefaultCaptureMode = CaptureMode(rawValue: rawDefaultCaptureMode) {
            defaultCaptureMode = persistedDefaultCaptureMode
        } else if let rawCaptureMode = defaults.string(forKey: SettingsKey.captureMode),
                  let persistedCaptureMode = CaptureMode(rawValue: rawCaptureMode) {
            defaultCaptureMode = persistedCaptureMode
            defaults.set(persistedCaptureMode.rawValue, forKey: SettingsKey.defaultCaptureMode)
        }

        captureMode = defaultCaptureMode

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

        if defaults.object(forKey: SettingsKey.zebraEnabled) != nil {
            zebraEnabled = defaults.bool(forKey: SettingsKey.zebraEnabled)
        }

        if defaults.object(forKey: SettingsKey.proExposureEnabled) != nil {
            proExposureEnabled = defaults.bool(forKey: SettingsKey.proExposureEnabled)
        }

        if let rawProMode = defaults.string(forKey: SettingsKey.proExposureMode),
           let mode = ProExposureMode(rawValue: rawProMode) {
            proExposureMode = mode
        }

        if defaults.object(forKey: SettingsKey.photoProExposureEnabled) != nil {
            photoProExposureEnabled = defaults.bool(forKey: SettingsKey.photoProExposureEnabled)
        }

        if let rawPhotoProMode = defaults.string(forKey: SettingsKey.photoProExposureMode),
           let mode = PhotoProExposureMode(rawValue: rawPhotoProMode) {
            photoProExposureMode = mode == .auto ? .manual : mode
        } else {
            photoProExposureMode = .manual
        }

        if defaults.object(forKey: SettingsKey.whiteBalanceLockedDuringRecording) != nil {
            whiteBalanceLockedDuringRecording = defaults.bool(forKey: SettingsKey.whiteBalanceLockedDuringRecording)
        }

        if defaults.object(forKey: SettingsKey.exposureLockedDuringRecording) != nil {
            exposureLockedDuringRecording = defaults.bool(forKey: SettingsKey.exposureLockedDuringRecording)
        }

        if let savedCodec = defaults.string(forKey: SettingsKey.selectedVideoCodec),
           let codec = VideoRecordingCodec(rawValue: savedCodec) {
            selectedVideoCodec = codec
        }

        if let savedPhotoCompanionFormat = defaults.string(forKey: SettingsKey.photoCompanionFormat),
           let companionFormat = PhotoCompanionFormat(rawValue: savedPhotoCompanionFormat) {
            photoCompanionFormat = companionFormat
        }

        if let savedPhotoResolutionOption = defaults.string(forKey: SettingsKey.photoResolutionOption),
           let resolutionOption = PhotoResolutionOption(rawValue: savedPhotoResolutionOption) {
            photoResolutionOption = resolutionOption
        }

        if let savedExposureBias = defaults.object(forKey: SettingsKey.exposureBias) as? Double {
            exposureBias = Float(savedExposureBias)
        }

        if let savedVideoWhiteBalanceTemperature = defaults.object(forKey: SettingsKey.videoWhiteBalanceTemperature) as? Double {
            videoWhiteBalanceTemperature = savedVideoWhiteBalanceTemperature
        }

        if defaults.object(forKey: SettingsKey.videoUsesManualWhiteBalance) != nil {
            videoUsesManualWhiteBalance = defaults.bool(forKey: SettingsKey.videoUsesManualWhiteBalance)
        }

        if let savedPhotoWhiteBalanceTemperature = defaults.object(forKey: SettingsKey.photoWhiteBalanceTemperature) as? Double {
            photoWhiteBalanceTemperature = savedPhotoWhiteBalanceTemperature
        }

        if defaults.object(forKey: SettingsKey.photoUsesManualWhiteBalance) != nil {
            photoUsesManualWhiteBalance = defaults.bool(forKey: SettingsKey.photoUsesManualWhiteBalance)
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

        if let savedPhotoShutterDenominator = defaults.object(forKey: SettingsKey.photoManualShutterSpeedDenominator) as? Int {
            photoManualShutterSpeedDenominator = savedPhotoShutterDenominator
        }

        if let savedPhotoISO = defaults.object(forKey: SettingsKey.photoManualISO) as? Double {
            photoManualISO = Float(savedPhotoISO)
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

                if !self.isCurrentProExposureEnabled && device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    if device.isExposureRectOfInterestSupported {
                        device.exposureRectOfInterest = self.autoExposureRect(around: point)
                    }
                }

                if shouldLockAfterFocus {
                    if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                    }
                    if !self.isCurrentProExposureEnabled && device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    }
                } else {
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                    if !self.isCurrentProExposureEnabled && device.isExposureModeSupported(.continuousAutoExposure) {
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

            if !isCurrentProExposureEnabled && device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
            }
            device.isSubjectAreaChangeMonitoringEnabled = false
            DispatchQueue.main.async {
                self.isFocusExposureLocked = true
            }
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
        if let connection = photoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
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
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
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
                self.removeTemporaryCaptureFile(at: fileURL)
                self.presentStatusMessage("Video was recorded but Photos access is not allowed.")
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            } completionHandler: { success, error in
                self.removeTemporaryCaptureFile(at: fileURL)

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

    fileprivate func saveCapturedPhotoToPhotoLibrary(_ captureResult: CapturedPhotoResult) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                self.presentStatusMessage("RAW photo was captured but Photos access is not allowed.")
                return
            }

            let rawURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("dng")

            var processedURL: URL?

            do {
                try captureResult.rawData.write(to: rawURL, options: .atomic)

                if let processedData = captureResult.processedData,
                   let processedFileType = captureResult.processedFileType {
                    let fileExtension = processedFileType == .heic ? "heic" : "jpg"
                    let url = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(fileExtension)
                    try processedData.write(to: url, options: .atomic)
                    processedURL = url
                }
            } catch {
                self.presentStatusMessage("Could not prepare RAW photo for saving.")
                return
            }

            PHPhotoLibrary.shared().performChanges({
                let rawRequest = PHAssetCreationRequest.forAsset()
                let rawOptions = PHAssetResourceCreationOptions()
                rawOptions.shouldMoveFile = true
                rawRequest.addResource(with: .photo, fileURL: rawURL, options: rawOptions)

                if let processedURL {
                    let processedRequest = PHAssetCreationRequest.forAsset()
                    let processedOptions = PHAssetResourceCreationOptions()
                    processedOptions.shouldMoveFile = true
                    processedRequest.addResource(with: .photo, fileURL: processedURL, options: processedOptions)
                }
            }, completionHandler: { success, error in
                if !success {
                    try? FileManager.default.removeItem(at: rawURL)
                    if let processedURL {
                        try? FileManager.default.removeItem(at: processedURL)
                    }
                }

                if let error {
                    self.presentStatusMessage("Could not save RAW photo: \(error.localizedDescription)")
                    return
                }

                if success {
                    if captureResult.processedData != nil,
                       let processedFileType = captureResult.processedFileType {
                        let companionTitle = processedFileType == .heic ? "HEIC" : "JPEG"
                        self.presentStatusMessage("DNG and \(companionTitle) saved to Photos.")
                    } else {
                        self.presentStatusMessage("RAW photo saved to Photos.")
                    }
                }
            })
        }
    }
}

private final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (CapturedPhotoResult?) -> Void
    private let processedFileType: AVFileType?
    private let stateQueue = DispatchQueue(label: "com.logcamera.photoCaptureProcessor")
    private var rawPhotoData: Data?
    private var processedPhotoData: Data?

    init(processedFileType: AVFileType?, completion: @escaping (CapturedPhotoResult?) -> Void) {
        self.processedFileType = processedFileType
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation() else { return }

        stateQueue.sync {
            if photo.isRawPhoto {
                rawPhotoData = data
            } else {
                processedPhotoData = data
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        if let error {
            print("PhotoCaptureProcessor capture error: \(error)")
        }
        let result: CapturedPhotoResult? = stateQueue.sync {
            guard let rawPhotoData else { return nil }
            return CapturedPhotoResult(
                rawData: rawPhotoData,
                processedData: processedPhotoData,
                processedFileType: processedFileType
            )
        }
        DispatchQueue.main.async {
            self.completion(result)
        }
    }
}

private struct ProcessedPhotoCaptureConfiguration {
    let format: [String: Any]
    let fileType: AVFileType
}

private struct CapturedPhotoResult {
    let rawData: Data
    let processedData: Data?
    let processedFileType: AVFileType?
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
