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
                    step: 0.01
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
                in: Double(cameraManager.videoExposureBiasRange.lowerBound)...Double(cameraManager.videoExposureBiasRange.upperBound)
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
                step: 0.01
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

                Button {
                    cameraManager.setWhiteBalanceAuto()
                } label: {
                    Text("Auto")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(cameraManager.usesManualWhiteBalance ? AppTheme.textPrimary : Color.black)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 40, minHeight: 24)
                        .metalCapsulePanel(isActive: !cameraManager.usesManualWhiteBalance)
                }
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
                step: 10
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
                    .foregroundStyle(cameraManager.usesManualWhiteBalance ? AppTheme.textPrimary : Color.black)
                    .padding(.horizontal, 10)
                    .frame(minWidth: 56, minHeight: 24)
                    .lineLimit(1)
                    .metalCapsulePanel(isActive: !cameraManager.usesManualWhiteBalance)
                    .rotationEffect(.degrees(previewControlRotationDegrees))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.plain)
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
                    .foregroundStyle(isFocusAdjusted ? Color.black : AppTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .metalCapsulePanel(isActive: isFocusAdjusted)
                    .rotationEffect(.degrees(previewControlRotationDegrees))
            }
            .buttonStyle(.plain)
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
                                .stroke(Color.white.opacity(0.88), lineWidth: 2.4)
                        )
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

                    PhotoShutterCore(isClosed: cameraManager.isPhotoCaptureInProgress)
                        .frame(width: 48, height: 48)
                        .scaleEffect(cameraManager.isPhotoCaptureInProgress ? 0.94 : 1)
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

    private var captureModeSwitchButton: some View {
        Button {
            cameraManager.switchCaptureMode()
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
                .foregroundStyle(cameraManager.usesManualWhiteBalance ? AppTheme.textPrimary : Color.black)
                .padding(.horizontal, 5)
                .frame(minWidth: 24, minHeight: 16)
                .metalCapsulePanel(isActive: !cameraManager.usesManualWhiteBalance)
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    private var photoFocusResetButton: some View {
        Button {
            cameraManager.setManualFocusEnabled(false)
        } label: {
            Text("AF")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(cameraManager.manualFocusEnabled ? AppTheme.textPrimary : Color.black)
                .padding(.horizontal, 5)
                .frame(minWidth: 20, minHeight: 16)
                .metalCapsulePanel(isActive: !cameraManager.manualFocusEnabled)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
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
                showsPhotoExposureBiasPanel = true
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
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(isExposureAdjusted ? Color.black : AppTheme.textSecondary)
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 16)
                .metalCapsulePanel(isActive: isExposureAdjusted)
        }
        .buttonStyle(.plain)
        .disabled(!isExposureAdjusted)
    }

    private var photoMeteringResetButton: some View {
        Button {
            cameraManager.clearPhotoMeteringSelection()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.black, lineWidth: 1.7)
                    .frame(width: 14, height: 14)

                Capsule()
                    .fill(Color.black)
                    .frame(width: 16, height: 1.9)
                    .rotationEffect(.degrees(-45))
            }
            .frame(width: 30, height: 30)
            .metalCirclePanel(isActive: true)
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
    @State private var isPhotoExpanded = true
    @State private var isVideoExpanded = true

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
    }

    private var settingsBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.055),
                Color.black,
                Color(red: 0.08, green: 0.08, blue: 0.09)
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
                .fill(Color.white.opacity(0.08))
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
        }
    }

    private var photoSection: some View {
        collapsiblePanel(
            title: "Photo",
            subtitle: cameraManager.appleProRAWEnabled ? "ProRAW ready" : "ProRAW unavailable",
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
                    }
                }
            }

            settingsRow(title: "Companion", detail: cameraManager.appleProRAWEnabled ? "DNG base" : "RAW off") {
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
                optionStrip {
                    ForEach(PhotoResolutionOption.allCases) { option in
                        selectionButton(
                            title: option.title,
                            isSelected: cameraManager.photoResolutionOption == option
                        ) {
                            cameraManager.selectPhotoResolutionOption(option)
                        }
                    }
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
            subtitle: "\(cameraManager.selectedFrameRate) fps - \(cameraManager.selectedVideoCodec.title)",
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
                .foregroundStyle(Color.black)
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
            Slider(value: value, in: range, step: 1)
                .tint(tint)
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
                .foregroundStyle(isSelected ? Color.black : AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .frame(maxWidth: .infinity)
                .metalRoundedPanel(cornerRadius: 9, isActive: isSelected)
        }
        .buttonStyle(.plain)
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

    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 22

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, thumbSize)
            let progress = normalizedProgress
            let xPosition = (thumbSize / 2) + progress * max(width - thumbSize, 1)

            ZStack(alignment: .leading) {
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
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateValue(for: gesture.location.x, width: width)
                    }
            )
        }
        .frame(height: 24)
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
        .animation(.easeInOut(duration: 0.16), value: isClosed)
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
