import SwiftUI
import AVFoundation
import Combine
import MetalKit

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.configureSession(cameraManager.session)
        view.bindPreviewFrames(to: cameraManager)
        view.setPreviewLookMode(cameraManager.previewLookMode)
        view.applyConnectionConfiguration(from: cameraManager)
        view.onFocusSelection = { [weak cameraManager] capturePoint, previewPoint, shouldLock in
            guard let cameraManager else { return }
            cameraManager.showFocusFeedback(at: previewPoint, isLocked: shouldLock)
            if shouldLock {
                cameraManager.focusAndLock(at: capturePoint)
            } else {
                cameraManager.focus(at: capturePoint)
            }
        }
        if let device = cameraManager.activeDevice {
            view.updateActiveDevice(device)
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.configureSession(cameraManager.session)
        uiView.bindPreviewFrames(to: cameraManager)
        uiView.setPreviewLookMode(cameraManager.previewLookMode)
        uiView.applyConnectionConfiguration(from: cameraManager)
        uiView.onFocusSelection = { [weak cameraManager] capturePoint, previewPoint, shouldLock in
            guard let cameraManager else { return }
            cameraManager.showFocusFeedback(at: previewPoint, isLocked: shouldLock)
            if shouldLock {
                cameraManager.focusAndLock(at: capturePoint)
            } else {
                cameraManager.focus(at: capturePoint)
            }
        }

        if let device = cameraManager.activeDevice {
            uiView.updateActiveDevice(device)
        }
    }
}

final class PreviewView: UIView {
    var onFocusSelection: ((CGPoint, CGPoint, Bool) -> Void)?

    private let previewSurface = MTKView(frame: .zero)
    private let conversionPreviewLayer = AVCaptureVideoPreviewLayer()
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?
    private var activeDevice: AVCaptureDevice?
    private weak var boundCameraManager: CameraManager?
    private var previewFrameCancellable: AnyCancellable?
    private var previewRenderer: MetalPreviewRenderer?
    private var currentPreviewRotationAngle: CGFloat = 0
    private var currentPreviewLookMode: PreviewLookMode = .log

    private lazy var tapGestureRecognizer = UITapGestureRecognizer(
        target: self,
        action: #selector(handleTapToFocus(_:))
    )

