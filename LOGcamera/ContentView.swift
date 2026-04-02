import SwiftUI
import AVFoundation
import UIKit

private enum AppTheme {
    static let accent = Color(red: 0.90, green: 0.91, blue: 0.94)
    static let accentStrong = Color(red: 0.69, green: 0.72, blue: 0.78)
    static let surface = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let surfaceRaised = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let surfaceLift = Color(red: 0.19, green: 0.19, blue: 0.21)
    static let border = Color.white.opacity(0.14)
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.62)
    static let recordLive = Color(red: 0.86, green: 0.24, blue: 0.26)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.10, blue: 0.11),
                Color.black,
                Color(red: 0.13, green: 0.13, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                surfaceLift.opacity(0.96),
                surfaceRaised.opacity(0.98),
                surface.opacity(1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var activeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.96),
                accent,
                accentStrong
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var flatSurfaceFill: Color {
        surfaceRaised.opacity(0.92)
    }

    static var flatSurfaceActiveFill: Color {
        accent
    }
}

private extension View {
    func metalRoundedPanel(cornerRadius: CGFloat = 22, isActive: Bool = false) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isActive ? AppTheme.flatSurfaceActiveFill : AppTheme.flatSurfaceFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isActive ? Color.white.opacity(0.20) : AppTheme.border, lineWidth: 1)
            )
    }

    func metalCapsulePanel(isActive: Bool = false) -> some View {
        self
            .background(
                Capsule()
                    .fill(isActive ? AppTheme.flatSurfaceActiveFill : AppTheme.flatSurfaceFill)
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? Color.white.opacity(0.20) : AppTheme.border, lineWidth: 1)
            )
    }

    func metalCirclePanel(isActive: Bool = false) -> some View {
        self
            .background(
                Circle()
                    .fill(isActive ? AppTheme.flatSurfaceActiveFill : AppTheme.flatSurfaceFill)
            )
            .overlay(
                Circle()
                    .stroke(isActive ? Color.white.opacity(0.20) : AppTheme.border, lineWidth: 1)
            )
    }
}

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if cameraManager.isAuthorized {
                CameraScreen(cameraManager: cameraManager)
            } else {
                PermissionView(cameraManager: cameraManager)
            }
        }
        .preferredColorScheme(.dark)
        .statusBar(hidden: true)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, newPhase in
            cameraManager.handleScenePhase(newPhase)
        }
    }
}

