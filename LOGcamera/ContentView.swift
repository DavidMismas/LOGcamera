import SwiftUI
import AVFoundation
import Photos
import UIKit

private enum AppTheme {
    static let accent = Color(red: 0.78, green: 0.07, blue: 0.11)
    static let accentStrong = Color(red: 0.43, green: 0.018, blue: 0.04)
    static let surface = Color(red: 0.055, green: 0.045, blue: 0.05)
    static let surfaceRaised = Color(red: 0.12, green: 0.095, blue: 0.10)
    static let surfaceLift = Color(red: 0.20, green: 0.16, blue: 0.17)
    static let border = Color(red: 0.90, green: 0.62, blue: 0.64).opacity(0.16)
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.62)
    static let recordLive = Color(red: 0.91, green: 0.10, blue: 0.14)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.15, green: 0.055, blue: 0.07),
                Color.black,
                Color(red: 0.10, green: 0.075, blue: 0.085)
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
                accent,
                recordLive,
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
            .shadow(color: isActive ? AppTheme.accent.opacity(0.24) : Color.clear, radius: 8, y: 2)
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
            .shadow(color: isActive ? AppTheme.accent.opacity(0.22) : Color.clear, radius: 6, y: 2)
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
            .shadow(color: isActive ? AppTheme.accent.opacity(0.24) : Color.clear, radius: 7, y: 2)
    }

    func expandedTapTarget(horizontal: CGFloat = 3, vertical: CGFloat = 8) -> some View {
        contentShape(
            .interaction,
            ExpandedHitRectangle(horizontalExpansion: horizontal, verticalExpansion: vertical)
        )
    }
}

private struct ExpandedHitRectangle: Shape {
    let horizontalExpansion: CGFloat
    let verticalExpansion: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(
            CGRect(
                x: rect.minX - horizontalExpansion,
                y: rect.minY - verticalExpansion,
                width: rect.width + horizontalExpansion * 2,
                height: rect.height + verticalExpansion * 2
            )
        )
    }
}

struct ContentView: View {
    private static let currentOnboardingVersion = 1

    @StateObject private var cameraManager = CameraManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("app.onboardingVersion") private var onboardingVersion = 0

    var body: some View {
        Group {
            if onboardingVersion < Self.currentOnboardingVersion {
                RawlightOnboardingView(cameraManager: cameraManager, mode: .firstLaunch) {
                    onboardingVersion = Self.currentOnboardingVersion
                }
            } else if cameraManager.isAuthorized {
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
        }
        .allowsHitTesting(false)
    }
}

private struct CameraScreen: View {
    private enum PhotoProAdjustment: String {
        case shutterSpeed
        case iso
        case whiteBalance
        case focus
    }

    private enum VideoQuickAdjustment {
        case whiteBalance
        case exposure
        case focus
    }

    private enum VideoProAdjustment: String {
        case shutterSpeed
        case iso
        case whiteBalance
        case focus
    }

