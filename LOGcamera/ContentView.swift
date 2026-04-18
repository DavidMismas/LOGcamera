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

private struct RuleOfThirdsGridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let verticalOffsets = [width / 3, (width * 2) / 3]
                let horizontalOffsets = [height / 3, (height * 2) / 3]

                for x in verticalOffsets {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }

                for y in horizontalOffsets {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.34), lineWidth: 1)
            .shadow(color: Color.black.opacity(0.28), radius: 0, x: 0, y: 0)
        }
        .allowsHitTesting(false)
    }
}

private struct CameraScreen: View {
    private enum PhotoProAdjustment: String {
        case shutterSpeed
        case iso
        case whiteBalance
    }

    private enum VideoQuickAdjustment {
        case whiteBalance
        case exposure
    }

    @ObservedObject var cameraManager: CameraManager
    @State private var showsControlMenu = false
    @State private var showsExposurePanel = false
    @State private var showsWhiteBalancePanel = false
    @State private var showsPhotoExposureBiasPanel = false
    @State private var activePhotoProAdjustment: PhotoProAdjustment?
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
                    .offset(y: -5)
                if cameraManager.captureMode == .photo {
                    Spacer(minLength: 0)
                    previewSurface
                    photoBottomBar
                        .padding(.top, 14)
                        .padding(.horizontal, 14)
                } else {
                    previewSurface
                    Spacer(minLength: 0)
                }
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
        .onChange(of: cameraManager.captureMode) { _, _ in
            showsExposurePanel = false
            showsWhiteBalancePanel = false
            showsPhotoExposureBiasPanel = false
            activePhotoProAdjustment = nil
        }
        .onChange(of: cameraManager.photoProExposureEnabled) { _, isEnabled in
            if isEnabled {
                showsPhotoExposureBiasPanel = false
            } else {
                activePhotoProAdjustment = nil
            }
        }
    }

    private var topControlStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 8) {
                if cameraManager.captureMode == .photo {
                    compactControlChip(title: "PRO", isSelected: cameraManager.photoProExposureEnabled) {
                        showsPhotoExposureBiasPanel = false
                        cameraManager.setProExposureEnabled(!cameraManager.photoProExposureEnabled)
                    }

                    if cameraManager.photoProExposureEnabled {
                        compactActionChip(
                            title: "S \(cameraManager.currentShutterSpeedLabel)",
                            isSelected: activePhotoProAdjustment == .shutterSpeed
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showsPhotoExposureBiasPanel = false
                                activePhotoProAdjustment = activePhotoProAdjustment == .shutterSpeed ? nil : .shutterSpeed
                            }
                        }

                        compactActionChip(
                            title: "ISO \(cameraManager.currentISOValueLabel)",
                            isSelected: activePhotoProAdjustment == .iso
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showsPhotoExposureBiasPanel = false
                                activePhotoProAdjustment = activePhotoProAdjustment == .iso ? nil : .iso
                            }
                        }

                        compactActionChip(
                            title: "WB \(photoWhiteBalanceChipLabel)",
                            isSelected: activePhotoProAdjustment == .whiteBalance
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showsPhotoExposureBiasPanel = false
                                activePhotoProAdjustment = activePhotoProAdjustment == .whiteBalance ? nil : .whiteBalance
                            }
                        }
                    }
                } else {
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
            }
            .padding(.horizontal, 14)
        }
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    private var previewSurface: some View {
        CameraPreviewView(cameraManager: cameraManager, isSuspended: showsControlMenu)
            .aspectRatio(cameraManager.previewAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .overlay {
                if shouldShowCompositionGrid {
                    RuleOfThirdsGridOverlay()
                }
            }
            .overlay {
                FocusFeedbackOverlay(feedback: cameraManager.focusFeedback)
            }
            .overlay(alignment: focusLockBadgeAlignment) {
                if cameraManager.isFocusExposureLocked {
                    focusLockStatusBadge
                }
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
            .overlay(alignment: .topTrailing) {
                if cameraManager.captureMode == .photo,
                   !isLandscapePreviewOrientation,
                   let activePhotoProAdjustment,
                   cameraManager.photoProExposureEnabled {
                    photoProAdjustmentPanel(for: activePhotoProAdjustment)
                        .padding(.top, 76)
                        .padding(.trailing, 14)
                        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                }
            }
            .overlay(alignment: .topTrailing) {
                if cameraManager.captureMode == .photo,
                   !isLandscapePreviewOrientation,
                   showsPhotoExposureBiasPanel {
                    photoExposureBiasAdjustmentPanel
                        .padding(.top, 76)
                        .padding(.trailing, 14)
                        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                }
            }
            .overlay(alignment: .bottom) {
                Group {
                    if cameraManager.captureMode == .photo {
                        photoPreviewOverlay
                    } else {
                        bottomOverlay
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
    }

    private var shouldShowCompositionGrid: Bool {
        switch cameraManager.captureMode {
        case .photo:
            return cameraManager.photoGridEnabled
        case .video:
            return cameraManager.videoGridEnabled
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
                if cameraManager.captureMode == .video {
                    if isLandscapePreviewOrientation {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 10) {
                                if let activeVideoQuickAdjustment {
                                    videoQuickAdjustmentPanel(for: activeVideoQuickAdjustment)
                                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
                                }

                                quickAdjustments
                                    .hidden()
                            }
                            .padding(.leading, 2)
                            .padding(.bottom, 12)

                            Spacer(minLength: 0)

                            quickAdjustments
                                .padding(.bottom, 12)
                        }
                    } else {
                        HStack(alignment: .bottom) {
                            Spacer(minLength: 0)

                            VStack(alignment: .trailing, spacing: 10) {
                                if let activeVideoQuickAdjustment {
                                    videoQuickAdjustmentPanel(for: activeVideoQuickAdjustment)
                                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
                                }

                                quickAdjustments
                            }
                            .padding(.trailing, 2)
                            .padding(.bottom, 12)
                        }
                    }

                    VStack(spacing: 12) {
                        lensPickerStrip
                        ZStack {
                            recordButton

                            captureModeSwitchButton
                                .offset(x: captureModeSwitchButtonOffset, y: 6)
                        }
                    }
                    .padding(.bottom, 2)
                } else {
                    HStack(alignment: .bottom) {
                        Spacer()
                        controlsButton
                            .padding(.bottom, 12)
                    }

                    VStack(spacing: 12) {
                        lensPickerStrip
                        ZStack {
                            recordButton

                            captureModeSwitchButton
                                .offset(x: captureModeSwitchButtonOffset, y: 6)
                        }
                    }
                    .padding(.bottom, 2)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: cameraManager.captureMode == .video
                    ? (showsQuickAdjustmentPanel ? 338 : 168)
                    : 136,
                alignment: .bottom
            )
        }
    }

    private var photoPreviewOverlay: some View {
        VStack(spacing: isLandscapePreviewOrientation ? 5 : 10) {
            if let statusMessage = photoPreviewStatusMessage {
                Text(statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .metalRoundedPanel(cornerRadius: 16)
            }

            if isLandscapePreviewOrientation,
               cameraManager.photoProExposureEnabled || showsPhotoExposureBiasPanel {
                HStack {
                    Spacer(minLength: 0)
                    if cameraManager.photoProExposureEnabled,
                       let activePhotoProAdjustment {
                        photoLandscapeAdjustmentPanel(for: activePhotoProAdjustment)
                    } else if showsPhotoExposureBiasPanel {
                        photoLandscapeExposureBiasAdjustmentPanel
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottomTrailing)))
            }

            lensPickerStrip
                .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .bottom)
    }

    private var photoPreviewStatusMessage: String? {
        guard let statusMessage = cameraManager.statusMessage else { return nil }
        return statusMessage.localizedCaseInsensitiveContains("stabilization") ? nil : statusMessage
    }

    private var photoBottomBar: some View {
        ZStack(alignment: .center) {
            HStack {
                captureModeSwitchButton
                Spacer()
                VStack(spacing: 8) {
                    photoExposureBiasButton
                    controlsButton
                        .frame(width: 62, height: 62)
                }
            }

            recordButton
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .center)
    }

    @ViewBuilder
    private func photoProAdjustmentPanel(for adjustment: PhotoProAdjustment) -> some View {
        let title = photoAdjustmentTitle(for: adjustment)
        let valueLabel = photoAdjustmentValueLabel(for: adjustment)
        let sliderBinding = photoSliderBinding(for: adjustment)
        let sliderRange = 0...Double(max(photoAdjustmentStepCount(for: adjustment) - 1, 0))

        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(AppTheme.textSecondary)

            Text(valueLabel)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)

            DiscreteLandscapeSlider(
                value: sliderBinding,
                range: sliderRange,
                step: 1
            )
            .frame(width: 272)
            .rotationEffect(.degrees(-90))
            .frame(width: 34, height: 272)

            if adjustment == .whiteBalance {
                Button("Auto") {
                    cameraManager.setWhiteBalanceAuto()
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.accent)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .frame(width: 60)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surfaceRaised.opacity(0.36))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.7)
        )
        .rotationEffect(.degrees(previewControlRotationDegrees))
    }

    private func photoLandscapeAdjustmentPanel(for adjustment: PhotoProAdjustment) -> some View {
        let title = photoAdjustmentTitle(for: adjustment)
        let valueLabel = photoAdjustmentValueLabel(for: adjustment)
        let sliderBinding = photoSliderBinding(for: adjustment)
        let sliderRange = 0...Double(max(photoAdjustmentStepCount(for: adjustment) - 1, 0))

        return HStack(spacing: 10) {
            DiscreteLandscapeSlider(
                value: sliderBinding,
                range: sliderRange,
                step: 1
            )
            .frame(maxWidth: .infinity)

            VStack(alignment: .center, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .fixedSize()

                Text(valueLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .fixedSize()

                if adjustment == .whiteBalance {
                    Button("Auto") {
                        cameraManager.setWhiteBalanceAuto()
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.accent)
                    .buttonStyle(.plain)
                    .fixedSize()
                }
            }
            .rotationEffect(.degrees(previewControlRotationDegrees))
            .frame(width: 56, height: 116)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surfaceRaised.opacity(0.36))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.7)
        )
    }

    private var photoExposureBiasAdjustmentPanel: some View {
        VStack(spacing: 10) {
            Text("EV")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(AppTheme.textSecondary)

            Text(String(format: "%+.1f", cameraManager.exposureBias))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)

            DiscreteLandscapeSlider(
                value: photoExposureBiasSliderBinding,
                range: 0...Double(max(photoExposureBiasValues.count - 1, 0)),
                step: 1
            )
            .frame(width: 272)
            .rotationEffect(.degrees(-90))
            .frame(width: 34, height: 272)

            photoExposureBiasResetButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .frame(width: 60)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surfaceRaised.opacity(0.36))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.7)
        )
        .rotationEffect(.degrees(previewControlRotationDegrees))
    }

    private var photoLandscapeExposureBiasAdjustmentPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                DiscreteLandscapeSlider(
                    value: photoExposureBiasSliderBinding,
                    range: 0...Double(max(photoExposureBiasValues.count - 1, 0)),
                    step: 1
                )
                .frame(maxWidth: .infinity)

                VStack(alignment: .center, spacing: 4) {
                    Text("EV")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(0.4)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .fixedSize()

                    Text(String(format: "%+.1f", cameraManager.exposureBias))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .rotationEffect(.degrees(previewControlRotationDegrees))
                .frame(width: 56, height: 116)
            }

            photoExposureBiasResetButton
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 92)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surfaceRaised.opacity(0.36))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.7)
        )
    }

    private var quickAdjustments: some View {
        VStack(alignment: .trailing, spacing: 10) {
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

    private var activeVideoQuickAdjustment: VideoQuickAdjustment? {
        if showsWhiteBalancePanel {
            return .whiteBalance
        }
        if showsExposurePanel {
            return .exposure
        }
        return nil
    }

    @ViewBuilder
    private func videoQuickAdjustmentPanel(for adjustment: VideoQuickAdjustment) -> some View {
        switch adjustment {
        case .exposure:
            videoVerticalExposureQuickPanel
        case .whiteBalance:
            videoVerticalWhiteBalanceQuickPanel
        }
    }

    private var exposureQuickPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Exposure")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button {
                    cameraManager.setExposureBias(0)
                } label: {
                    Text("0.0")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(isExposureAdjusted ? Color.black : AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .metalCapsulePanel(isActive: isExposureAdjusted)
                }
                .buttonStyle(.plain)
                .disabled(!isExposureAdjusted)

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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surfaceRaised.opacity(0.36))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.7)
        )
    }

    private var videoVerticalExposureQuickPanel: some View {
        VStack(spacing: 10) {
            Text("EXP")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(AppTheme.textSecondary)
                .rotationEffect(.degrees(previewControlRotationDegrees))

            Text(String(format: "%+.1f", cameraManager.exposureBias))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .rotationEffect(.degrees(previewControlRotationDegrees))

            Slider(
                value: Binding(
                    get: { Double(cameraManager.exposureBias) },
                    set: { cameraManager.setExposureBias(Float($0)) }
                ),
                in: Double(cameraManager.exposureBiasRange.lowerBound)...Double(cameraManager.exposureBiasRange.upperBound)
            )
            .tint(AppTheme.accent)
            .frame(width: 236)
            .rotationEffect(.degrees(-90))
            .frame(width: 34, height: 236)

            Button {
                cameraManager.setExposureBias(0)
            } label: {
                Text("0.0")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isExposureAdjusted ? Color.black : AppTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .metalCapsulePanel(isActive: isExposureAdjusted)
                    .rotationEffect(.degrees(previewControlRotationDegrees))
            }
            .buttonStyle(.plain)
            .disabled(!isExposureAdjusted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .frame(width: 60)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surfaceRaised.opacity(0.36))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.7)
        )
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surfaceRaised.opacity(0.36))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.7)
        )
    }

    private var videoVerticalWhiteBalanceQuickPanel: some View {
        VStack(spacing: 10) {
            Text("WB")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(AppTheme.textSecondary)
                .rotationEffect(.degrees(previewControlRotationDegrees))

            Text(cameraManager.whiteBalanceLabel)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .rotationEffect(.degrees(previewControlRotationDegrees))

            Slider(
                value: Binding(
                    get: { cameraManager.whiteBalanceTemperature },
                    set: { cameraManager.setWhiteBalanceTemperature($0) }
                ),
                in: cameraManager.whiteBalanceTemperatureRange,
                step: 10
            )
            .tint(AppTheme.accent)
            .frame(width: 236)
            .rotationEffect(.degrees(-90))
            .frame(width: 34, height: 236)

            Button("Auto") {
                cameraManager.setWhiteBalanceAuto()
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(AppTheme.accent)
            .buttonStyle(.plain)
            .rotationEffect(.degrees(previewControlRotationDegrees))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .frame(width: 60)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surfaceRaised.opacity(0.36))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.7)
        )
    }

    private var lensPickerStrip: some View {
        HStack(spacing: 8) {
            ForEach(cameraManager.lensPickerOptions) { lens in
                Button {
                    cameraManager.handleLensPickerTap(selectorID: lens.selectorID)
                } label: {
                    Text(cameraManager.lensPickerTitle(for: lens))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(cameraManager.activeLensSelectorID == lens.selectorID ? Color.black : AppTheme.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(cameraManager.activeLensSelectorID == lens.selectorID ? AppTheme.accent : Color.black.opacity(0.60))
                        )
                        .overlay(
                            Circle()
                                .stroke(cameraManager.activeLensSelectorID == lens.selectorID ? Color.white.opacity(0.18) : AppTheme.border, lineWidth: 1)
                        )
                        .rotationEffect(.degrees(previewControlRotationDegrees))
                }
                .buttonStyle(.plain)
                .disabled(cameraManager.isCaptureBusy)
            }
        }
    }

    private var recordButton: some View {
        Button {
            cameraManager.triggerPrimaryCapture()
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
                } else if cameraManager.isPhotoCaptureInProgress {
                    Circle()
                        .fill(Color.white.opacity(0.78))
                        .frame(width: 44, height: 44)
                } else {
                    Circle()
                        .fill(
                            cameraManager.captureMode == .photo
                                ? LinearGradient(colors: [Color.white.opacity(0.98), Color.white.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : (cameraManager.canTriggerCapture
                                    ? AppTheme.activeGradient
                                    : LinearGradient(colors: [Color.gray.opacity(0.65), Color.gray.opacity(0.28)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .frame(width: 58, height: 58)
                }
            }
            .offset(y: cameraManager.captureMode == .photo ? 0 : 11)
            .frame(width: 124, height: 124)
            .contentShape(Circle())
        }
        .background(
            Circle()
                .fill(Color.black.opacity(0.001))
                .frame(width: 124, height: 124)
        )
        .buttonStyle(.plain)
        .disabled(!cameraManager.canTriggerCapture)
    }

    private var captureModeSwitchButton: some View {
        Button {
            cameraManager.switchCaptureMode()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: cameraManager.captureMode == .video ? "camera.fill" : "video.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(cameraManager.captureMode.switchButtonTitle)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.7)
            }
            .foregroundStyle(AppTheme.textPrimary)
            .frame(width: 62, height: 62)
            .metalCirclePanel()
        }
        .buttonStyle(.plain)
        .disabled(cameraManager.isCaptureBusy)
        .rotationEffect(.degrees(previewControlRotationDegrees))
    }

    private var controlsButton: some View {
        Button {
            showsExposurePanel = false
            showsWhiteBalancePanel = false
            showsPhotoExposureBiasPanel = false
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

    private var isExposureAdjusted: Bool {
        abs(cameraManager.exposureBias) > 0.01
    }

    private var isWhiteBalanceAdjusted: Bool {
        cameraManager.usesManualWhiteBalance
    }

    private var showsQuickAdjustmentPanel: Bool {
        showsExposurePanel || showsWhiteBalancePanel
    }

    private var isLandscapePreviewOrientation: Bool {
        abs(previewControlRotationDegrees) == 90
    }

    private var photoExposureBiasValues: [Double] {
        (0...100).map { Double($0) / 10 - 5 }
    }

    private var photoExposureBiasSliderBinding: Binding<Double> {
        Binding(
            get: {
                Double(photoCurrentExposureBiasIndex)
            },
            set: { newValue in
                let index = photoClampedIndex(for: newValue, count: photoExposureBiasValues.count)
                guard photoExposureBiasValues.indices.contains(index) else { return }
                cameraManager.setExposureBias(Float(photoExposureBiasValues[index]))
            }
        )
    }

    private var photoShutterSliderBinding: Binding<Double> {
        Binding(
            get: {
                Double(photoCurrentShutterIndex)
            },
            set: { newValue in
                let index = photoClampedIndex(for: newValue, count: cameraManager.availableShutterSpeedDenominators.count)
                guard cameraManager.availableShutterSpeedDenominators.indices.contains(index) else { return }
                cameraManager.setManualShutterSpeedDenominator(
                    cameraManager.availableShutterSpeedDenominators[index]
                )
            }
        )
    }

    private var photoISOSliderBinding: Binding<Double> {
        Binding(
            get: {
                Double(photoCurrentISOIndex)
            },
            set: { newValue in
                let index = photoClampedIndex(for: newValue, count: cameraManager.availableISOValues.count)
                guard cameraManager.availableISOValues.indices.contains(index) else { return }
                cameraManager.setManualISO(cameraManager.availableISOValues[index])
            }
        )
    }

    private var photoWhiteBalanceSliderBinding: Binding<Double> {
        Binding(
            get: {
                Double(photoCurrentWhiteBalanceIndex)
            },
            set: { newValue in
                let values = photoWhiteBalanceValues
                let index = photoClampedIndex(for: newValue, count: values.count)
                guard values.indices.contains(index) else { return }
                cameraManager.setWhiteBalanceTemperature(values[index])
            }
        )
    }

    private var photoCurrentShutterIndex: Int {
        let values = cameraManager.availableShutterSpeedDenominators
        return values.firstIndex(of: cameraManager.currentShutterSpeedDenominator) ?? 0
    }

    private var photoCurrentISOIndex: Int {
        let values = cameraManager.availableISOValues
        guard !values.isEmpty else { return 0 }

        let currentISO = Float(cameraManager.currentISOValueLabel) ?? values[0]
        return values.enumerated().min { lhs, rhs in
            abs(lhs.element - currentISO) < abs(rhs.element - currentISO)
        }?.offset ?? 0
    }

    private var photoCurrentWhiteBalanceIndex: Int {
        let values = photoWhiteBalanceValues
        guard !values.isEmpty else { return 0 }

        let currentTemperature = cameraManager.whiteBalanceTemperature
        return values.enumerated().min { lhs, rhs in
            abs(lhs.element - currentTemperature) < abs(rhs.element - currentTemperature)
        }?.offset ?? 0
    }

    private var photoCurrentExposureBiasIndex: Int {
        let values = photoExposureBiasValues
        guard !values.isEmpty else { return 0 }

        let currentBias = Double(cameraManager.exposureBias)
        return values.enumerated().min { lhs, rhs in
            abs(lhs.element - currentBias) < abs(rhs.element - currentBias)
        }?.offset ?? 0
    }

    private func photoAdjustmentStepCount(for adjustment: PhotoProAdjustment) -> Int {
        switch adjustment {
        case .shutterSpeed:
            return cameraManager.availableShutterSpeedDenominators.count
        case .iso:
            return cameraManager.availableISOValues.count
        case .whiteBalance:
            return photoWhiteBalanceValues.count
        }
    }

    private func photoAdjustmentTitle(for adjustment: PhotoProAdjustment) -> String {
        switch adjustment {
        case .shutterSpeed:
            return "SS"
        case .iso:
            return "ISO"
        case .whiteBalance:
            return "WB"
        }
    }

    private func photoAdjustmentValueLabel(for adjustment: PhotoProAdjustment) -> String {
        switch adjustment {
        case .shutterSpeed:
            return cameraManager.currentShutterSpeedLabel
        case .iso:
            return cameraManager.currentISOValueLabel
        case .whiteBalance:
            return photoWhiteBalanceChipLabel
        }
    }

    private func photoSliderBinding(for adjustment: PhotoProAdjustment) -> Binding<Double> {
        switch adjustment {
        case .shutterSpeed:
            return photoShutterSliderBinding
        case .iso:
            return photoISOSliderBinding
        case .whiteBalance:
            return photoWhiteBalanceSliderBinding
        }
    }

    private var photoWhiteBalanceValues: [Double] {
        let range = cameraManager.whiteBalanceTemperatureRange
        let lowerBound = Int(range.lowerBound.rounded())
        let upperBound = Int(range.upperBound.rounded())
        return Array(stride(from: lowerBound, through: upperBound, by: 100)).map(Double.init)
    }

    private var photoWhiteBalanceChipLabel: String {
        cameraManager.whiteBalanceLabel
    }

    private func photoClampedIndex(for value: Double, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(Int(value.rounded()), 0), count - 1)
    }

    private var captureModeSwitchButtonOffset: CGFloat {
        -132
    }

    private var focusLockBadgeAlignment: Alignment {
        isLandscapePreviewOrientation ? .trailing : .top
    }

    private var focusLockStatusBadge: some View {
        Text("AE/AF LOCK")
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .metalCapsulePanel()
            .rotationEffect(.degrees(previewControlRotationDegrees))
            .padding(.top, isLandscapePreviewOrientation ? 0 : (cameraManager.isRecording ? 58 : 18))
            .padding(.trailing, isLandscapePreviewOrientation ? 0 : 0)
            .allowsHitTesting(false)
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

    private var photoExposureBiasButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                activePhotoProAdjustment = nil
                showsPhotoExposureBiasPanel.toggle()
            }
        } label: {
            Text("EV")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(photoExposureBiasButtonIsActive ? Color.black : AppTheme.textPrimary)
                .frame(width: 44, height: 28)
                .metalCapsulePanel(isActive: photoExposureBiasButtonIsActive)
        }
        .buttonStyle(.plain)
        .disabled(!cameraManager.supportsExposureBiasAdjustment)
        .opacity(cameraManager.supportsExposureBiasAdjustment ? 1 : 0.45)
        .rotationEffect(.degrees(previewControlRotationDegrees))
    }

    private var photoExposureBiasButtonIsActive: Bool {
        cameraManager.supportsExposureBiasAdjustment && (showsPhotoExposureBiasPanel || isExposureAdjusted)
    }

    private var photoExposureBiasResetButton: some View {
        Button {
            cameraManager.setExposureBias(0)
        } label: {
            Text("0.0")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(isExposureAdjusted ? Color.black : AppTheme.textSecondary)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .metalCapsulePanel(isActive: isExposureAdjusted)
        }
        .buttonStyle(.plain)
        .disabled(!isExposureAdjusted)
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

    private func compactActionChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? Color.black : AppTheme.textPrimary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .metalCapsulePanel(isActive: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func compactReadOnlyChip(title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .metalCapsulePanel()
    }

    private func compactControlChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 9, weight: .black))
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(0.4)
            }
            .foregroundStyle(isSelected ? Color.black : AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .metalCapsulePanel(isActive: isSelected)
        }
        .buttonStyle(.plain)
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
                VStack(alignment: .leading, spacing: 14) {
                    header
                    appSection
                    photoSection
                    videoSection
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
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
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

    private var appSection: some View {
        settingsCard(title: "App") {
            VStack(alignment: .leading, spacing: 14) {
                settingsSubsection(title: "Default Mode") {
                    HStack(spacing: 8) {
                        ForEach(CaptureMode.allCases) { mode in
                            selectionButton(
                                title: mode.title,
                                isSelected: cameraManager.defaultCaptureMode == mode
                            ) {
                                cameraManager.selectDefaultCaptureMode(mode)
                            }
                        }
                    }

                    settingsSupportingText("This mode opens when the app launches.")
                }

                settingsDivider()

                settingsSubsection(title: "Monitoring") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            selectionButton(
                                title: "Zebra Off",
                                isSelected: !cameraManager.zebraEnabled
                            ) {
                                cameraManager.zebraEnabled = false
                            }

                            selectionButton(
                                title: "Zebra On",
                                isSelected: cameraManager.zebraEnabled
                            ) {
                                cameraManager.zebraEnabled = true
                            }
                        }

                        HStack {
                            Text("Threshold")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text("\(cameraManager.zebraThresholdPercent)%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.accent)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(cameraManager.zebraThresholdPercent) },
                                set: { cameraManager.setZebraThresholdPercent(Int($0.rounded())) }
                            ),
                            in: 80...100,
                            step: 1
                        )
                        .tint(AppTheme.accent)

                        HStack(spacing: 8) {
                            ForEach(ZebraChannel.allCases) { channel in
                                selectionButton(
                                    title: channel.title,
                                    isSelected: cameraManager.zebraChannel == channel
                                ) {
                                    cameraManager.selectZebraChannel(channel)
                                }
                            }
                        }
                    }

                    settingsSupportingText("Uses the selected RGB channel and shows zebras once that channel reaches the chosen threshold.")
                }
            }
        }
    }

    private var previewOptions: some View {
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

    private var frameRateOptions: some View {
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

    private var photoSection: some View {
        settingsCard(title: "Photo") {
            VStack(alignment: .leading, spacing: 14) {
                settingsSubsection(title: "Default Lens") {
                    photoDefaultLensOptions
                }

                settingsDivider()

                settingsSubsection(title: "Format") {
                    photoCaptureOptions
                }

                settingsDivider()

                settingsSubsection(title: "Resolution") {
                    photoResolutionOptions
                }

                settingsDivider()

                settingsSubsection(title: "Metering") {
                    photoMeteringOptions
                }

                settingsDivider()

                settingsSubsection(title: "Composition") {
                    photoCompositionOptions
                }
            }
        }
    }

    private var photoDefaultLensOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(PhotoDefaultWideFocalLength.allCases) { focalLength in
                    selectionButton(
                        title: focalLength.title,
                        isSelected: cameraManager.photoDefaultWideFocalLength == focalLength
                    ) {
                        cameraManager.selectPhotoDefaultWideFocalLength(focalLength)
                    }
                }
            }

            settingsSupportingText("Chooses the startup focal length for the main wide lens. If the selected crop is unavailable on the current device, LOGcamera falls back to 24 mm.")
        }
    }

    private var photoCaptureOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Format")
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(cameraManager.appleProRAWEnabled ? "ProRAW DNG" : "Unavailable")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(cameraManager.appleProRAWEnabled ? AppTheme.accent : .white.opacity(0.7))
            }
            .font(.system(size: 12, weight: .medium))

            HStack(spacing: 8) {
                ForEach(PhotoCompanionFormat.allCases) { format in
                    selectionButton(
                        title: format.title,
                        isSelected: cameraManager.photoCompanionFormat == format
                    ) {
                        cameraManager.selectPhotoCompanionFormat(format)
                    }
                }
            }

            settingsSupportingText("HEIC/JPEG is saved as a separate file next to the DNG.")
        }
    }

    private var photoResolutionOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(PhotoResolutionOption.allCases) { option in
                    selectionButton(
                        title: option.title,
                        isSelected: cameraManager.photoResolutionOption == option
                    ) {
                        cameraManager.selectPhotoResolutionOption(option)
                    }
                }
            }

            settingsSupportingText("12 MP uses the closest supported 12-megapixel capture size.")
        }
    }

    private var photoCompositionOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                selectionButton(
                    title: "Grid Off",
                    isSelected: !cameraManager.photoGridEnabled
                ) {
                    cameraManager.photoGridEnabled = false
                }

                selectionButton(
                    title: "Grid On",
                    isSelected: cameraManager.photoGridEnabled
                ) {
                    cameraManager.photoGridEnabled = true
                }
            }

            settingsSupportingText("Shows a 3×3 rule-of-thirds grid on the photo preview.")
        }
    }

    private var photoMeteringOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                selectionButton(
                    title: "Separate",
                    isSelected: !cameraManager.photoMeteringPointsLinked
                ) {
                    cameraManager.photoMeteringPointsLinked = false
                }

                selectionButton(
                    title: "Linked",
                    isSelected: cameraManager.photoMeteringPointsLinked
                ) {
                    cameraManager.photoMeteringPointsLinked = true
                }
            }

            settingsSupportingText("Separate keeps AF and EV draggable on their own. Linked keeps both markers together while dragging either one.")
        }
    }

    private var videoSection: some View {
        settingsCard(title: "Video") {
            VStack(alignment: .leading, spacing: 14) {
                settingsSubsection(title: "Preview") {
                    previewOptions
                }

                settingsDivider()

                settingsSubsection(title: "Frame Rate") {
                    frameRateOptions
                }

                settingsDivider()

                settingsSubsection(title: "Codec") {
                    videoCodecOptions
                }

                settingsDivider()

                settingsSubsection(title: "Bitrate") {
                    bitrateOptions
                }

                settingsDivider()

                settingsSubsection(title: "Audio") {
                    videoAudioOptions
                }

                settingsDivider()

                settingsSubsection(title: "Stabilization") {
                    stabilizationOptions
                }

                settingsDivider()

                settingsSubsection(title: "Locks") {
                    lockOptions
                }

                settingsDivider()

                settingsSubsection(title: "Composition") {
                    videoCompositionOptions
                }
            }
        }
    }

    private var videoCompositionOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                selectionButton(
                    title: "Grid Off",
                    isSelected: !cameraManager.videoGridEnabled
                ) {
                    cameraManager.videoGridEnabled = false
                }

                selectionButton(
                    title: "Grid On",
                    isSelected: cameraManager.videoGridEnabled
                ) {
                    cameraManager.videoGridEnabled = true
                }
            }

            settingsSupportingText("Shows a 3×3 rule-of-thirds grid on the video preview.")
        }
    }

    private var videoCodecOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(VideoRecordingCodec.allCases) { codec in
                    selectionButton(
                        title: codec.title,
                        isSelected: cameraManager.selectedVideoCodec == codec
                    ) {
                        cameraManager.selectVideoCodec(codec)
                    }
                }
            }

            settingsSupportingText(
                cameraManager.allowsCustomBitrate
                ? "HEVC uses the bitrate setting below."
                : "ProRes records larger files and uses its own internal data rate."
            )
        }
    }

    private var stabilizationOptions: some View {
        VStack(spacing: 10) {
            HStack {
                settingsSupportingText("For video mode only.")
                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(CaptureStabilizationMode.allCases) { mode in
                    selectionButton(
                        title: mode.title,
                        isSelected: cameraManager.selectedStabilizationMode == mode
                    ) {
                        cameraManager.selectStabilizationMode(mode)
                    }
                    .disabled(cameraManager.captureMode == .video && !cameraManager.supportedStabilizationModes.contains(mode))
                    .opacity((cameraManager.captureMode == .photo || cameraManager.supportedStabilizationModes.contains(mode)) ? 1 : 0.45)
                }
            }

            HStack {
                Text("Active")
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(cameraManager.activeStabilizationTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(cameraManager.activeStabilizationMode == .off ? .white.opacity(0.7) : AppTheme.accent)
            }
            .font(.system(size: 12, weight: .medium))
        }
    }

    private var lockOptions: some View {
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

    private var bitrateOptions: some View {
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
            .disabled(!cameraManager.allowsCustomBitrate)
            .opacity(cameraManager.allowsCustomBitrate ? 1 : 0.45)

            HStack {
                Button(cameraManager.usesCustomBitrate ? "Auto" : "Default") {
                    cameraManager.resetRecordingBitrateToDefault()
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .buttonStyle(.plain)

                Spacer()
            }
            .disabled(!cameraManager.allowsCustomBitrate)
            .opacity(cameraManager.allowsCustomBitrate ? 1 : 0.45)

            if !cameraManager.allowsCustomBitrate {
                settingsSupportingText("Selected codec manages bitrate internally.")
            }
        }
    }

    private var videoAudioOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(VideoAudioMode.allCases) { mode in
                    selectionButton(
                        title: mode.title,
                        isSelected: cameraManager.videoAudioMode == mode
                    ) {
                        cameraManager.selectVideoAudioMode(mode)
                    }
                    .disabled(!cameraManager.audioCaptureAvailable || (mode == .stereo && !cameraManager.supportedVideoAudioModes.contains(.stereo)))
                    .opacity((cameraManager.audioCaptureAvailable && (mode == .mono || cameraManager.supportedVideoAudioModes.contains(.stereo))) ? 1 : 0.45)
                }
            }

            HStack {
                Text("Active Capture")
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(cameraManager.activeVideoAudioModeTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(cameraManager.activeVideoAudioModeTitle == "Unavailable" ? .white.opacity(0.7) : AppTheme.accent)
            }
            .font(.system(size: 12, weight: .medium))

            HStack(spacing: 8) {
                selectionButton(
                    title: "Wind Off",
                    isSelected: !cameraManager.videoWindNoiseReductionEnabled
                ) {
                    cameraManager.setVideoWindNoiseReductionEnabled(false)
                }

                selectionButton(
                    title: "Wind On",
                    isSelected: cameraManager.videoWindNoiseReductionEnabled
                ) {
                    cameraManager.setVideoWindNoiseReductionEnabled(true)
                }
            }
            .disabled(!cameraManager.canEnableVideoWindNoiseReduction)
            .opacity(cameraManager.canEnableVideoWindNoiseReduction ? 1 : 0.45)

            settingsActionButton(
                title: "Mic Modes...",
                detail: cameraManager.activeMicrophoneModeTitle
            ) {
                cameraManager.openSystemMicrophoneModes()
            }

            HStack {
                Text("Preferred")
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(cameraManager.preferredMicrophoneModeTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .font(.system(size: 12, weight: .medium))

            settingsSupportingText(cameraManager.videoAudioSettingsSummary)
            settingsSupportingText(cameraManager.videoWindNoiseReductionSummary)
        }
    }

    private func settingsCard<Content: View>(title: String,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            content()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .metalRoundedPanel(cornerRadius: 22)
    }

    private func subsectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .tracking(0.9)
            .foregroundStyle(AppTheme.textPrimary)
    }

    private func settingsSupportingText(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
    }

    private func settingsDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
    }

    private func settingsSubsection<Content: View>(title: String,
                                                   @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            subsectionLabel(title)
            content()
        }
    }

    private func selectionButton(title: String,
                                 isSelected: Bool,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? Color.black : AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .metalRoundedPanel(cornerRadius: 12, isActive: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func frameRateButton(fps: Int,
                                 isSelected: Bool,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text("\(fps)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))

                Text("FPS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.5)
            }
            .foregroundStyle(isSelected ? Color.black : AppTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .metalRoundedPanel(cornerRadius: 12, isActive: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func lockChip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(isOn ? Color.black : AppTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .metalRoundedPanel(cornerRadius: 12, isActive: isOn)
        }
        .buttonStyle(.plain)
    }

    private func settingsActionButton(title: String,
                                      detail: String,
                                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer(minLength: 0)

                Text(detail)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .metalRoundedPanel(cornerRadius: 12)
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

                Text("Enable permissions in Settings to capture ProRAW photos and 4K video, then save them to Photos.")
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

private struct DiscreteLandscapeSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    private let trackHeight: CGFloat = 5
    private let thumbSize: CGFloat = 28

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, thumbSize)
            let progress = normalizedProgress
            let xPosition = (thumbSize / 2) + progress * max(width - thumbSize, 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.white.opacity(0.30))
                    .frame(width: max(xPosition, thumbSize / 2), height: trackHeight)

                Circle()
                    .fill(Color.white.opacity(0.98))
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.16), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.16), radius: 3, y: 1)
                    .position(x: xPosition, y: proxy.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateValue(for: gesture.location.x, width: width)
                    }
            )
        }
        .frame(height: 34)
    }

    private var normalizedProgress: CGFloat {
        let lower = range.lowerBound
        let upper = range.upperBound
        guard upper > lower else { return 0 }
        let clamped = min(max(value, lower), upper)
        return CGFloat((clamped - lower) / (upper - lower))
    }

    private func updateValue(for locationX: CGFloat, width: CGFloat) {
        let usableWidth = max(width - thumbSize, 1)
        let clampedX = min(max(locationX, thumbSize / 2), width - thumbSize / 2)
        let progress = (clampedX - thumbSize / 2) / usableWidth
        let rawValue = range.lowerBound + Double(progress) * (range.upperBound - range.lowerBound)
        let steppedValue = (rawValue / step).rounded() * step
        value = min(max(steppedValue, range.lowerBound), range.upperBound)
    }
}

private struct FocusFeedbackOverlay: View {
    let feedback: FocusFeedback?

    var body: some View {
        GeometryReader { proxy in
            if let feedback {
                ZStack {
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
                    y: feedback.previewPoint.y * proxy.size.height
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