private struct CameraScreen: View {
    @ObservedObject var cameraManager: CameraManager
    @State private var showsControlMenu = false
    @State private var showsExposurePanel = false
    @State private var showsWhiteBalancePanel = false
    @State private var previewControlRotationDegrees: Double = 0

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            RadialGradient(
                colors: [Color.white.opacity(0.10), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 280
            )
            .ignoresSafeArea()
            .blendMode(.screen)

            VStack(spacing: 0) {
                topControlStrip
                    .offset(y: -3)
                previewSurface
                Spacer(minLength: 0)
            }
            .ignoresSafeArea(edges: .horizontal)
        }
        .fullScreenCover(isPresented: $showsControlMenu) {
            CameraSettingsView(cameraManager: cameraManager)
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            updatePreviewControlRotation(for: UIDevice.current.orientation)
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updatePreviewControlRotation(for: UIDevice.current.orientation)
        }
    }

    private var topControlStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                compactToggleChip(title: "PRO", isSelected: cameraManager.proExposureEnabled) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showsExposurePanel = false
                        cameraManager.setProExposureEnabled(!cameraManager.proExposureEnabled)
                    }
                }

                if cameraManager.proExposureEnabled {
                    Menu {
                        ForEach(ProExposureMode.allCases) { mode in
                            Button(mode.title) {
                                showsExposurePanel = false
                                cameraManager.selectProExposureMode(mode)
                            }
                        }
                    } label: {
                        compactMenuChip(title: cameraManager.proExposureMode.title)
                    }

                    if cameraManager.proExposureMode == .shutterAngle180 {
                        compactReadOnlyChip(title: "S \(cameraManager.currentShutterSpeedLabel)")
                        compactReadOnlyChip(title: "ISO Auto")
                    }

                    if cameraManager.proExposureMode == .manual {
                        Menu {
                            ForEach(cameraManager.availableShutterSpeedDenominators, id: \.self) { denominator in
                                Button("1/\(denominator)") {
                                    cameraManager.setManualShutterSpeedDenominator(denominator)
                                }
                            }
                        } label: {
                            compactMenuChip(title: "S \(cameraManager.currentShutterSpeedLabel)")
                        }

                        Menu {
                            ForEach(cameraManager.availableISOValues, id: \.self) { iso in
                                Button(String(format: "ISO %.0f", iso)) {
                                    cameraManager.setManualISO(iso)
                                }
                            }
                        } label: {
                            compactMenuChip(title: "ISO \(cameraManager.currentISOValueLabel)")
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    private var previewSurface: some View {
        CameraPreviewView(cameraManager: cameraManager, isSuspended: showsControlMenu)
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .overlay {
                FocusFeedbackOverlay(feedback: cameraManager.focusFeedback)
            }
            .overlay(alignment: .top) {
                if cameraManager.isRecording {
                    Text(cameraManager.recordingTimeText)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.72), in: Capsule())
                        .padding(.top, 18)
                }
            }
            .overlay(alignment: .bottom) {
                bottomOverlay
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }
    }

    private var bottomOverlay: some View {
        VStack(spacing: 14) {
            if let statusMessage = cameraManager.statusMessage {
                Text(statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .metalRoundedPanel(cornerRadius: 16)
            }

            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom) {
                    lensPickerButton
                        .padding(.bottom, 12)
                    Spacer()
                    quickAdjustments
                        .padding(.bottom, 12)
                }

                recordButton
                    .padding(.bottom, 2)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: showsQuickAdjustmentPanel ? 210 : 138,
                alignment: .bottom
            )
        }
    }

    private var quickAdjustments: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if showsWhiteBalancePanel {
                whiteBalanceQuickPanel
            }

            if showsExposurePanel {
                exposureQuickPanel
            }

            quickAdjustButton(title: "WB", isActive: showsWhiteBalancePanel || isWhiteBalanceAdjusted) {
                withAnimation(.easeOut(duration: 0.18)) {
                    showsExposurePanel = false
                    showsWhiteBalancePanel.toggle()
                }
            }

            quickAdjustButton(title: "EXP", isActive: showsExposurePanel || isExposureAdjusted) {
                withAnimation(.easeOut(duration: 0.18)) {
                    showsWhiteBalancePanel = false
                    showsExposurePanel.toggle()
                }
            }
            .disabled(!cameraManager.supportsExposureBiasAdjustment)
            .opacity(cameraManager.supportsExposureBiasAdjustment ? 1 : 0.45)

            controlsButton
        }
    }

    private var exposureQuickPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Exposure")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(String(format: "%+.1f EV", cameraManager.exposureBias))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Slider(
                value: Binding(
                    get: { Double(cameraManager.exposureBias) },
                    set: { cameraManager.setExposureBias(Float($0)) }
                ),
                in: Double(cameraManager.exposureBiasRange.lowerBound)...Double(cameraManager.exposureBiasRange.upperBound)
            )
            .tint(AppTheme.accent)
        }
        .padding(12)
        .frame(width: 268)
        .metalRoundedPanel(cornerRadius: 18)
        .rotationEffect(.degrees(previewControlRotationDegrees))
    }

    private var whiteBalanceQuickPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("White Balance")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(cameraManager.whiteBalanceLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Slider(
                value: Binding(
                    get: { cameraManager.whiteBalanceTemperature },
                    set: { cameraManager.setWhiteBalanceTemperature($0) }
                ),
                in: cameraManager.whiteBalanceTemperatureRange,
                step: 10
            )
            .tint(AppTheme.accent)

            HStack {
                Text("2500K")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Button("Auto") {
                    cameraManager.setWhiteBalanceAuto()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .buttonStyle(.plain)

                Spacer()

                Text("9000K")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(12)
        .frame(width: 268)
        .metalRoundedPanel(cornerRadius: 18)
        .rotationEffect(.degrees(previewControlRotationDegrees))
    }

    private var lensPickerButton: some View {
        Menu {
            ForEach(cameraManager.availableLenses) { lens in
                Button(lens.shortName) {
                    cameraManager.switchLens(to: lens.id)
                }
            }
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(activeLensShortName)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                    if cameraManager.activeLensSummary.caseInsensitiveCompare(activeLensShortName) != .orderedSame {
                        Text(cameraManager.activeLensSummary)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .metalCapsulePanel()
        }
        .buttonStyle(.plain)
        .disabled(cameraManager.isRecording)
        .rotationEffect(.degrees(previewControlRotationDegrees))
    }

    private var recordButton: some View {
        Button {
            if cameraManager.isRecording {
                cameraManager.stopRecording()
            } else {
                cameraManager.startRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.94), lineWidth: 4)
                    .frame(width: 82, height: 82)
                    .background(
                        Circle()
                            .fill(AppTheme.surfaceGradient)
                            .frame(width: 82, height: 82)
                    )

                if cameraManager.isRecording {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.recordLive)
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .fill(cameraManager.canRecord ? AppTheme.activeGradient : LinearGradient(colors: [Color.gray.opacity(0.65), Color.gray.opacity(0.28)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 58, height: 58)
                }
            }
            .offset(y: 11)
            .frame(width: 124, height: 124)
            .contentShape(Circle())
        }
        .background(
            Circle()
                .fill(Color.black.opacity(0.001))
                .frame(width: 124, height: 124)
        )
        .buttonStyle(.plain)
        .disabled(!cameraManager.canRecord && !cameraManager.isRecording)
    }

    private var controlsButton: some View {
        Button {
            showsExposurePanel = false
            showsWhiteBalancePanel = false
            showsControlMenu.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 56, height: 56)
                .metalCirclePanel()
        }
        .buttonStyle(.plain)
        .rotationEffect(.degrees(previewControlRotationDegrees))
    }

    private var activeLensShortName: String {
        cameraManager.availableLenses.first(where: { $0.id == cameraManager.activeLensID })?.shortName ?? "Wide"
    }

    private var isExposureAdjusted: Bool {
        abs(cameraManager.exposureBias) > 0.01
    }

    private var isWhiteBalanceAdjusted: Bool {
        cameraManager.usesManualWhiteBalance
    }

    private var showsQuickAdjustmentPanel: Bool {
        showsExposurePanel || showsWhiteBalancePanel
    }

    private func updatePreviewControlRotation(for orientation: UIDeviceOrientation) {
        let angle: Double
        switch orientation {
        case .landscapeLeft:
            angle = 90
        case .landscapeRight:
            angle = -90
        case .portraitUpsideDown:
            angle = 180
        case .portrait:
            angle = 0
        default:
            return
        }

        guard angle != previewControlRotationDegrees else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            previewControlRotationDegrees = angle
        }
    }

    private func quickAdjustButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(isActive ? Color.black : AppTheme.textPrimary)
                .frame(width: 48, height: 48)
                .metalCirclePanel(isActive: isActive)
        }
        .buttonStyle(.plain)
        .rotationEffect(.degrees(previewControlRotationDegrees))
    }

    private func compactToggleChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(isSelected ? Color.black : AppTheme.textPrimary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .metalCapsulePanel(isActive: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func compactMenuChip(title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .metalCapsulePanel()
    }

    private func compactReadOnlyChip(title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .metalCapsulePanel()
    }
}

private struct CameraSettingsView: View {
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            RadialGradient(
                colors: [Color.white.opacity(0.10), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()
            .blendMode(.screen)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    previewSection
                    frameRateSection
                    stabilizationSection
                    lockSection
                    bitrateSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 42, height: 42)
                    .metalCirclePanel()
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
    }

    private var previewSection: some View {
        settingsCard(title: "Preview") {
            HStack(spacing: 8) {
                ForEach(PreviewLookMode.allCases) { mode in
                    selectionButton(
                        title: mode.title,
                        isSelected: cameraManager.previewLookMode == mode
                    ) {
                        cameraManager.selectPreviewLookMode(mode)
                    }
                }
            }
        }
    }

    private var frameRateSection: some View {
        settingsCard(title: "Frame Rate") {
            HStack(spacing: 8) {
                ForEach(CameraManager.supportedFrameRates, id: \.self) { fps in
                    frameRateButton(
                        fps: fps,
                        isSelected: cameraManager.selectedFrameRate == fps
                    ) {
                        cameraManager.selectFrameRate(fps)
                    }
                    .disabled(cameraManager.isRecording)
                }
            }
        }
    }

    private var stabilizationSection: some View {
        settingsCard(title: "Stabilization") {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(CaptureStabilizationMode.allCases) { mode in
                        selectionButton(
                            title: mode.title,
                            isSelected: cameraManager.selectedStabilizationMode == mode
                        ) {
                            cameraManager.selectStabilizationMode(mode)
                        }
                        .disabled(!cameraManager.supportedStabilizationModes.contains(mode))
                        .opacity(cameraManager.supportedStabilizationModes.contains(mode) ? 1 : 0.45)
                    }
                }

                HStack {
                    Text("Active")
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(cameraManager.activeStabilizationTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(cameraManager.activeStabilizationMode == .off ? .white.opacity(0.7) : AppTheme.accent)
                }
                .font(.system(size: 13, weight: .medium))
            }
        }
    }

    private var lockSection: some View {
        settingsCard(title: "Locks") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    lockChip(
                        title: "WB Lock REC",
                        isOn: cameraManager.whiteBalanceLockedDuringRecording
                    ) {
                        cameraManager.whiteBalanceLockedDuringRecording.toggle()
                    }

                    lockChip(
                        title: "AE Lock REC",
                        isOn: cameraManager.exposureLockedDuringRecording
                    ) {
                        cameraManager.exposureLockedDuringRecording.toggle()
                    }
                }
            }
        }
    }

    private var bitrateSection: some View {
        settingsCard(title: "Bitrate") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(CameraManager.supportedBitratesMbps, id: \.self) { bitrate in
                        selectionButton(
                            title: String(format: "%.0f Mb/s", bitrate),
                            isSelected: cameraManager.recordingBitrateMbps == bitrate
                        ) {
                            cameraManager.setRecordingBitrateMbps(bitrate)
                        }
                    }
                }

                HStack {
                    Button(cameraManager.usesCustomBitrate ? "Auto" : "Default") {
                        cameraManager.resetRecordingBitrateToDefault()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
    }

    private func settingsCard<Content: View>(title: String,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(AppTheme.textSecondary)

            content()
        }
        .padding(16)
        .metalRoundedPanel(cornerRadius: 24)
    }

    private func selectionButton(title: String,
                                 isSelected: Bool,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? Color.black : AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .metalRoundedPanel(cornerRadius: 14, isActive: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func frameRateButton(fps: Int,
                                 isSelected: Bool,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text("\(fps)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))

                Text("FPS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.6)
            }
            .foregroundStyle(isSelected ? Color.black : AppTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .metalRoundedPanel(cornerRadius: 14, isActive: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func lockChip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(isOn ? Color.black : AppTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .metalRoundedPanel(cornerRadius: 14, isActive: isOn)
        }
        .buttonStyle(.plain)
    }
}

private struct PermissionView: View {
    @ObservedObject var cameraManager: CameraManager

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            RadialGradient(
                colors: [Color.white.opacity(0.12), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 340
            )
            .ignoresSafeArea()
            .blendMode(.screen)

            VStack(spacing: 18) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(AppTheme.accent)

                Text("LOGcamera needs camera, microphone and Photos access.")
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("Enable permissions in Settings to capture 4K HEVC video in Apple Log and save clips to Photos.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentStrong)
            }
            .padding(28)
        }
    }
}

private struct FocusFeedbackOverlay: View {
    let feedback: FocusFeedback?

    var body: some View {
        GeometryReader { proxy in
            if let feedback {
                VStack(spacing: 8) {
                    if feedback.isLocked {
                        Text("AE/AF Lock")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .metalCapsulePanel()
                    }

                    ZStack {
                        Circle()
                            .stroke(feedback.isLocked ? AppTheme.accent : AppTheme.textPrimary, lineWidth: 2)
                            .frame(width: 84, height: 84)

                        Circle()
                            .fill((feedback.isLocked ? AppTheme.accent : AppTheme.textPrimary).opacity(0.22))
                            .frame(width: 12, height: 12)
                    }
                }
                    .position(
                        x: feedback.previewPoint.x * proxy.size.width,
                        y: max(54, feedback.previewPoint.y * proxy.size.height - (feedback.isLocked ? 18 : 0))
                    )
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: feedback?.id)
        .allowsHitTesting(false)
    }
}

#Preview {
    ContentView()
}