    @ObservedObject var cameraManager: CameraManager
    @State private var showsControlMenu = false
    @State private var showsExposurePanel = false
    @State private var showsWhiteBalancePanel = false
    @State private var showsFocusPanel = false
    @State private var showsPhotoExposureBiasPanel = true
    @State private var activePhotoProAdjustment: PhotoProAdjustment?
    @State private var activeVideoProAdjustment: VideoProAdjustment?
    @State private var previewControlRotationDegrees: Double = 0
    @State private var isPhotoShutterAnimating = false
    @State private var isModeTransitionVisible = false
    @State private var modeTransitionTarget: CaptureMode = .photo

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            RadialGradient(
                colors: [AppTheme.accent.opacity(0.16), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 280
            )
            .ignoresSafeArea()
            .blendMode(.screen)

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    topControlStrip
                        .offset(y: -5)
                    if cameraManager.captureMode == .photo {
                        previewSurface(width: proxy.size.width, forceFullWidth: true)
                            .padding(.top, 18)
                        photoAdjustmentDock
                            .padding(.top, 14)
                        Spacer(minLength: 0)
                        photoBottomBar
                            .offset(y: 10)
                            .padding(.horizontal, 14)
                    } else {
                        videoModeLayout(in: proxy.size)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .ignoresSafeArea(edges: .horizontal)
            }

            CaptureModeTransitionOverlay(
                targetMode: modeTransitionTarget,
                rotationDegrees: previewControlRotationDegrees,
                isActive: isModeTransitionVisible
            )
            .opacity(isModeTransitionVisible ? 1 : 0)
            .allowsHitTesting(isModeTransitionVisible)
            .animation(.easeInOut(duration: 0.14), value: isModeTransitionVisible)
            .zIndex(100)
        }
        .fullScreenCover(isPresented: $showsControlMenu, onDismiss: {
            guard cameraManager.captureMode == .photo,
                  !cameraManager.photoProExposureEnabled else { return }
            showsPhotoExposureBiasPanel = true
        }) {
            CameraSettingsView(cameraManager: cameraManager)
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            updatePreviewControlRotation(for: UIDevice.current.orientation)
            if cameraManager.captureMode == .photo {
                showsPhotoExposureBiasPanel = !cameraManager.photoProExposureEnabled
                activePhotoProAdjustment = cameraManager.photoProExposureEnabled ? .iso : nil
                activeVideoProAdjustment = nil
            } else {
                showsPhotoExposureBiasPanel = false
                activePhotoProAdjustment = nil
                activeVideoProAdjustment = cameraManager.proExposureEnabled ? .iso : nil
            }
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
            showsFocusPanel = false
            if cameraManager.captureMode == .photo {
                showsPhotoExposureBiasPanel = !cameraManager.photoProExposureEnabled
                activePhotoProAdjustment = cameraManager.photoProExposureEnabled ? .iso : nil
                activeVideoProAdjustment = nil
            } else {
                showsPhotoExposureBiasPanel = false
                activePhotoProAdjustment = nil
                activeVideoProAdjustment = cameraManager.proExposureEnabled ? .iso : nil
            }
        }
        .onChange(of: cameraManager.isSwitchingCaptureMode) { _, isSwitching in
            guard !isSwitching, isModeTransitionVisible else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                isModeTransitionVisible = false
            }
        }
        .onChange(of: cameraManager.photoProExposureEnabled) { _, isEnabled in
            withAnimation(.easeOut(duration: 0.18)) {
                if isEnabled {
                    showsPhotoExposureBiasPanel = false
                    activePhotoProAdjustment = .iso
                } else {
                    showsPhotoExposureBiasPanel = true
                    activePhotoProAdjustment = nil
                }
            }
        }
        .onChange(of: cameraManager.proExposureEnabled) { _, isEnabled in
            if isEnabled {
                activeVideoProAdjustment = activeVideoProAdjustment ?? .iso
            } else {
                showsWhiteBalancePanel = false
                showsFocusPanel = false
                activeVideoProAdjustment = nil
            }
        }
        .onChange(of: cameraManager.supportsManualFocus) { _, supportsManualFocus in
            if !supportsManualFocus {
                showsFocusPanel = false
                if activePhotoProAdjustment == .focus {
                    activePhotoProAdjustment = nil
                }
                if activeVideoProAdjustment == .focus {
                    activeVideoProAdjustment = cameraManager.captureMode == .video && cameraManager.proExposureEnabled ? .iso : nil
                }
            }
        }
    }

    private var topControlStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 8) {
                if cameraManager.captureMode == .photo {
                    compactControlChip(title: "M", isSelected: cameraManager.photoProExposureEnabled) {
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
                                activePhotoProAdjustment = .shutterSpeed
                            }
                        }

                        compactActionChip(
                            title: "ISO \(cameraManager.currentISOValueLabel)",
                            isSelected: activePhotoProAdjustment == .iso
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showsPhotoExposureBiasPanel = false
                                activePhotoProAdjustment = .iso
                            }
                        }

                        compactActionChip(
                            title: "WB \(photoWhiteBalanceChipLabel)",
                            isSelected: activePhotoProAdjustment == .whiteBalance
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showsPhotoExposureBiasPanel = false
                                activePhotoProAdjustment = .whiteBalance
                            }
                        }

                        if cameraManager.supportsManualFocus {
                            compactActionChip(
                                title: "AF/MF",
                                isSelected: activePhotoProAdjustment == .focus
                            ) {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    showsPhotoExposureBiasPanel = false
                                    activePhotoProAdjustment = .focus
                                }
                            }
                        }
                    }
                } else {
                    compactControlChip(title: "M", isSelected: cameraManager.proExposureEnabled) {
                        let isEnabling = !cameraManager.proExposureEnabled
                        activeVideoProAdjustment = isEnabling ? (activeVideoProAdjustment ?? .iso) : nil
                        cameraManager.setProExposureEnabled(isEnabling)
                    }

                    if cameraManager.proExposureEnabled {
                        compactActionChip(
                            title: "SS \(cameraManager.currentShutterSpeedLabel)",
                            isSelected: activeVideoProAdjustment == .shutterSpeed
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                activeVideoProAdjustment = .shutterSpeed
                            }
                        }

                        compactActionChip(
                            title: "ISO \(cameraManager.currentISOValueLabel)",
                            isSelected: activeVideoProAdjustment == .iso
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                activeVideoProAdjustment = .iso
                            }
                        }

                        compactActionChip(
                            title: "WB \(whiteBalanceValueLabel)",
                            isSelected: activeVideoProAdjustment == .whiteBalance
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                activeVideoProAdjustment = .whiteBalance
                            }
                        }

                        compactActionChip(
                            title: "MF \(focusValueLabel)",
                            isSelected: activeVideoProAdjustment == .focus
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                activeVideoProAdjustment = .focus
                            }
                        }
                        .disabled(!cameraManager.supportsManualFocus)
                        .opacity(cameraManager.supportsManualFocus ? 1 : 0.45)
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    private func videoModeLayout(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            previewSurface(
                width: videoPreviewWidth(for: size),
                forceFullWidth: false,
                showsBottomOverlay: false
            )
            .padding(.top, 12)

            videoAdjustmentDock
                .padding(.top, 8)

            Spacer(minLength: 0)

            videoBottomBar
                .offset(y: 10)
                .padding(.horizontal, 14)
        }
    }

    private func previewSurface(width: CGFloat, forceFullWidth: Bool) -> some View {
        previewSurface(width: width, forceFullWidth: forceFullWidth, showsBottomOverlay: true)
    }

    private func previewSurface(
        width: CGFloat,
        forceFullWidth: Bool,
        showsBottomOverlay: Bool
    ) -> some View {
        CameraPreviewView(cameraManager: cameraManager, isSuspended: showsControlMenu)
            .frame(
                width: width,
                height: forceFullWidth ? (width / cameraManager.previewAspectRatio) : nil
            )
            .frame(maxWidth: .infinity)
            .aspectRatio(cameraManager.previewAspectRatio, contentMode: forceFullWidth ? .fill : .fit)
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
            .overlay(alignment: .topLeading) {
                if showsPhotoMeteringResetButton {
                    photoMeteringResetButton
                        .padding(14)
                        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topLeading)))
                }
            }
            .overlay(alignment: .bottom) {
                if !showsBottomOverlay,
                   let statusMessage = videoPreviewStatusMessage {
                    Text(statusMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .metalRoundedPanel(cornerRadius: 16)
                        .padding(.bottom, 14)
                }
            }
            .overlay(alignment: .bottom) {
                if showsBottomOverlay {
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
    }

    private func videoPreviewWidth(for size: CGSize) -> CGFloat {
        let maxWidth = max(size.width - 28, 180)
        let reservedHeight: CGFloat = size.width > size.height ? 172 : 216
        let maxHeight = max(size.height - reservedHeight, 220)
        let fittedHeight = min(maxWidth / cameraManager.previewAspectRatio, maxHeight)
        return fittedHeight * cameraManager.previewAspectRatio
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
                                        .offset(videoQuickAdjustmentPanelOffset(for: activeVideoQuickAdjustment))
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
                                        .offset(videoQuickAdjustmentPanelOffset(for: activeVideoQuickAdjustment))
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
        VStack(spacing: 10) {
            if let statusMessage = photoPreviewStatusMessage {
                Text(statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .metalRoundedPanel(cornerRadius: 16)
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

    private var videoPreviewStatusMessage: String? {
        guard cameraManager.captureMode == .video else { return nil }
        return cameraManager.statusMessage
    }

    private var showsPhotoMeteringResetButton: Bool {
        cameraManager.captureMode == .photo && cameraManager.photoMeteringHandlesVisible
    }

    private var photoBottomBar: some View {
        HStack(spacing: 0) {
            HStack {
                captureModeSwitchButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)

            recordButton

            HStack {
                controlsButton
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .center)
    }

    private var videoBottomBar: some View {
        VStack(spacing: 6) {
            lensPickerStrip
                .padding(.bottom, 0)

            HStack(spacing: 0) {
                HStack {
                    captureModeSwitchButton
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)

                recordButton

                HStack {
                    controlsButton
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 10)
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
        }
    }

    private var photoAdjustmentHeaderRowHeight: CGFloat {
        14
    }

    private var photoAdjustmentDock: some View {
        ZStack {
            if cameraManager.photoProExposureEnabled,
               let activePhotoProAdjustment {
                photoProAdjustmentPanel(for: activePhotoProAdjustment)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else if showsPhotoExposureBiasPanel && !cameraManager.photoProExposureEnabled {
                photoExposureBiasAdjustmentPanel
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var videoAdjustmentDock: some View {
        ZStack {
            if cameraManager.proExposureEnabled,
               let activeVideoProAdjustment {
                videoProAdjustmentPanel(for: activeVideoProAdjustment)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else if cameraManager.supportsExposureBiasAdjustment {
                videoExposureBiasAdjustmentPanel
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func photoProAdjustmentPanel(for adjustment: PhotoProAdjustment) -> some View {
        let sliderBinding = photoSliderBinding(for: adjustment)
        let sliderRange = 0...Double(max(photoAdjustmentStepCount(for: adjustment) - 1, 0))

        switch adjustment {
        case .whiteBalance:
            photoAdjustmentHeaderPanel(
                sliderBinding: sliderBinding,
                sliderRange: sliderRange
            ) {
                HStack {
                    Spacer(minLength: 0)
                    photoWhiteBalanceResetButton
                }
            }
        case .focus:
            photoAdjustmentHeaderPanel(
                sliderBinding: sliderBinding,
                sliderRange: sliderRange
            ) {
                HStack {
                    Spacer(minLength: 0)
                    photoFocusResetButton
                }
            }
        case .shutterSpeed, .iso:
            photoAdjustmentPlainPanel(
                sliderBinding: sliderBinding,
                sliderRange: sliderRange
            )
        }
    }

    private var photoExposureBiasAdjustmentPanel: some View {
        photoAdjustmentHeaderPanel(
            sliderBinding: photoExposureBiasSliderBinding,
            sliderRange: 0...Double(max(photoExposureBiasValues.count - 1, 0))
        ) {
            HStack(alignment: .center, spacing: 10) {
                Text(String(format: "%+.1f EV", cameraManager.exposureBias))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                photoExposureBiasResetButton
            }
        }
    }

    @ViewBuilder
    private func videoProAdjustmentPanel(for adjustment: VideoProAdjustment) -> some View {
        let sliderBinding = videoSliderBinding(for: adjustment)
        let sliderRange = 0...Double(max(videoAdjustmentStepCount(for: adjustment) - 1, 0))

        switch adjustment {
        case .whiteBalance:
            photoAdjustmentHeaderPanel(
                sliderBinding: sliderBinding,
                sliderRange: sliderRange
            ) {
                HStack {
                    Spacer(minLength: 0)
                    photoWhiteBalanceResetButton
                }
            }
        case .focus:
            photoAdjustmentHeaderPanel(
                sliderBinding: sliderBinding,
                sliderRange: sliderRange
            ) {
                HStack {
                    Spacer(minLength: 0)
                    photoFocusResetButton
                }
            }
        case .shutterSpeed, .iso:
            photoAdjustmentPlainPanel(
                sliderBinding: sliderBinding,
                sliderRange: sliderRange
            )
        }
    }

    private var videoExposureBiasAdjustmentPanel: some View {
        photoAdjustmentPanelContainer {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    Text(String(format: "%+.1f EV", cameraManager.exposureBias))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    photoExposureBiasResetButton
                }
                .frame(height: photoAdjustmentHeaderRowHeight)
                .frame(maxWidth: .infinity)

                DiscreteLandscapeSlider(
                    value: Binding(
                        get: { Double(cameraManager.exposureBias) },
                        set: { cameraManager.setExposureBias(Float($0)) }
                    ),
                    range: Double(cameraManager.videoExposureBiasRange.lowerBound)...Double(cameraManager.videoExposureBiasRange.upperBound),
                    step: 0.1
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
            }
        }
    }

    private func photoAdjustmentPlainPanel(
        sliderBinding: Binding<Double>,
        sliderRange: ClosedRange<Double>
    ) -> some View {
        photoAdjustmentPanelContainer {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: photoAdjustmentHeaderRowHeight)

                photoAdjustmentSliderTrack(
                    sliderBinding: sliderBinding,
                    sliderRange: sliderRange
                )
                .padding(.top, 2)
            }
        }
    }

    private func photoAdjustmentHeaderPanel<Header: View>(
        sliderBinding: Binding<Double>,
        sliderRange: ClosedRange<Double>,
        @ViewBuilder header: () -> Header
    ) -> some View {
        photoAdjustmentPanelContainer {
            VStack(alignment: .leading, spacing: 0) {
                header()
                    .frame(height: photoAdjustmentHeaderRowHeight)
                    .frame(maxWidth: .infinity)

                photoAdjustmentSliderTrack(
                    sliderBinding: sliderBinding,
                    sliderRange: sliderRange
                )
                .padding(.top, 2)
            }
        }
    }

    private func photoAdjustmentPanelContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func photoAdjustmentSliderTrack(
        sliderBinding: Binding<Double>,
        sliderRange: ClosedRange<Double>
    ) -> some View {
        DiscreteLandscapeSlider(
            value: sliderBinding,
            range: sliderRange,
            step: 1
        )
        .frame(maxWidth: .infinity)
    }

    private var quickAdjustments: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if !cameraManager.proExposureEnabled {
                quickAdjustButton(title: "EXP", isActive: showsExposurePanel || isExposureAdjusted) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showsWhiteBalancePanel = false
                        showsFocusPanel = false
                        showsExposurePanel.toggle()
                    }
                }
                .disabled(!cameraManager.supportsExposureBiasAdjustment)
                .opacity(cameraManager.supportsExposureBiasAdjustment ? 1 : 0.45)
            }

            if cameraManager.proExposureEnabled {
                quickAdjustButton(title: "WB", isActive: showsWhiteBalancePanel || isWhiteBalanceAdjusted) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showsExposurePanel = false
                        showsFocusPanel = false
                        showsWhiteBalancePanel.toggle()
                    }
                }

                quickAdjustButton(title: "F", isActive: showsFocusPanel || isFocusAdjusted) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showsWhiteBalancePanel = false
                        showsExposurePanel = false
                        showsFocusPanel.toggle()
                    }
                }
                .disabled(!cameraManager.supportsManualFocus)
                .opacity(cameraManager.supportsManualFocus ? 1 : 0.45)
            }

            controlsButton
        }
    }

    private var activeVideoQuickAdjustment: VideoQuickAdjustment? {
        if cameraManager.proExposureEnabled && showsFocusPanel {
            return .focus
        }
        if cameraManager.proExposureEnabled && showsWhiteBalancePanel {
            return .whiteBalance
        }
        if !cameraManager.proExposureEnabled && showsExposurePanel {
            return .exposure
        }
        return nil
    }

    private var videoQuickAdjustmentColumnWidth: CGFloat {
        56
    }

    private var videoQuickAdjustmentHorizontalPadding: CGFloat {
        8
    }

    private var videoWhiteBalancePanelWidth: CGFloat {
        76
    }

    private func videoQuickAdjustmentPanelOffset(for adjustment: VideoQuickAdjustment) -> CGSize {
        guard adjustment == .whiteBalance || adjustment == .focus else {
            return .zero
        }

        if isLandscapePreviewOrientation {
            return CGSize(width: 0, height: 14)
        }

        return CGSize(width: 0, height: 8)
    }

    @ViewBuilder
    private func videoQuickAdjustmentPanel(for adjustment: VideoQuickAdjustment) -> some View {
        switch adjustment {
        case .exposure:
            videoVerticalExposureQuickPanel
        case .whiteBalance:
            videoVerticalWhiteBalanceQuickPanel
        case .focus:
            videoVerticalFocusQuickPanel
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
                        .foregroundStyle(isExposureAdjusted ? AppTheme.textPrimary : AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .metalCapsulePanel(isActive: isExposureAdjusted)
                }
                .buttonStyle(.plain)
                .expandedTapTarget(horizontal: 3, vertical: 11)
                .disabled(!isExposureAdjusted)

                Text(String(format: "%+.1f EV", cameraManager.exposureBias))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            SteppedHapticSlider(
                value: Binding(
                    get: { Double(cameraManager.exposureBias) },
                    set: { cameraManager.setExposureBias(Float($0)) }
                ),
                range: Double(cameraManager.videoExposureBiasRange.lowerBound)...Double(cameraManager.videoExposureBiasRange.upperBound),
                step: 0.1,
                tint: AppTheme.accent
            )
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

            Text(String(format: "%+.1f", cameraManager.exposureBias))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .rotationEffect(.degrees(previewControlRotationDegrees))

            DiscreteLandscapeSlider(
                value: Binding(
                    get: { Double(cameraManager.exposureBias) },
                    set: { cameraManager.setExposureBias(Float($0)) }
                ),
                range: Double(cameraManager.videoExposureBiasRange.lowerBound)...Double(cameraManager.videoExposureBiasRange.upperBound),
                step: 0.1
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
                    .foregroundStyle(isExposureAdjusted ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .metalCapsulePanel(isActive: isExposureAdjusted)
                    .rotationEffect(.degrees(previewControlRotationDegrees))
            }
            .buttonStyle(.plain)
            .expandedTapTarget(horizontal: 3, vertical: 11)
            .disabled(!isExposureAdjusted)
        }
        .padding(.horizontal, videoQuickAdjustmentHorizontalPadding)
        .padding(.vertical, 14)
        .frame(width: videoQuickAdjustmentColumnWidth)
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
                Text(whiteBalanceValueLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            SteppedHapticSlider(
                value: Binding(
                    get: { cameraManager.whiteBalanceTemperature },
                    set: { cameraManager.setWhiteBalanceTemperature($0) }
                ),
                range: cameraManager.whiteBalanceTemperatureRange,
                step: 100,
                tint: AppTheme.accent
            )

            HStack {
                Text("2500K")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Button {
                    cameraManager.setWhiteBalanceAuto()
                } label: {
                    Text("Auto")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 40, minHeight: 24)
                        .metalCapsulePanel(isActive: !cameraManager.usesManualWhiteBalance)
                }
                .buttonStyle(.plain)
                .expandedTapTarget(horizontal: 3, vertical: 10)

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
        VStack(spacing: isLandscapePreviewOrientation ? 12 : 10) {
            Text("WB")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(AppTheme.textSecondary)
                .rotationEffect(.degrees(previewControlRotationDegrees))

            Text(whiteBalanceValueLabel)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .rotationEffect(.degrees(previewControlRotationDegrees))
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: isLandscapePreviewOrientation ? 20 : nil)
                .frame(height: isLandscapePreviewOrientation ? 70 : nil)

            DiscreteLandscapeSlider(
                value: Binding(
                    get: { cameraManager.whiteBalanceTemperature },
                    set: { cameraManager.setWhiteBalanceTemperature($0) }
                ),
                range: cameraManager.whiteBalanceTemperatureRange,
                step: 100
            )
            .tint(AppTheme.accent)
            .frame(width: 236)
            .rotationEffect(.degrees(-90))
            .frame(width: 34, height: 236)

            Button {
                cameraManager.setWhiteBalanceAuto()
            } label: {
                Text("Auto")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .frame(minWidth: 56, minHeight: 24)
                    .lineLimit(1)
                    .metalCapsulePanel(isActive: !cameraManager.usesManualWhiteBalance)
                    .rotationEffect(.degrees(previewControlRotationDegrees))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.plain)
            .expandedTapTarget(horizontal: 3, vertical: 10)
            .frame(
                width: isLandscapePreviewOrientation ? 24 : nil,
                height: isLandscapePreviewOrientation ? 70 : nil
            )
        }
        .padding(.horizontal, videoQuickAdjustmentHorizontalPadding)
        .padding(.vertical, isLandscapePreviewOrientation ? 16 : 14)
        .frame(width: videoWhiteBalancePanelWidth)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surfaceRaised.opacity(0.36))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.7)
        )
    }

    private var videoVerticalFocusQuickPanel: some View {
        VStack(spacing: 10) {
            Text("MF")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(AppTheme.textSecondary)
                .rotationEffect(.degrees(previewControlRotationDegrees))

            Text(focusValueLabel)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .rotationEffect(.degrees(previewControlRotationDegrees))

            DiscreteLandscapeSlider(
                value: Binding(
                    get: { Double(cameraManager.manualFocusPosition) },
                    set: { cameraManager.setManualFocusPosition(Float($0)) }
                ),
                range: 0...1,
                step: 0.01
            )
            .tint(AppTheme.accent)
            .frame(width: 236)
            .rotationEffect(.degrees(-90))
            .frame(width: 34, height: 236)

            Button {
                cameraManager.setManualFocusEnabled(false)
            } label: {
                Text("A")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isFocusAdjusted ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .metalCapsulePanel(isActive: isFocusAdjusted)
                    .rotationEffect(.degrees(previewControlRotationDegrees))
            }
            .buttonStyle(.plain)
            .expandedTapTarget(horizontal: 3, vertical: 11)
            .disabled(!isFocusAdjusted)
        }
        .padding(.horizontal, videoQuickAdjustmentHorizontalPadding)
        .padding(.vertical, 14)
        .frame(width: videoQuickAdjustmentColumnWidth)
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
                        .foregroundStyle(AppTheme.textPrimary)
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
                .expandedTapTarget(horizontal: 3, vertical: 5)
                .disabled(cameraManager.isCaptureBusy)
            }
        }
    }

    private var recordButton: some View {
        Button {
            if cameraManager.captureMode == .photo {
                playPhotoShutterAnimation()
            }
            cameraManager.triggerPrimaryCapture()
        } label: {
            ZStack {
                if cameraManager.captureMode == .photo {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.28, green: 0.29, blue: 0.33),
                                    Color(red: 0.11, green: 0.12, blue: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .stroke(AppTheme.accent.opacity(0.92), lineWidth: 2.4)
                        )
                        .shadow(color: AppTheme.accent.opacity(0.20), radius: 9)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.38), lineWidth: 1)
                                .padding(3)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                                .padding(8)
                        )

                    PhotoShutterCore(isClosed: isPhotoShutterAnimating)
                        .frame(width: 48, height: 48)
                        .scaleEffect(isPhotoShutterAnimating ? 0.94 : 1)
                } else {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.94), lineWidth: 4)
                        .frame(width: 74, height: 74)
                        .background(
                            Circle()
                                .fill(AppTheme.surfaceGradient)
                                .frame(width: 74, height: 74)
                        )

                    if cameraManager.isRecording {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.recordLive)
                            .frame(width: 28, height: 28)
                    } else {
                        Circle()
                            .fill(
                                cameraManager.canTriggerCapture
                                    ? AppTheme.activeGradient
                                    : LinearGradient(colors: [Color.gray.opacity(0.65), Color.gray.opacity(0.28)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 50, height: 50)
                    }
                }
            }
            .offset(y: cameraManager.captureMode == .photo ? 0 : 6)
            .frame(
                width: cameraManager.captureMode == .photo ? 96 : 106,
                height: cameraManager.captureMode == .photo ? 96 : 106
            )
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!cameraManager.canTriggerCapture)
    }

    private func playPhotoShutterAnimation() {
        withAnimation(.easeIn(duration: 0.045)) {
            isPhotoShutterAnimating = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.075) {
            withAnimation(.easeOut(duration: 0.085)) {
                isPhotoShutterAnimating = false
            }
        }
    }

    private var captureModeSwitchButton: some View {
        Button {
            beginCaptureModeSwitch()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: cameraManager.captureMode == .video ? "camera.fill" : "video.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(cameraManager.captureMode.switchButtonTitle)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.7)
            }
            .foregroundStyle(AppTheme.textPrimary)
            .frame(width: 48, height: 48)
            .metalCirclePanel()
        }
        .buttonStyle(.plain)
        .disabled(cameraManager.isCaptureBusy)
        .rotationEffect(.degrees(previewControlRotationDegrees))
    }

    private func beginCaptureModeSwitch() {
        guard !isModeTransitionVisible, !cameraManager.isCaptureBusy else { return }
        modeTransitionTarget = cameraManager.captureMode == .video ? .photo : .video
        isModeTransitionVisible = true

        // Let SwiftUI present the lightweight cover before AVFoundation begins
        // rebuilding the capture session and its Metal-backed preview surfaces.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            cameraManager.switchCaptureMode()
        }
    }

    private var controlsButton: some View {
        Button {
            showsExposurePanel = false
            showsWhiteBalancePanel = false
            showsFocusPanel = false
            showsControlMenu.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 48, height: 48)
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

    private var isFocusAdjusted: Bool {
        cameraManager.supportsManualFocus && cameraManager.manualFocusEnabled
    }

    private var showsQuickAdjustmentPanel: Bool {
        showsExposurePanel || showsWhiteBalancePanel || showsFocusPanel
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

    private var videoShutterSliderBinding: Binding<Double> {
        Binding(
            get: {
                Double(videoCurrentShutterIndex)
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

    private var videoISOSliderBinding: Binding<Double> {
        Binding(
            get: {
                Double(videoCurrentISOIndex)
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

    private var videoWhiteBalanceSliderBinding: Binding<Double> {
        Binding(
            get: {
                Double(videoCurrentWhiteBalanceIndex)
            },
            set: { newValue in
                let values = photoWhiteBalanceValues
                let index = photoClampedIndex(for: newValue, count: values.count)
                guard values.indices.contains(index) else { return }
                cameraManager.setWhiteBalanceTemperature(values[index])
            }
        )
    }

    private var photoFocusSliderBinding: Binding<Double> {
        Binding(
            get: {
                Double(photoCurrentFocusIndex)
            },
            set: { newValue in
                let index = photoClampedIndex(for: newValue, count: 101)
                cameraManager.setManualFocusPosition(Float(index) / 100)
            }
        )
    }

    private var videoFocusSliderBinding: Binding<Double> {
        Binding(
            get: {
                Double(videoCurrentFocusIndex)
            },
            set: { newValue in
                let index = photoClampedIndex(for: newValue, count: 101)
                cameraManager.setManualFocusPosition(Float(index) / 100)
            }
        )
    }

    private var photoCurrentShutterIndex: Int {
        let values = cameraManager.availableShutterSpeedDenominators
        return values.firstIndex(of: cameraManager.currentShutterSpeedDenominator) ?? 0
    }

    private var videoCurrentShutterIndex: Int {
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

    private var videoCurrentISOIndex: Int {
        let values = cameraManager.availableISOValues
        guard !values.isEmpty else { return 0 }

        return values.enumerated().min { lhs, rhs in
            abs(lhs.element - cameraManager.manualISO) < abs(rhs.element - cameraManager.manualISO)
        }?.offset ?? 0
    }

    private var photoCurrentWhiteBalanceIndex: Int {
        let values = photoWhiteBalanceValues
        guard !values.isEmpty else { return 0 }

        let currentTemperature = cameraManager.whiteBalanceTemperature
        let closestIndex = values.enumerated().min { lhs, rhs in
            abs(lhs.element - currentTemperature) < abs(rhs.element - currentTemperature)
        }?.offset ?? 0
        return closestIndex
    }

    private var videoCurrentWhiteBalanceIndex: Int {
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

    private var photoCurrentFocusIndex: Int {
        min(max(Int((Double(cameraManager.manualFocusPosition) * 100).rounded()), 0), 100)
    }

    private var videoCurrentFocusIndex: Int {
        min(max(Int((Double(cameraManager.manualFocusPosition) * 100).rounded()), 0), 100)
    }

    private func photoAdjustmentStepCount(for adjustment: PhotoProAdjustment) -> Int {
        switch adjustment {
        case .shutterSpeed:
            return cameraManager.availableShutterSpeedDenominators.count
        case .iso:
            return cameraManager.availableISOValues.count
        case .whiteBalance:
            return photoWhiteBalanceValues.count
        case .focus:
            return 101
        }
    }

    private func videoAdjustmentStepCount(for adjustment: VideoProAdjustment) -> Int {
        switch adjustment {
        case .shutterSpeed:
            return cameraManager.availableShutterSpeedDenominators.count
        case .iso:
            return cameraManager.availableISOValues.count
        case .whiteBalance:
            return photoWhiteBalanceValues.count
        case .focus:
            return 101
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
        case .focus:
            return photoFocusSliderBinding
        }
    }

    private func videoSliderBinding(for adjustment: VideoProAdjustment) -> Binding<Double> {
        switch adjustment {
        case .shutterSpeed:
            return videoShutterSliderBinding
        case .iso:
            return videoISOSliderBinding
        case .whiteBalance:
            return videoWhiteBalanceSliderBinding
        case .focus:
            return videoFocusSliderBinding
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

    private var whiteBalanceValueLabel: String {
        String(format: "%.0f K", cameraManager.whiteBalanceTemperature)
    }

    private var photoWhiteBalanceResetButton: some View {
        Button {
            cameraManager.setWhiteBalanceAuto()
        } label: {
            Text("Auto")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 5)
                .frame(minWidth: 24, minHeight: 16)
                .metalCapsulePanel(isActive: !cameraManager.usesManualWhiteBalance)
        }
        .buttonStyle(.plain)
        .expandedTapTarget(horizontal: 4, vertical: 14)
        .fixedSize()
    }

    private var photoFocusResetButton: some View {
        Button {
            cameraManager.setManualFocusEnabled(false)
        } label: {
            Text("AF")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 5)
                .frame(minWidth: 20, minHeight: 16)
                .metalCapsulePanel(isActive: !cameraManager.manualFocusEnabled)
        }
        .buttonStyle(.plain)
        .expandedTapTarget(horizontal: 4, vertical: 14)
    }

    private var focusValueLabel: String {
        guard cameraManager.supportsManualFocus else { return "--" }
        guard cameraManager.manualFocusEnabled else { return "A" }
        return String(format: "%.2f", cameraManager.manualFocusPosition)
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
                .foregroundStyle(AppTheme.textPrimary)
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
                showsPhotoExposureBiasPanel = true
            }
        } label: {
            Text("EV")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 44, height: 28)
                .metalCapsulePanel(isActive: photoExposureBiasButtonIsActive)
        }
        .buttonStyle(.plain)
        .expandedTapTarget(horizontal: 3, vertical: 8)
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
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(isExposureAdjusted ? AppTheme.textPrimary : AppTheme.textSecondary)
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 16)
                .metalCapsulePanel(isActive: isExposureAdjusted)
        }
        .buttonStyle(.plain)
        .expandedTapTarget(horizontal: 4, vertical: 14)
        .disabled(!isExposureAdjusted)
    }

    private var photoMeteringResetButton: some View {
        Button {
            cameraManager.clearPhotoMeteringSelection()
        } label: {
            ZStack {
                Circle()
                    .stroke(AppTheme.textPrimary, lineWidth: 1.7)
                    .frame(width: 14, height: 14)

                Capsule()
                    .fill(AppTheme.textPrimary)
                    .frame(width: 16, height: 1.9)
                    .rotationEffect(.degrees(-45))
            }
            .frame(width: 30, height: 30)
            .metalCirclePanel(isActive: true)
        }
        .buttonStyle(.plain)
        .expandedTapTarget(horizontal: 4, vertical: 7)
        .rotationEffect(.degrees(previewControlRotationDegrees))
    }

    private func compactToggleChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .metalCapsulePanel(isActive: isSelected)
        }
        .buttonStyle(.plain)
        .expandedTapTarget(horizontal: 3, vertical: 8)
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
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .metalCapsulePanel(isActive: isSelected)
        }
        .buttonStyle(.plain)
        .expandedTapTarget(horizontal: 3, vertical: 8)
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
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .metalCapsulePanel(isActive: isSelected)
        }
        .buttonStyle(.plain)
        .expandedTapTarget(horizontal: 3, vertical: 7)
    }
}

