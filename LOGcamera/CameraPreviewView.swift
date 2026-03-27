import SwiftUI
import AVFoundation
import Combine
import MetalKit

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = cameraManager.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.bindPreviewFrames(to: cameraManager)
        view.setPreviewLookMode(cameraManager.previewLookMode)
        view.onFocusSelection = { [weak cameraManager] capturePoint, previewPoint, shouldLock in
            guard let cameraManager else { return }
            cameraManager.showFocusFeedback(at: previewPoint, isLocked: shouldLock)
            if shouldLock {
                cameraManager.focusAndLock(at: capturePoint)
            } else {
                cameraManager.focus(at: capturePoint)
            }
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = cameraManager.session
        uiView.bindPreviewFrames(to: cameraManager)
        uiView.setPreviewLookMode(cameraManager.previewLookMode)
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

    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?
    private var activeDevice: AVCaptureDevice?
    private weak var boundCameraManager: CameraManager?
    private var previewFrameCancellable: AnyCancellable?
    private let processedPreviewView = MTKView(frame: .zero)
    private var previewRenderer: MetalPreviewRenderer?
    private var isProcessedPreviewEnabled = false
    private var currentPreviewRotationAngle: CGFloat = 0

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

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupProcessedPreviewView()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupProcessedPreviewView()
        setupGestures()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateProcessedPreviewLayout()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            setupRotationIfPossible()
        } else {
            teardownRotation()
        }
    }

    func updateActiveDevice(_ device: AVCaptureDevice?) {
        guard activeDevice?.uniqueID != device?.uniqueID else { return }
        activeDevice = device
        setupRotationIfPossible()
        updateProcessedPreviewLayout()
    }

    func bindPreviewFrames(to cameraManager: CameraManager) {
        guard boundCameraManager !== cameraManager else { return }

        boundCameraManager = cameraManager
        previewFrameCancellable = cameraManager.previewFramePublisher.sink { [weak self] frame in
            self?.previewRenderer?.enqueue(frame)
        }
    }

    func setPreviewLookMode(_ mode: PreviewLookMode) {
        isProcessedPreviewEnabled = mode == .rec709
        if !isProcessedPreviewEnabled {
            previewRenderer?.clear()
        }
        processedPreviewView.isHidden = !isProcessedPreviewEnabled
    }

    private func setupGestures() {
        isUserInteractionEnabled = true
        tapGestureRecognizer.require(toFail: longPressGestureRecognizer)
        addGestureRecognizer(tapGestureRecognizer)
        addGestureRecognizer(longPressGestureRecognizer)
    }

    private func setupProcessedPreviewView() {
        processedPreviewView.clipsToBounds = true
        processedPreviewView.isUserInteractionEnabled = false
        processedPreviewView.backgroundColor = .clear
        processedPreviewView.isHidden = true
        previewRenderer = MetalPreviewRenderer(view: processedPreviewView)
        addSubview(processedPreviewView)
    }

    private func setupRotationIfPossible() {
        guard let activeDevice else { return }
        guard videoPreviewLayer.connection != nil else { return }

        if let coordinator = rotationCoordinator,
           coordinator.device?.uniqueID == activeDevice.uniqueID {
            return
        }

        teardownRotation()

        let coordinator = AVCaptureDevice.RotationCoordinator(device: activeDevice, previewLayer: videoPreviewLayer)
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
        guard let connection = videoPreviewLayer.connection,
              connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
        currentPreviewRotationAngle = angle
        updateProcessedPreviewLayout()
    }

    private func teardownRotation() {
        previewRotationObservation?.invalidate()
        previewRotationObservation = nil
        rotationCoordinator = nil
    }

    private func capturePoint(from gesture: UIGestureRecognizer) -> CGPoint {
        let location = gesture.location(in: self)
        return videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: location)
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

    private func updateProcessedPreviewLayout() {
        let normalizedAngle = abs(Int(currentPreviewRotationAngle.rounded())) % 360
        let swapsAxes = normalizedAngle == 90 || normalizedAngle == 270
        let baseSize = bounds.size
        let rotatedSize = swapsAxes
            ? CGSize(width: baseSize.height, height: baseSize.width)
            : baseSize

        processedPreviewView.bounds = CGRect(origin: .zero, size: rotatedSize)
        processedPreviewView.center = CGPoint(x: bounds.midX, y: bounds.midY)

        var transform = CGAffineTransform(rotationAngle: currentPreviewRotationAngle * (.pi / 180))
        if activeDevice?.position == .front {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        processedPreviewView.transform = transform
    }
}