    private lazy var longPressGestureRecognizer: UILongPressGestureRecognizer = {
        let recognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPressToLock(_:))
        )
        recognizer.minimumPressDuration = 0.45
        return recognizer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPreviewSurface()
        setupConversionLayer()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPreviewSurface()
        setupConversionLayer()
        setupGestures()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        conversionPreviewLayer.frame = bounds
        updatePreviewSurfaceLayout()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            setupRotationIfPossible()
        } else {
            teardownRotation()
        }
    }

    func configureSession(_ session: AVCaptureSession) {
        if conversionPreviewLayer.session !== session {
            conversionPreviewLayer.session = session
            previewRenderer?.clear()
            if let boundCameraManager {
                applyConnectionConfiguration(from: boundCameraManager)
            }
            setupRotationIfPossible()
        }
    }

    func updateActiveDevice(_ device: AVCaptureDevice?) {
        guard activeDevice?.uniqueID != device?.uniqueID else { return }
        activeDevice = device
        previewRenderer?.clear()
        setupRotationIfPossible()
        updatePreviewSurfaceLayout()
    }

    func bindPreviewFrames(to cameraManager: CameraManager) {
        guard boundCameraManager !== cameraManager else { return }

        boundCameraManager = cameraManager
        previewFrameCancellable = cameraManager.previewFramePublisher.sink { [weak self] frame in
            guard let self else { return }
            self.previewRenderer?.enqueue(frame)
        }
        applyConnectionConfiguration(from: cameraManager)
    }

    func setPreviewLookMode(_ mode: PreviewLookMode) {
        currentPreviewLookMode = mode
        previewRenderer?.setPreviewLookMode(mode)
        updateVisiblePreviewMode()
    }

    private func setupPreviewSurface() {
        previewSurface.clipsToBounds = true
        previewSurface.isUserInteractionEnabled = false
        previewSurface.backgroundColor = .black
        previewSurface.frame = bounds
        previewRenderer = MetalPreviewRenderer(view: previewSurface)
        addSubview(previewSurface)
        bringSubviewToFront(previewSurface)
        updateVisiblePreviewMode()
    }

    private func setupConversionLayer() {
        conversionPreviewLayer.videoGravity = .resizeAspectFill
        conversionPreviewLayer.isHidden = true
        layer.insertSublayer(conversionPreviewLayer, at: 0)
    }

    private func setupGestures() {
        isUserInteractionEnabled = true
        tapGestureRecognizer.require(toFail: longPressGestureRecognizer)
        addGestureRecognizer(tapGestureRecognizer)
        addGestureRecognizer(longPressGestureRecognizer)
    }

    private func setupRotationIfPossible() {
        guard let activeDevice else { return }
        guard conversionPreviewLayer.connection != nil else { return }

        if let coordinator = rotationCoordinator,
           coordinator.device?.uniqueID == activeDevice.uniqueID {
            return
        }

        teardownRotation()

        let coordinator = AVCaptureDevice.RotationCoordinator(device: activeDevice, previewLayer: conversionPreviewLayer)
        rotationCoordinator = coordinator
        applyPreviewRotation(coordinator.videoRotationAngleForHorizonLevelPreview)

        previewRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview,
            options: [.new]
        ) { [weak self] coordinator, _ in
            DispatchQueue.main.async {
                self?.applyPreviewRotation(coordinator.videoRotationAngleForHorizonLevelPreview)
            }
        }
    }

    private func applyPreviewRotation(_ angle: CGFloat) {
        guard let connection = conversionPreviewLayer.connection,
              connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
        if let boundCameraManager {
            boundCameraManager.applyPreviewConnectionConfiguration(connection)
        }
        currentPreviewRotationAngle = angle
        updatePreviewSurfaceLayout()
    }

    private func teardownRotation() {
        previewRotationObservation?.invalidate()
        previewRotationObservation = nil
        rotationCoordinator = nil
    }

    private func capturePoint(from gesture: UIGestureRecognizer) -> CGPoint {
        let location = gesture.location(in: self)
        return conversionPreviewLayer.captureDevicePointConverted(fromLayerPoint: location)
    }

    private func previewPoint(from gesture: UIGestureRecognizer) -> CGPoint {
        guard bounds.width > 0, bounds.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }

        let location = gesture.location(in: self)
        return CGPoint(
            x: min(max(location.x / bounds.width, 0), 1),
            y: min(max(location.y / bounds.height, 0), 1)
        )
    }

    @objc private func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        onFocusSelection?(capturePoint(from: gesture), previewPoint(from: gesture), false)
    }

    @objc private func handleLongPressToLock(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        onFocusSelection?(capturePoint(from: gesture), previewPoint(from: gesture), true)
    }

    private func updatePreviewSurfaceLayout() {
        let normalizedAngle = abs(Int(currentPreviewRotationAngle.rounded())) % 360
        let swapsAxes = normalizedAngle == 90 || normalizedAngle == 270
        let baseSize = bounds.size
        let rotatedSize = swapsAxes
            ? CGSize(width: baseSize.height, height: baseSize.width)
            : baseSize

        previewSurface.bounds = CGRect(origin: .zero, size: rotatedSize)
        previewSurface.center = CGPoint(x: bounds.midX, y: bounds.midY)

        var transform = CGAffineTransform(rotationAngle: currentPreviewRotationAngle * (.pi / 180))
        if activeDevice?.position == .front {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        previewSurface.transform = transform
    }

    private func updateVisiblePreviewMode() {
        let showMetalPreview = previewRenderer != nil
        previewSurface.isHidden = !showMetalPreview
        previewSurface.alpha = 1
        conversionPreviewLayer.isHidden = showMetalPreview
        if showMetalPreview {
            bringSubviewToFront(previewSurface)
        }
    }

    func applyConnectionConfiguration(from cameraManager: CameraManager) {
        if let connection = conversionPreviewLayer.connection {
            cameraManager.applyPreviewConnectionConfiguration(connection)
        }
    }
}