private struct CameraSettingsView: View {
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.dismiss) private var dismiss
    @State private var isPhotoExpanded = true
    @State private var isVideoExpanded = true
    @State private var showsQuickGuide = false

    var body: some View {
        ZStack(alignment: .top) {
            settingsBackground

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    appSection
                    photoSection
                    videoSection
                }
                .padding(.horizontal, 14)
                .padding(.top, 92)
                .padding(.bottom, 34)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)

            stickyHeader
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showsQuickGuide) {
            RawlightOnboardingView(cameraManager: cameraManager, mode: .quickGuide) {
                showsQuickGuide = false
            }
        }
    }

    private var settingsBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.11, green: 0.035, blue: 0.045),
                Color.black,
                Color(red: 0.075, green: 0.05, blue: 0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var stickyHeader: some View {
        HStack(spacing: 12) {
            Text("Settings")
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .metalCirclePanel()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.black.opacity(0.84))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.accent.opacity(0.28))
                .frame(height: 1)
        }
    }

    private var appSection: some View {
        settingsPanel(title: "App", icon: "camera.aperture") {
            settingsRow(title: "Startup Mode") {
                optionStrip {
                    ForEach(CaptureMode.allCases) { mode in
                        selectionButton(
                            title: mode.title,
                            isSelected: cameraManager.defaultCaptureMode == mode
                        ) {
                            cameraManager.selectDefaultCaptureMode(mode)
                        }
                    }
                }
            }

            settingsRow(title: "Help") {
                actionChip(title: "Quick Guide") {
                    showsQuickGuide = true
                }
            }
        }
    }

    private var photoSection: some View {
        collapsiblePanel(
            title: "Photo",
            subtitle: cameraManager.canCapturePhoto
                ? "\(cameraManager.photoRAWFormat.title) ready"
                : "\(cameraManager.photoRAWFormat.title) unavailable",
            icon: "camera.fill",
            isExpanded: $isPhotoExpanded
        ) {
            photoSettingsRows
        }
    }

    private var photoSettingsRows: some View {
        VStack(spacing: 0) {
            settingsRow(title: "Default Lens") {
                optionStrip {
                    ForEach(PhotoDefaultWideFocalLength.allCases) { focalLength in
                        selectionButton(
                            title: focalLength.title,
                            isSelected: cameraManager.photoDefaultWideFocalLength == focalLength
                        ) {
                            cameraManager.selectPhotoDefaultWideFocalLength(focalLength)
                        }
                        .disabled(cameraManager.photoRAWFormat == .bayerRAW && focalLength != .mm24)
                        .opacity(cameraManager.photoRAWFormat == .bayerRAW && focalLength != .mm24 ? 0.45 : 1)
                    }
                }
            }

            settingsRow(title: "RAW Format") {
                VStack(alignment: .leading, spacing: 7) {
                    optionStrip {
                        ForEach(PhotoRAWFormat.allCases) { format in
                            selectionButton(
                                title: format.title,
                                isSelected: cameraManager.photoRAWFormat == format
                            ) {
                                cameraManager.selectPhotoRAWFormat(format)
                            }
                        }
                    }

                    if cameraManager.captureMode == .photo,
                       cameraManager.photoRAWFormat == .bayerRAW,
                       !cameraManager.bayerRAWSupported {
                        Text("Pure RAW is not exposed by the current iOS camera pipeline. Select ProRAW to continue shooting.")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.yellow.opacity(0.85))
                    }
                }
            }

            settingsRow(title: "Companion", detail: cameraManager.canCapturePhoto ? "DNG base" : "RAW off") {
                optionStrip {
                    ForEach(PhotoCompanionFormat.allCases) { format in
                        selectionButton(
                            title: format.title,
                            isSelected: cameraManager.photoCompanionFormat == format
                        ) {
                            cameraManager.selectPhotoCompanionFormat(format)
                        }
                    }
                }
            }

            settingsRow(title: "Resolution") {
                VStack(alignment: .leading, spacing: 7) {
                    optionStrip {
                        ForEach(PhotoResolutionOption.allCases) { option in
                            selectionButton(
                                title: option.title,
                                isSelected: cameraManager.photoResolutionOption == option
                            ) {
                                cameraManager.selectPhotoResolutionOption(option)
                            }
                            .disabled(cameraManager.photoRAWFormat == .bayerRAW && option == .full)
                            .opacity(cameraManager.photoRAWFormat == .bayerRAW && option == .full ? 0.45 : 1)
                        }
                    }

                    Text("Manual exposure and Pure RAW support up to 12 MP.")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            photoMeteringRow
            zebraRows(for: .photo)
            focusPeakingRows(for: .photo)

            settingsRow(title: "Grid") {
                optionStrip {
                    selectionButton(title: "Off", isSelected: !cameraManager.photoGridEnabled) {
                        cameraManager.photoGridEnabled = false
                    }
                    selectionButton(title: "On", isSelected: cameraManager.photoGridEnabled) {
                        cameraManager.photoGridEnabled = true
                    }
                }
            }
        }
    }

    private var photoMeteringRow: some View {
        let forcesLinked = cameraManager.photoProExposureEnabled

        return settingsRow(title: "Metering", detail: forcesLinked ? "Manual links AF/EV" : nil) {
            optionStrip {
                selectionButton(
                    title: "Separate",
                    isSelected: !cameraManager.effectivePhotoMeteringPointsLinked
                ) {
                    cameraManager.photoMeteringPointsLinked = false
                }
                .disabled(forcesLinked)
                .opacity(forcesLinked ? 0.45 : 1)

                selectionButton(
                    title: "Linked",
                    isSelected: cameraManager.effectivePhotoMeteringPointsLinked
                ) {
                    cameraManager.photoMeteringPointsLinked = true
                }
            }
        }
    }

    private var videoSection: some View {
        collapsiblePanel(
            title: "Video",
            subtitle: "\(cameraManager.selectedVideoResolution.title) - \(cameraManager.selectedFrameRate) fps - \(cameraManager.selectedVideoCodec.title)",
            icon: "video.fill",
            isExpanded: $isVideoExpanded
        ) {
            videoSettingsRows
        }
    }

    private var videoSettingsRows: some View {
        VStack(spacing: 0) {
            settingsRow(title: "Preview") {
                optionStrip {
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

            zebraRows(for: .video)
            focusPeakingRows(for: .video)

            settingsRow(title: "Resolution") {
                optionStrip {
                    ForEach(VideoResolution.allCases) { resolution in
                        selectionButton(
                            title: resolution.title,
                            isSelected: cameraManager.selectedVideoResolution == resolution
                        ) {
                            cameraManager.selectVideoResolution(resolution)
                        }
                        .disabled(cameraManager.isRecording)
                        .opacity(cameraManager.isRecording ? 0.45 : 1)
                    }
                }
            }

            settingsRow(title: "Frame Rate") {
                optionStrip {
                    ForEach(CameraManager.supportedFrameRates, id: \.self) { fps in
                        selectionButton(
                            title: "\(fps)",
                            isSelected: cameraManager.selectedFrameRate == fps
                        ) {
                            cameraManager.selectFrameRate(fps)
                        }
                        .disabled(cameraManager.isRecording)
                        .opacity(cameraManager.isRecording ? 0.45 : 1)
                    }
                }
            }

            settingsRow(title: "Codec") {
                optionStrip {
                    ForEach(VideoRecordingCodec.allCases) { codec in
                        selectionButton(
                            title: codec.title,
                            isSelected: cameraManager.selectedVideoCodec == codec
                        ) {
                            cameraManager.selectVideoCodec(codec)
                        }
                    }
                }
            }

            bitrateRow
            audioRows
            stabilizationRow
            lockRow

            settingsRow(title: "Grid") {
                optionStrip {
                    selectionButton(title: "Off", isSelected: !cameraManager.videoGridEnabled) {
                        cameraManager.videoGridEnabled = false
                    }
                    selectionButton(title: "On", isSelected: cameraManager.videoGridEnabled) {
                        cameraManager.videoGridEnabled = true
                    }
                }
            }
        }
    }

    private func zebraRows(for mode: CaptureMode) -> some View {
        Group {
            settingsRow(title: "Zebras") {
                optionStrip {
                    selectionButton(
                        title: "Off",
                        isSelected: !cameraManager.isZebraEnabled(for: mode)
                    ) {
                        cameraManager.setZebraEnabled(false, for: mode)
                    }
                    selectionButton(
                        title: "On",
                        isSelected: cameraManager.isZebraEnabled(for: mode)
                    ) {
                        cameraManager.setZebraEnabled(true, for: mode)
                    }
                }
            }

            sliderRow(
                title: "Zebra Level",
                valueText: "\(cameraManager.zebraThresholdPercent(for: mode))%",
                value: Binding(
                    get: { Double(cameraManager.zebraThresholdPercent(for: mode)) },
                    set: { cameraManager.setZebraThresholdPercent(Int($0.rounded()), for: mode) }
                ),
                range: 80...100,
                tint: AppTheme.accent
            )

            settingsRow(title: "Zebra Color") {
                optionStrip {
                    ForEach(ZebraChannel.allCases) { channel in
                        selectionButton(
                            title: channel.title,
                            isSelected: cameraManager.zebraChannelSetting(for: mode) == channel
                        ) {
                            cameraManager.selectZebraChannel(channel, for: mode)
                        }
                    }
                }
            }
        }
    }

    private func focusPeakingRows(for mode: CaptureMode) -> some View {
        Group {
            settingsRow(title: "Peaking") {
                optionStrip {
                    selectionButton(
                        title: "Off",
                        isSelected: !cameraManager.isFocusPeakingEnabled(for: mode)
                    ) {
                        cameraManager.setFocusPeakingEnabled(false, for: mode)
                    }
                    selectionButton(
                        title: "On",
                        isSelected: cameraManager.isFocusPeakingEnabled(for: mode)
                    ) {
                        cameraManager.setFocusPeakingEnabled(true, for: mode)
                    }
                }
            }

            sliderRow(
                title: "Peaking Level",
                valueText: "\(cameraManager.focusPeakingSensitivityPercent(for: mode))",
                value: Binding(
                    get: { Double(cameraManager.focusPeakingSensitivityPercent(for: mode)) },
                    set: { cameraManager.setFocusPeakingSensitivityPercent(Int($0.rounded()), for: mode) }
                ),
                range: 20...100,
                tint: Color(red: 0.26, green: 0.92, blue: 0.42)
            )
        }
    }

    private var bitrateRow: some View {
        settingsRow(
            title: "Bitrate",
            detail: cameraManager.allowsCustomBitrate ? nil : "Codec managed",
            isEnabled: cameraManager.allowsCustomBitrate
        ) {
            optionStrip {
                ForEach(CameraManager.supportedBitratesMbps, id: \.self) { bitrate in
                    selectionButton(
                        title: String(format: "%.0f Mb/s", bitrate),
                        isSelected: cameraManager.recordingBitrateMbps == bitrate
                    ) {
                        cameraManager.setRecordingBitrateMbps(bitrate)
                    }
                }

                actionChip(title: cameraManager.usesCustomBitrate ? "Auto" : "Default") {
                    cameraManager.resetRecordingBitrateToDefault()
                }
            }
        }
        .disabled(!cameraManager.allowsCustomBitrate)
    }

    private var audioRows: some View {
        Group {
            settingsRow(title: "Audio", detail: cameraManager.activeVideoAudioModeTitle) {
                optionStrip {
                    ForEach(VideoAudioMode.allCases) { mode in
                        let isAvailable = cameraManager.audioCaptureAvailable &&
                            (mode == .mono || cameraManager.supportedVideoAudioModes.contains(.stereo))
                        selectionButton(
                            title: mode.title,
                            isSelected: cameraManager.videoAudioMode == mode
                        ) {
                            cameraManager.selectVideoAudioMode(mode)
                        }
                        .disabled(!isAvailable)
                        .opacity(isAvailable ? 1 : 0.45)
                    }
                }
            }

            settingsRow(title: "Wind Filter", isEnabled: cameraManager.canEnableVideoWindNoiseReduction) {
                optionStrip {
                    selectionButton(title: "Off", isSelected: !cameraManager.videoWindNoiseReductionEnabled) {
                        cameraManager.setVideoWindNoiseReductionEnabled(false)
                    }
                    selectionButton(title: "On", isSelected: cameraManager.videoWindNoiseReductionEnabled) {
                        cameraManager.setVideoWindNoiseReductionEnabled(true)
                    }
                }
            }
            .disabled(!cameraManager.canEnableVideoWindNoiseReduction)

            settingsRow(title: "Mic Mode", detail: "Preferred \(cameraManager.preferredMicrophoneModeTitle)") {
                optionStrip {
                    actionChip(title: cameraManager.activeMicrophoneModeTitle) {
                        cameraManager.openSystemMicrophoneModes()
                    }
                }
            }
        }
    }

    private var stabilizationRow: some View {
        settingsRow(title: "Stabilization", detail: cameraManager.activeStabilizationTitle) {
            optionStrip {
                ForEach(CaptureStabilizationMode.allCases) { mode in
                    let isAvailable = cameraManager.captureMode == .photo ||
                        cameraManager.supportedStabilizationModes.contains(mode)
                    selectionButton(
                        title: mode.title,
                        isSelected: cameraManager.selectedStabilizationMode == mode
                    ) {
                        cameraManager.selectStabilizationMode(mode)
                    }
                    .disabled(!isAvailable || cameraManager.isRecording)
                    .opacity(isAvailable && !cameraManager.isRecording ? 1 : 0.45)
                }
            }
        }
    }

    private var lockRow: some View {
        settingsRow(title: "REC Locks") {
            optionStrip {
                selectionButton(
                    title: "WB",
                    isSelected: cameraManager.whiteBalanceLockedDuringRecording
                ) {
                    cameraManager.whiteBalanceLockedDuringRecording.toggle()
                }
                selectionButton(
                    title: "AE",
                    isSelected: cameraManager.exposureLockedDuringRecording
                ) {
                    cameraManager.exposureLockedDuringRecording.toggle()
                }
            }
        }
    }

    private func settingsPanel<Content: View>(title: String,
                                              icon: String,
                                              @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            sectionHeader(title: title, subtitle: nil, icon: icon, isExpanded: nil)
            content()
        }
        .settingsPanelStyle()
    }

    private func collapsiblePanel<Content: View>(title: String,
                                                 subtitle: String,
                                                 icon: String,
                                                 isExpanded: Binding<Bool>,
                                                 @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.90, blendDuration: 0.04)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                sectionHeader(title: title, subtitle: subtitle, icon: icon, isExpanded: isExpanded.wrappedValue)
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
                    .clipped()
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .top)),
                            removal: .opacity
                        )
                    )
            }
        }
        .settingsPanelStyle()
    }

    private func sectionHeader(title: String,
                               subtitle: String?,
                               icon: String,
                               isExpanded: Bool?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 32, height: 32)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if let isExpanded {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(AppTheme.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .animation(.spring(response: 0.30, dampingFraction: 0.90), value: isExpanded)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private func settingsRow<Content: View>(title: String,
                                            detail: String? = nil,
                                            isEnabled: Bool = true,
                                            @ViewBuilder controls: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if let detail {
                    Text(detail)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)
            }

            controls()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .opacity(isEnabled ? 1 : 0.48)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 1)
        }
    }

    private func sliderRow(title: String,
                           valueText: String,
                           value: Binding<Double>,
                           range: ClosedRange<Double>,
                           tint: Color) -> some View {
        settingsRow(title: title, detail: valueText) {
            SteppedHapticSlider(
                value: value,
                range: range,
                step: 1,
                hapticStride: 5,
                tint: tint
            )
                .frame(minWidth: 156)
        }
    }

    private func optionStrip<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 76), spacing: 8, alignment: .leading)
            ],
            alignment: .leading,
            spacing: 8
        ) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectionButton(title: String,
                                 isSelected: Bool,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .frame(maxWidth: .infinity)
                .metalRoundedPanel(cornerRadius: 9, isActive: isSelected)
        }
        .buttonStyle(.plain)
        .expandedTapTarget(horizontal: 2, vertical: 5)
    }

    private func actionChip(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .black))
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .frame(maxWidth: .infinity)
            .metalRoundedPanel(cornerRadius: 9)
        }
        .buttonStyle(.plain)
        .expandedTapTarget(horizontal: 2, vertical: 5)
    }
}

