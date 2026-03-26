import SwiftUI
import AVFoundation
import PhotosUI
import UIKit

private enum AppTheme {
    static let accent = Color(red: 0.58, green: 0.36, blue: 0.98)
    static let accentStrong = Color(red: 0.49, green: 0.28, blue: 0.95)
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
    @State private var showsGalleryPicker = false
    @State private var selectedGalleryItem: PhotosPickerItem?
    @State private var showsExposurePanel = false
    @State private var showsWhiteBalancePanel = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                previewSurface
                Spacer(minLength: 0)
            }
            .ignoresSafeArea(edges: .horizontal)

            if showsControlMenu {
                VStack {
                    Spacer()
                    controlsMenu
                        .padding(.horizontal, 16)
                        .padding(.bottom, 118)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .photosPicker(
            isPresented: $showsGalleryPicker,
            selection: $selectedGalleryItem,
            matching: .videos,
            preferredItemEncoding: .automatic
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: showsControlMenu)
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                showsGalleryPicker = true
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.black.opacity(0.48), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
    }

    private var previewSurface: some View {
        CameraPreviewView(cameraManager: cameraManager)
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .overlay {
                FocusFeedbackOverlay(feedback: cameraManager.focusFeedback)
            }
            .overlay(alignment: .topTrailing) {
                topBar
                    .padding(.top, 14)
                    .padding(.trailing, 14)
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
                    .padding(.bottom, 16)
            }
    }

    private var bottomOverlay: some View {
        VStack(spacing: 14) {
            if let statusMessage = cameraManager.statusMessage {
                Text(statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
            }

            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom) {
                    lensPickerButton
                    Spacer()
                    quickAdjustments
                }

                recordButton
            }
        }
    }

    private var quickAdjustments: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if showsExposurePanel {
                exposureQuickPanel
            }

            if showsWhiteBalancePanel {
                whiteBalanceQuickPanel
            }

            HStack(spacing: 10) {
                quickAdjustButton(title: "EXP", isActive: showsExposurePanel) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showsExposurePanel.toggle()
                        if showsExposurePanel {
                            showsWhiteBalancePanel = false
                        }
                    }
                }

                quickAdjustButton(title: "WB", isActive: showsWhiteBalancePanel) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showsWhiteBalancePanel.toggle()
                        if showsWhiteBalancePanel {
                            showsExposurePanel = false
                        }
                    }
                }

                controlsButton
            }
        }
        .padding(.bottom, 54)
    }

    private var exposureQuickPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Exposure")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(String(format: "%+.1f EV", cameraManager.exposureBias))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
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
        .frame(width: 188)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
                    .foregroundStyle(.white.opacity(0.72))
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
                    .foregroundStyle(.white.opacity(0.52))
                Spacer()
                Button("Auto") {
                    cameraManager.setWhiteBalanceAuto()
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .buttonStyle(.plain)
                Spacer()
                Text("9000K")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
            }
        }
        .padding(12)
        .frame(width: 188)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var lensPickerButton: some View {
        Menu {
            ForEach(cameraManager.availableLenses) { lens in
                Button("\(lens.shortName)  \(lens.displayName)") {
                    cameraManager.switchLens(to: lens.id)
                }
            }
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(activeLensShortName)
                        .font(.system(size: 18, weight: .semibold))
                    Text(cameraManager.activeLensSummary)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.black.opacity(0.48), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(cameraManager.isRecording)
    }

    private var controlsMenu: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Camera Controls")
                    .font(.system(size: 16, weight: .bold))

                Spacer()

                Button {
                    showsControlMenu = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }

            fpsRow
            stabilizationRow
            lockRow
            controlPanel
        }
        .padding(14)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 24))
    }

    private var fpsRow: some View {
        HStack(spacing: 8) {
            ForEach(CameraManager.supportedFrameRates, id: \.self) { fps in
                Button {
                    cameraManager.selectFrameRate(fps)
                } label: {
                    Text("\(fps)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(cameraManager.selectedFrameRate == fps ? Color.black : Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cameraManager.selectedFrameRate == fps ? AppTheme.accent : Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .disabled(cameraManager.isRecording)
            }
        }
    }

    private var stabilizationRow: some View {
        HStack(spacing: 8) {
            ForEach(CaptureStabilizationMode.allCases) { mode in
                Button {
                    cameraManager.selectStabilizationMode(mode)
                } label: {
                    Text(mode.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(cameraManager.selectedStabilizationMode == mode ? Color.black : Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cameraManager.selectedStabilizationMode == mode ? AppTheme.accent : Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var lockRow: some View {
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

            if cameraManager.supportsManualFocus {
                lockChip(
                    title: "Manual Focus",
                    isOn: cameraManager.manualFocusEnabled
                ) {
                    cameraManager.setManualFocusEnabled(!cameraManager.manualFocusEnabled)
                }
            }
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Bitrate")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(cameraManager.recordingBitrateLabel)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                }

                HStack(spacing: 8) {
                    ForEach(CameraManager.supportedBitratesMbps, id: \.self) { bitrate in
                        Button {
                            cameraManager.setRecordingBitrateMbps(bitrate)
                        } label: {
                            Text(String(format: "%.0f", bitrate))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(cameraManager.recordingBitrateMbps == bitrate ? Color.black : Color.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(cameraManager.recordingBitrateMbps == bitrate ? AppTheme.accent : Color.white.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Text(cameraManager.usesCustomBitrate ? "Custom bitrate" : "Auto bitrate")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))

                    Spacer()

                    Button(cameraManager.usesCustomBitrate ? "Auto" : "Default") {
                        cameraManager.resetRecordingBitrateToDefault()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .buttonStyle(.plain)
                }
            }

            if cameraManager.supportsManualFocus {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Focus")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text(cameraManager.manualFocusEnabled ? String(format: "%.2f", cameraManager.manualFocusPosition) : "AF")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    Slider(
                        value: Binding(
                            get: { Double(cameraManager.manualFocusPosition) },
                            set: { cameraManager.setManualFocusPosition(Float($0)) }
                        ),
                        in: 0...1
                    )
                    .tint(AppTheme.accent)
                    .disabled(!cameraManager.manualFocusEnabled)
                }
            }

            Text(cameraManager.manualFocusEnabled ? "Manual focus stays locked while recording." : "Tap to focus and expose. Long-press to lock focus and exposure.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 4)
                    .frame(width: 82, height: 82)

                if cameraManager.isRecording {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.accentStrong)
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .fill(cameraManager.canRecord ? AppTheme.accent : Color.gray)
                        .frame(width: 58, height: 58)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!cameraManager.canRecord && !cameraManager.isRecording)
    }

    private var controlsButton: some View {
        Button {
            showsControlMenu.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.black.opacity(0.48), in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var activeLensShortName: String {
        cameraManager.availableLenses.first(where: { $0.id == cameraManager.activeLensID })?.shortName ?? "1x"
    }

    private func lockChip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn ? Color.black : Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isOn ? AppTheme.accent : Color.white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    private func quickAdjustButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isActive ? Color.black : Color.white)
                .frame(width: 48, height: 48)
                .background(isActive ? AppTheme.accent : Color.black.opacity(0.48), in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isActive ? 0 : 0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PermissionView: View {
    @ObservedObject var cameraManager: CameraManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.12, green: 0.12, blue: 0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(AppTheme.accent)

                Text("LOGcamera needs camera and microphone access.")
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("Enable permissions in Settings to capture 4K HEVC video in Apple Log.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
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
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.72), in: Capsule())
                    }

                    ZStack {
                        Circle()
                            .stroke(feedback.isLocked ? AppTheme.accent : Color.white, lineWidth: 2)
                            .frame(width: 84, height: 84)

                        Circle()
                            .fill((feedback.isLocked ? AppTheme.accent : Color.white).opacity(0.22))
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