private extension View {
    func settingsPanelStyle() -> some View {
        self
            .background(Color.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            )
    }
}

private enum RawlightOnboardingMode {
    case firstLaunch
    case quickGuide
}

private struct RawlightOnboardingView: View {
    private enum Page: CaseIterable {
        case welcome
        case camera
        case photos
        case microphone
        case controls
        case formats
    }

    private enum PermissionState {
        case notDetermined
        case allowed
        case denied
    }

    @ObservedObject var cameraManager: CameraManager
    let mode: RawlightOnboardingMode
    let onComplete: () -> Void

    @State private var pageIndex = 0
    @State private var isRequestingPermission = false

    private var pages: [Page] {
        switch mode {
        case .firstLaunch:
            return Page.allCases
        case .quickGuide:
            return [.controls, .formats]
        }
    }

    private var page: Page {
        pages[min(pageIndex, pages.count - 1)]
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            RadialGradient(
                colors: [Color.white.opacity(0.14), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 380
            )
            .ignoresSafeArea()
            .blendMode(.screen)

            VStack(spacing: 0) {
                header

                ScrollView(.vertical, showsIndicators: false) {
                    pageContent
                        .frame(maxWidth: 520)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 18)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)

                footer
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 38, height: 38)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("RAWLIGHT")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.textPrimary)

            Spacer(minLength: 0)

            Button(mode == .firstLaunch ? "Skip" : "Close") {
                onComplete()
            }
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(AppTheme.textSecondary)
            .buttonStyle(.plain)
            .frame(minWidth: 48, minHeight: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    @ViewBuilder
    private var pageContent: some View {
        VStack(spacing: 22) {
            heroIcon

            VStack(spacing: 10) {
                Text(pageTitle)
                    .font(.system(size: 27, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(pageDescription)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            switch page {
            case .camera, .photos, .microphone:
                permissionStatusPanel
            case .controls:
                VStack(spacing: 10) {
                    guideRow(icon: "hand.tap.fill", title: "TAP TO METER", detail: "Tap the preview to place focus and exposure. Tap again to lock the point.")
                    guideRow(icon: "slider.horizontal.3", title: "M IS MANUAL", detail: "Use shutter speed, ISO, white balance and manual focus directly above the preview.")
                    guideRow(icon: "viewfinder", title: "EXPOSURE TOOLS", detail: "Enable zebras, focus peaking and the grid in Settings when you need them.")
                }
            case .formats:
                VStack(spacing: 10) {
                    guideRow(icon: "wand.and.stars", title: "APPLE ProRAW", detail: "Apple's processed RAW workflow with additional computational image data.")
                    guideRow(icon: "circle.grid.cross", title: "PURE RAW · 12 MP", detail: "Bayer RAW data from the sensor without Apple ProRAW processing.")
                    guideRow(icon: "video.fill", title: "APPLE LOG", detail: "Use the Video settings to choose codec, frame rate, monitoring look and audio.")
                }
            case .welcome:
                welcomePanel
            }
        }
    }

    private var heroIcon: some View {
        Image(systemName: pageIcon)
            .font(.system(size: 52, weight: .light))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(width: 116, height: 116)
            .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 22, y: 12)
    }

    private var welcomePanel: some View {
        HStack(spacing: 0) {
            welcomeFeature(icon: "camera.fill", title: "PHOTO", detail: "ProRAW + Pure RAW")
            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 52)
            welcomeFeature(icon: "video.fill", title: "VIDEO", detail: "Apple Log")
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .metalRoundedPanel(cornerRadius: 16)
    }

    private func welcomeFeature(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(AppTheme.textPrimary)
            Text(detail)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var permissionStatusPanel: some View {
        HStack(spacing: 12) {
            Image(systemName: permissionState == .allowed ? "checkmark.circle.fill" : permissionState == .denied ? "exclamationmark.circle.fill" : "circle.dashed")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(permissionState == .allowed ? Color.green.opacity(0.9) : permissionState == .denied ? Color.yellow.opacity(0.9) : AppTheme.accent)

            VStack(alignment: .leading, spacing: 3) {
                Text(permissionStatusTitle)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(permissionStatusDetail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .metalRoundedPanel(cornerRadius: 14)
    }

    private func guideRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 36, height: 36)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .metalRoundedPanel(cornerRadius: 14)
    }

    private var footer: some View {
        VStack(spacing: 13) {
            HStack(spacing: 7) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == pageIndex ? AppTheme.accent : Color.white.opacity(0.18))
                        .frame(width: index == pageIndex ? 22 : 7, height: 7)
                        .animation(.easeOut(duration: 0.2), value: pageIndex)
                }
            }

            Button(action: primaryAction) {
                HStack(spacing: 9) {
                    if isRequestingPermission {
                        ProgressView()
                            .tint(AppTheme.textPrimary)
                    }
                    Text(primaryButtonTitle)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .tracking(0.5)
                    if !isRequestingPermission {
                        Image(systemName: isLastPage ? "checkmark" : "arrow.right")
                            .font(.system(size: 13, weight: .black))
                    }
                }
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.activeGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isRequestingPermission)

            if isPermissionPage, permissionState == .denied {
                Button("Continue without access") {
                    advance()
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(.black.opacity(0.28))
    }

    private var pageTitle: String {
        switch page {
        case .welcome: return "Shoot your way"
        case .camera: return "Camera access"
        case .photos: return "Save your shots"
        case .microphone: return "Record sound"
        case .controls: return "Stay in control"
        case .formats: return "Choose your format"
        }
    }

    private var pageDescription: String {
        switch page {
        case .welcome:
            return "Manual photography, sensor RAW and Apple Log video in one focused camera."
        case .camera:
            return "Rawlight needs camera access to show the live preview and capture photos and video."
        case .photos:
            return "Allow add-only Photos access so Rawlight can save your finished captures to your library."
        case .microphone:
            return "Microphone access adds sound to video. Photos and silent video remain available without it."
        case .controls:
            return "The most important controls stay close to the preview, ready when you need them."
        case .formats:
            return "Select the capture pipeline that fits the shot. You can change it anytime in Settings."
        }
    }

    private var pageIcon: String {
        switch page {
        case .welcome: return "camera.aperture"
        case .camera: return "camera.fill"
        case .photos: return "photo.on.rectangle.angled"
        case .microphone: return "mic.fill"
        case .controls: return "dial.medium.fill"
        case .formats: return "circle.grid.cross"
        }
    }

    private var isPermissionPage: Bool {
        page == .camera || page == .photos || page == .microphone
    }

    private var permissionState: PermissionState {
        switch page {
        case .camera:
            switch cameraManager.cameraAuthorizationStatus {
            case .authorized: return .allowed
            case .notDetermined: return .notDetermined
            default: return .denied
            }
        case .microphone:
            switch cameraManager.microphoneAuthorizationStatus {
            case .authorized: return .allowed
            case .notDetermined: return .notDetermined
            default: return .denied
            }
        case .photos:
            switch cameraManager.photoLibraryAuthorizationStatus {
            case .authorized, .limited: return .allowed
            case .notDetermined: return .notDetermined
            default: return .denied
            }
        default:
            return .allowed
        }
    }

    private var permissionStatusTitle: String {
        switch permissionState {
        case .notDetermined: return "NOT REQUESTED"
        case .allowed: return "ACCESS ALLOWED"
        case .denied: return "ACCESS DISABLED"
        }
    }

    private var permissionStatusDetail: String {
        switch permissionState {
        case .notDetermined: return "Rawlight will show the system permission next."
        case .allowed: return "This permission is ready."
        case .denied: return "You can enable it in the iPhone Settings app."
        }
    }

    private var primaryButtonTitle: String {
        guard isPermissionPage else {
            if page == .welcome { return "GET STARTED" }
            return isLastPage ? (mode == .firstLaunch ? "START SHOOTING" : "DONE") : "CONTINUE"
        }

        switch permissionState {
        case .notDetermined:
            switch page {
            case .camera: return "ALLOW CAMERA"
            case .photos: return "ALLOW PHOTOS"
            case .microphone: return "ALLOW MICROPHONE"
            default: return "CONTINUE"
            }
        case .allowed:
            return "CONTINUE"
        case .denied:
            return "OPEN SETTINGS"
        }
    }

    private var isLastPage: Bool {
        pageIndex == pages.count - 1
    }

    private func primaryAction() {
        guard isPermissionPage else {
            advance()
            return
        }

        switch permissionState {
        case .allowed:
            advance()
        case .denied:
            openSettings()
        case .notDetermined:
            isRequestingPermission = true
            let completion: (Bool) -> Void = { _ in
                isRequestingPermission = false
                advance()
            }

            switch page {
            case .camera:
                cameraManager.requestCameraPermission(completion: completion)
            case .photos:
                cameraManager.requestPhotoLibraryPermission(completion: completion)
            case .microphone:
                cameraManager.requestMicrophonePermission(completion: completion)
            default:
                isRequestingPermission = false
                advance()
            }
        }
    }

    private func advance() {
        guard !isLastPage else {
            onComplete()
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            pageIndex += 1
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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

                Text("Rawlight needs camera access.")
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(cameraManager.cameraAuthorizationStatus == .notDetermined
                     ? "Allow access to use the live preview and capture photos and video."
                     : "Enable camera access in Settings to return to the live preview.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Button(cameraManager.cameraAuthorizationStatus == .notDetermined ? "Allow Camera" : "Open Settings") {
                    if cameraManager.cameraAuthorizationStatus == .notDetermined {
                        cameraManager.requestCameraPermission { _ in }
                    } else {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentStrong)
            }
            .padding(28)
        }
    }
}

private struct CaptureModeTransitionOverlay: View {
    let targetMode: CaptureMode
    let rotationDegrees: Double
    let isActive: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.93)

            RadialGradient(
                colors: [
                    AppTheme.accentStrong.opacity(0.68),
                    AppTheme.accent.opacity(0.12),
                    Color.clear
                ],
                center: .center,
                startRadius: 8,
                endRadius: 270
            )

            Circle()
                .stroke(AppTheme.accent.opacity(0.18), lineWidth: 1)
                .frame(width: 230, height: 230)
                .scaleEffect(isActive ? 1.06 : 0.82)
                .opacity(isActive ? 0.22 : 0)
                .animation(.easeOut(duration: 0.55), value: isActive)

            Circle()
                .stroke(AppTheme.accent.opacity(0.38), lineWidth: 1.5)
                .frame(width: 156, height: 156)
                .scaleEffect(isActive ? 0.94 : 1.08)
                .opacity(isActive ? 1 : 0)
                .animation(.easeOut(duration: 0.42), value: isActive)

            VStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(AppTheme.surfaceGradient)
                        .frame(width: 88, height: 88)
                        .overlay(
                            Circle()
                                .stroke(AppTheme.accent.opacity(0.88), lineWidth: 2)
                        )
                        .shadow(color: AppTheme.accent.opacity(0.32), radius: 16)

                    Image(systemName: targetMode == .photo ? "camera.fill" : "video.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                VStack(spacing: 4) {
                    Text(targetMode.title.uppercased())
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .tracking(2.2)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("PREPARING MODE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.accent)
            }
            .rotationEffect(.degrees(rotationDegrees))
            .scaleEffect(isActive ? 1 : 0.94)
            .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isActive)
        }
        .ignoresSafeArea()
    }
}

private struct SteppedHapticSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var hapticStride: Double? = nil
    let tint: Color

    @State private var lastHapticIndex: Int?
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)

    var body: some View {
        ZStack {
            SliderStepTicks(intervalCount: hapticIntervalCount)
                .padding(.horizontal, 12)

            Slider(
                value: Binding(
                    get: { value },
                    set: handleSliderValueChange
                ),
                in: range,
                step: step,
                onEditingChanged: handleEditingChanged
            )
            .tint(tint)
            .scaleEffect(x: 1, y: 1.08)
        }
        .expandedTapTarget(horizontal: 0, vertical: 10)
    }

    private var hapticIndex: Int {
        let increment = max(hapticStride ?? step, .ulpOfOne)
        return Int(((value - range.lowerBound) / increment).rounded())
    }

    private var hapticIntervalCount: Int {
        let increment = max(hapticStride ?? step, .ulpOfOne)
        return max(Int(((range.upperBound - range.lowerBound) / increment).rounded()), 1)
    }

    private func handleEditingChanged(_ editing: Bool) {
        if editing {
            lastHapticIndex = hapticIndex
            feedbackGenerator.prepare()
        } else {
            lastHapticIndex = nil
        }
    }

    private func handleSliderValueChange(_ newValue: Double) {
        let increment = max(hapticStride ?? step, .ulpOfOne)
        let newIndex = Int(((newValue - range.lowerBound) / increment).rounded())
        let previousIndex = lastHapticIndex ?? hapticIndex

        if previousIndex != newIndex {
            feedbackGenerator.impactOccurred(intensity: 1.0)
            feedbackGenerator.prepare()
        }

        lastHapticIndex = newIndex
        value = newValue
    }
}

private struct SliderStepTicks: View {
    let intervalCount: Int

    var body: some View {
        Canvas { context, size in
            let count = max(intervalCount, 1)

            for index in 0...count {
                let progress = CGFloat(index) / CGFloat(count)
                let x = progress * size.width
                let isEndpoint = index == 0 || index == count
                let isMajor = isEndpoint || index % 5 == 0
                let height: CGFloat = isMajor ? 12 : 6
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: (size.height - height) / 2))
                tick.addLine(to: CGPoint(x: x, y: (size.height + height) / 2))
                context.stroke(
                    tick,
                    with: .color(Color.white.opacity(isMajor ? 0.42 : 0.22)),
                    lineWidth: 1
                )
            }
        }
        .frame(height: 14)
        .allowsHitTesting(false)
    }
}

private struct DiscreteLandscapeSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    private let trackHeight: CGFloat = 5
    private let thumbSize: CGFloat = 26
    @State private var lastHapticIndex: Int?
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, thumbSize)
            let progress = normalizedProgress
            let xPosition = (thumbSize / 2) + progress * max(width - thumbSize, 1)

            ZStack(alignment: .leading) {
                SliderStepTicks(intervalCount: stepIntervalCount)
                    .padding(.horizontal, thumbSize / 2)

                Capsule()
                    .fill(Color.white.opacity(0.32))
                    .frame(height: trackHeight)

                Circle()
                    .fill(Color.white.opacity(1.0))
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.22), lineWidth: 0.8)
                    )
                    .position(x: xPosition, y: proxy.size.height / 2)
            }
            .contentShape(
                .interaction,
                ExpandedHitRectangle(horizontalExpansion: 0, verticalExpansion: 10)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateValue(for: gesture.location.x, width: width)
                    }
                    .onEnded { _ in
                        lastHapticIndex = nil
                    }
            )
        }
        .frame(height: 24)
        .accessibilityElement()
        .accessibilityLabel("Adjustment")
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                setValue(value + step, providesFeedback: true)
            case .decrement:
                setValue(value - step, providesFeedback: true)
            @unknown default:
                break
            }
        }
    }

    private var normalizedProgress: CGFloat {
        let lower = range.lowerBound
        let upper = range.upperBound
        guard upper > lower else { return 0 }
        let clamped = min(max(value, lower), upper)
        return CGFloat((clamped - lower) / (upper - lower))
    }

    private var stepIntervalCount: Int {
        max(Int(((range.upperBound - range.lowerBound) / max(step, .ulpOfOne)).rounded()), 1)
    }

    private func updateValue(for locationX: CGFloat, width: CGFloat) {
        let usableWidth = max(width - thumbSize, 1)
        let clampedX = min(max(locationX, thumbSize / 2), width - thumbSize / 2)
        let progress = (clampedX - thumbSize / 2) / usableWidth
        let rawValue = range.lowerBound + Double(progress) * (range.upperBound - range.lowerBound)
        let steppedValue = range.lowerBound + ((rawValue - range.lowerBound) / step).rounded() * step
        setValue(steppedValue, providesFeedback: true)
    }

    private var accessibilityValue: String {
        step < 1 ? String(format: "%.2f", value) : String(format: "%.0f", value)
    }

    private func setValue(_ newValue: Double, providesFeedback: Bool) {
        let clampedValue = min(max(newValue, range.lowerBound), range.upperBound)
        let newIndex = Int(((clampedValue - range.lowerBound) / max(step, .ulpOfOne)).rounded())

        if lastHapticIndex == nil {
            lastHapticIndex = Int(((value - range.lowerBound) / max(step, .ulpOfOne)).rounded())
            feedbackGenerator.prepare()
        }

        if providesFeedback, lastHapticIndex != newIndex {
            feedbackGenerator.impactOccurred(intensity: 1.0)
            feedbackGenerator.prepare()
        }

        lastHapticIndex = newIndex
        value = clampedValue
    }
}

private struct PhotoShutterCore: View {
    let isClosed: Bool

    private let bladeCount = 6

    var body: some View {
        ZStack {
            ApertureOctagonShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.19, green: 0.20, blue: 0.23),
                            Color(red: 0.08, green: 0.09, blue: 0.11)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    ApertureOctagonShape()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            ForEach(0..<bladeCount, id: \.self) { index in
                ApertureBladeShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color(red: 0.74, green: 0.76, blue: 0.81).opacity(0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        ApertureBladeShape()
                            .stroke(Color.black.opacity(0.18), lineWidth: 0.8)
                    )
                    .frame(
                        width: isClosed ? 26 : 23,
                        height: isClosed ? 27 : 31
                    )
                    .offset(y: isClosed ? -1.5 : -6.5)
                    .rotationEffect(
                        .degrees(Double(index) * (360.0 / Double(bladeCount)) + (isClosed ? 28 : 10))
                    )
            }

            ApertureOctagonShape()
                .fill(Color.black.opacity(0.76))
                .frame(
                    width: isClosed ? 26 : 14,
                    height: isClosed ? 26 : 14
                )
                .overlay(
                    ApertureOctagonShape()
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                )
                .rotationEffect(.degrees(isClosed ? 22 : 0))
        }
        .overlay(
            ApertureOctagonShape()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(isClosed ? 0.94 : 1)
        .animation(.easeInOut(duration: 0.065), value: isClosed)
    }
}

private struct ApertureBladeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.minY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.24, y: rect.maxY - rect.height * 0.10))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.maxY - rect.height * 0.28))
        path.closeSubpath()
        return path
    }
}

private struct ApertureOctagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let insetX = rect.width * 0.22
        let insetY = rect.height * 0.22

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + insetX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - insetX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + insetY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - insetY))
        path.addLine(to: CGPoint(x: rect.maxX - insetX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + insetX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - insetY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + insetY))
        path.closeSubpath()
        return path
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
