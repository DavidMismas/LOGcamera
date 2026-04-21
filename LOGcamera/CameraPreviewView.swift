import SwiftUI
import AVFoundation
import Combine
import MetalKit

enum PhotoMeteringHandleKind {
    case focus
    case exposure
    case both
}

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    let isSuspended: Bool

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.configureSession(cameraManager.session)
        view.bindPreviewFrames(to: cameraManager)
        view.setPreviewLookMode(cameraManager.previewLookMode)
        view.setZebraEnabled(cameraManager.zebraEnabled)
        view.setZebraThreshold(cameraManager.zebraThreshold)
        view.setZebraChannel(cameraManager.zebraChannel)
        view.setFocusPeakingEnabled(cameraManager.effectiveFocusPeakingEnabled)
        view.setFocusPeakingSensitivity(cameraManager.focusPeakingSensitivityPercent)
        view.setCaptureMode(cameraManager.captureMode)
        view.setPhotoMeteringPointsLinked(cameraManager.effectivePhotoMeteringPointsLinked)
        view.setPhotoMeteringHandlesVisible(cameraManager.photoMeteringHandlesVisible)
        view.setPreviewSuspended(isSuspended)
        view.applyConnectionConfiguration(from: cameraManager)
        view.onPhotoMeteringSelection = { [weak cameraManager] kind, capturePoint in
            guard let cameraManager else { return }
            switch kind {
            case .focus:
                cameraManager.setPhotoFocusPoint(at: capturePoint)
            case .exposure:
                cameraManager.setPhotoExposurePoint(at: capturePoint)
            case .both:
                cameraManager.setPhotoFocusAndExposurePoint(at: capturePoint)
            }
        }
        view.onFocusSelection = { [weak cameraManager] capturePoint, previewPoint, shouldLock in
            guard let cameraManager else { return }
            cameraManager.showFocusFeedback(at: previewPoint, isLocked: shouldLock)
            if shouldLock {
                cameraManager.focusAndLock(at: capturePoint)
            } else {
                cameraManager.focus(at: capturePoint)
            }
        }
        view.onPhotoMeteringHandlesVisibilityChanged = { [weak cameraManager] isVisible in
            cameraManager?.setPhotoMeteringHandlesVisible(isVisible)
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
        uiView.setZebraEnabled(cameraManager.zebraEnabled)
        uiView.setZebraThreshold(cameraManager.zebraThreshold)
        uiView.setZebraChannel(cameraManager.zebraChannel)
        uiView.setFocusPeakingEnabled(cameraManager.effectiveFocusPeakingEnabled)
        uiView.setFocusPeakingSensitivity(cameraManager.focusPeakingSensitivityPercent)
        uiView.setCaptureMode(cameraManager.captureMode)
        uiView.setPhotoMeteringPointsLinked(cameraManager.effectivePhotoMeteringPointsLinked)
        uiView.setPhotoMeteringHandlesVisible(cameraManager.photoMeteringHandlesVisible)
        uiView.setPreviewSuspended(isSuspended)
        uiView.applyConnectionConfiguration(from: cameraManager)
        uiView.onPhotoMeteringSelection = { [weak cameraManager] kind, capturePoint in
            guard let cameraManager else { return }
            switch kind {
            case .focus:
                cameraManager.setPhotoFocusPoint(at: capturePoint)
            case .exposure:
                cameraManager.setPhotoExposurePoint(at: capturePoint)
            case .both:
                cameraManager.setPhotoFocusAndExposurePoint(at: capturePoint)
            }
        }
        uiView.onFocusSelection = { [weak cameraManager] capturePoint, previewPoint, shouldLock in
            guard let cameraManager else { return }
            cameraManager.showFocusFeedback(at: previewPoint, isLocked: shouldLock)
            if shouldLock {
                cameraManager.focusAndLock(at: capturePoint)
            } else {
                cameraManager.focus(at: capturePoint)
            }
        }
        uiView.onPhotoMeteringHandlesVisibilityChanged = { [weak cameraManager] isVisible in
            cameraManager?.setPhotoMeteringHandlesVisible(isVisible)
        }

        if let device = cameraManager.activeDevice {
            uiView.updateActiveDevice(device)
        }
    }
}

private final class PhotoMeteringHandleView: UIView {
    enum Style {
        case focus
        case exposure

        var size: CGSize {
            switch self {
            case .focus:
                return CGSize(width: 76, height: 76)
            case .exposure:
                return CGSize(width: 52, height: 52)
            }
        }
    }

    private let style: Style
    private let outerRingLayer = CAShapeLayer()
    private let innerRingLayer = CAShapeLayer()
    private let detailLayer = CAShapeLayer()
    private let centerDotLayer = CAShapeLayer()
    private let badgeLabel = UILabel()

    init(style: Style) {
        self.style = style
        super.init(frame: CGRect(origin: .zero, size: style.size))
        backgroundColor = .clear
        isOpaque = false
        isHidden = true

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.32
        layer.shadowOffset = .zero
        switch style {
        case .focus:
            layer.shadowRadius = 10
        case .exposure:
            layer.shadowRadius = 8
        }

        [outerRingLayer, innerRingLayer, detailLayer, centerDotLayer].forEach {
            layer.addSublayer($0)
        }

        outerRingLayer.lineWidth = 2
        innerRingLayer.lineWidth = 1.5
        detailLayer.lineWidth = 2
        detailLayer.lineCap = .round
        centerDotLayer.strokeColor = nil

        badgeLabel.font = .monospacedSystemFont(ofSize: 10, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.68)
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.layer.masksToBounds = true
        badgeLabel.layer.borderWidth = 1
        badgeLabel.layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor
        addSubview(badgeLabel)

        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let contentsScale = window?.windowScene?.screen.scale ?? traitCollection.displayScale
        [outerRingLayer, innerRingLayer, detailLayer, centerDotLayer].forEach {
            $0.contentsScale = contentsScale
        }
        layer.shadowPath = UIBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2)).cgPath
        updatePaths()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let distance = hypot(point.x - center.x, point.y - center.y)

        switch style {
        case .focus:
            return distance >= focusRadius - 28 && distance <= focusRadius + 28
        case .exposure:
            return distance <= exposureRadius + 22
        }
    }

    private var focusRadius: CGFloat {
        min(bounds.width, bounds.height) * 0.5 - 10
    }

    private var exposureRadius: CGFloat {
        min(bounds.width, bounds.height) * 0.5 - 6
    }

    private func updateAppearance() {
        switch style {
        case .focus:
            let accent = UIColor.systemYellow.withAlphaComponent(0.95)
            outerRingLayer.strokeColor = accent.cgColor
            outerRingLayer.fillColor = UIColor.black.withAlphaComponent(0.14).cgColor
            innerRingLayer.isHidden = true
            detailLayer.strokeColor = accent.cgColor
            centerDotLayer.fillColor = accent.cgColor
            badgeLabel.text = "AF"
            badgeLabel.textColor = accent
        case .exposure:
            let accent = UIColor.white.withAlphaComponent(0.96)
            outerRingLayer.strokeColor = accent.cgColor
            outerRingLayer.fillColor = UIColor.black.withAlphaComponent(0.22).cgColor
            innerRingLayer.strokeColor = UIColor.white.withAlphaComponent(0.34).cgColor
            innerRingLayer.fillColor = UIColor.clear.cgColor
            innerRingLayer.isHidden = false
            detailLayer.strokeColor = accent.cgColor
            centerDotLayer.fillColor = accent.cgColor
            badgeLabel.text = "EV"
            badgeLabel.textColor = accent
        }
    }

    private func updatePaths() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        switch style {
        case .focus:
            let radius = focusRadius
            outerRingLayer.path = UIBezierPath(
                ovalIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            ).cgPath

            let tickPath = UIBezierPath()
            let tickLength: CGFloat = 8
            let tickInset: CGFloat = 6

            tickPath.move(to: CGPoint(x: center.x, y: center.y - radius + tickInset))
            tickPath.addLine(to: CGPoint(x: center.x, y: center.y - radius + tickInset + tickLength))

            tickPath.move(to: CGPoint(x: center.x + radius - tickInset, y: center.y))
            tickPath.addLine(to: CGPoint(x: center.x + radius - tickInset - tickLength, y: center.y))

            tickPath.move(to: CGPoint(x: center.x, y: center.y + radius - tickInset))
            tickPath.addLine(to: CGPoint(x: center.x, y: center.y + radius - tickInset - tickLength))

            tickPath.move(to: CGPoint(x: center.x - radius + tickInset, y: center.y))
            tickPath.addLine(to: CGPoint(x: center.x - radius + tickInset + tickLength, y: center.y))

            detailLayer.path = tickPath.cgPath
            innerRingLayer.path = nil
            centerDotLayer.path = UIBezierPath(
                ovalIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)
            ).cgPath
            badgeLabel.frame = CGRect(x: center.x - 15, y: bounds.minY + 2, width: 30, height: 16)

        case .exposure:
            let outerRadius = exposureRadius
            let innerRadius = max(outerRadius - 10, 8)

            outerRingLayer.path = UIBezierPath(
                ovalIn: CGRect(
                    x: center.x - outerRadius,
                    y: center.y - outerRadius,
                    width: outerRadius * 2,
                    height: outerRadius * 2
                )
            ).cgPath
            innerRingLayer.path = UIBezierPath(
                ovalIn: CGRect(
                    x: center.x - innerRadius,
                    y: center.y - innerRadius,
                    width: innerRadius * 2,
                    height: innerRadius * 2
                )
            ).cgPath

            let detailPath = UIBezierPath()
            detailPath.move(to: CGPoint(x: center.x - 7, y: center.y))
            detailPath.addLine(to: CGPoint(x: center.x + 7, y: center.y))
            detailPath.move(to: CGPoint(x: center.x, y: center.y - 7))
            detailPath.addLine(to: CGPoint(x: center.x, y: center.y + 7))

            detailLayer.path = detailPath.cgPath
            centerDotLayer.path = UIBezierPath(
                ovalIn: CGRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5)
            ).cgPath
            badgeLabel.frame = CGRect(x: center.x - 15, y: bounds.maxY - 18, width: 30, height: 16)
        }
    }
}

final class PreviewView: UIView {
    var onFocusSelection: ((CGPoint, CGPoint, Bool) -> Void)?
    var onPhotoMeteringSelection: ((PhotoMeteringHandleKind, CGPoint) -> Void)?
    var onPhotoMeteringHandlesVisibilityChanged: ((Bool) -> Void)?

    private let previewSurface = MTKView(frame: .zero)
    private let zebraSurface = MTKView(frame: .zero)
    private let focusPeakingSurface = MTKView(frame: .zero)
    private let conversionPreviewLayer = AVCaptureVideoPreviewLayer()
    private let photoFocusHandleView = PhotoMeteringHandleView(style: .focus)
    private let photoExposureHandleView = PhotoMeteringHandleView(style: .exposure)
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?
    private var activeDevice: AVCaptureDevice?
    private weak var boundCameraManager: CameraManager?
    private var previewFrameCancellable: AnyCancellable?
    private var previewRenderer: MetalPreviewRenderer?
    private var zebraRenderer: ZebraOverlayRenderer?
    private var focusPeakingRenderer: FocusPeakingOverlayRenderer?
    private var currentPreviewRotationAngle: CGFloat = 0
    private var currentPreviewLookMode: PreviewLookMode = .log
    private var currentCaptureMode: CaptureMode = .video
    private var isPreviewSuspended = false
    private var isZebraEnabled = false
    private var isFocusPeakingEnabled = false
    private var photoMeteringPointsLinked = false
    private var photoFocusPreviewPoint: CGPoint?
    private var photoExposurePreviewPoint: CGPoint?

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

    private lazy var photoFocusPanGestureRecognizer = UIPanGestureRecognizer(
        target: self,
        action: #selector(handlePhotoFocusPan(_:))
    )

    private lazy var photoExposurePanGestureRecognizer = UIPanGestureRecognizer(
        target: self,
        action: #selector(handlePhotoExposurePan(_:))
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        layer.masksToBounds = true
        setupPreviewSurface()
        setupZebraSurface()
        setupFocusPeakingSurface()
        setupConversionLayer()
        setupPhotoMeteringHandles()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        clipsToBounds = true
        layer.masksToBounds = true
        setupPreviewSurface()
        setupZebraSurface()
        setupFocusPeakingSurface()
        setupConversionLayer()
        setupPhotoMeteringHandles()
        setupGestures()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        conversionPreviewLayer.frame = bounds
        updatePreviewSurfaceLayout()
        updatePhotoMeteringHandleLayout()
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
            guard !self.isPreviewSuspended else { return }
            self.previewRenderer?.enqueue(frame)
            self.zebraRenderer?.enqueue(frame)
            self.focusPeakingRenderer?.enqueue(frame)
        }
        applyConnectionConfiguration(from: cameraManager)
    }

    func setPreviewLookMode(_ mode: PreviewLookMode) {
        currentPreviewLookMode = mode
        previewRenderer?.setPreviewLookMode(mode)
        zebraRenderer?.setPreviewLookMode(mode)
        focusPeakingRenderer?.setPreviewLookMode(mode)
        updateVisiblePreviewMode()
    }

    func setCaptureMode(_ mode: CaptureMode) {
        guard currentCaptureMode != mode else { return }
        currentCaptureMode = mode
        if mode != .photo {
            hidePhotoMeteringHandles()
        }
        updateVisiblePreviewMode()
    }

    func setPhotoMeteringPointsLinked(_ isLinked: Bool) {
        guard photoMeteringPointsLinked != isLinked else { return }
        photoMeteringPointsLinked = isLinked
        guard isLinked else { return }

        if let linkedPoint = photoFocusPreviewPoint ?? photoExposurePreviewPoint {
            photoFocusPreviewPoint = linkedPoint
            photoExposurePreviewPoint = linkedPoint
            updatePhotoMeteringHandleLayout()
        }
    }

    func setPhotoMeteringHandlesVisible(_ isVisible: Bool) {
        guard !isVisible else { return }
        hidePhotoMeteringHandles()
    }

    func setZebraEnabled(_ isEnabled: Bool) {
        guard isZebraEnabled != isEnabled else { return }
        isZebraEnabled = isEnabled
        zebraSurface.isHidden = !isEnabled
        zebraRenderer?.setEnabled(isEnabled)
        if isEnabled {
            bringSubviewToFront(zebraSurface)
        }
        if !isEnabled {
            zebraRenderer?.clear()
        }
    }

    func setZebraThreshold(_ threshold: Float) {
        zebraRenderer?.setThreshold(threshold)
    }

    func setZebraChannel(_ channel: ZebraChannel) {
        zebraRenderer?.setChannel(channel)
    }

    func setFocusPeakingEnabled(_ isEnabled: Bool) {
        guard isFocusPeakingEnabled != isEnabled else { return }
        isFocusPeakingEnabled = isEnabled
        focusPeakingSurface.isHidden = !isEnabled
        focusPeakingRenderer?.setEnabled(isEnabled)
        if isEnabled {
            bringSubviewToFront(focusPeakingSurface)
        } else {
            focusPeakingRenderer?.clear()
        }
    }

    func setFocusPeakingSensitivity(_ sensitivityPercent: Int) {
        focusPeakingRenderer?.setSensitivityPercent(sensitivityPercent)
    }

    func setPreviewSuspended(_ isSuspended: Bool) {
        guard isPreviewSuspended != isSuspended else { return }
        isPreviewSuspended = isSuspended
        previewSurface.isPaused = isSuspended
        zebraSurface.isPaused = isSuspended
        focusPeakingSurface.isPaused = isSuspended
        if isSuspended {
            previewRenderer?.clear()
            zebraRenderer?.clear()
            focusPeakingRenderer?.clear()
        }
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

    private func setupZebraSurface() {
        zebraSurface.clipsToBounds = true
        zebraSurface.isUserInteractionEnabled = false
        zebraSurface.isOpaque = false
        zebraSurface.backgroundColor = .clear
        zebraSurface.clearColor = MTLClearColorMake(0, 0, 0, 0)
        zebraSurface.frame = bounds
        zebraRenderer = ZebraOverlayRenderer(view: zebraSurface)
        zebraSurface.isHidden = true
        addSubview(zebraSurface)
        bringSubviewToFront(zebraSurface)
    }

    private func setupFocusPeakingSurface() {
        focusPeakingSurface.clipsToBounds = true
        focusPeakingSurface.isUserInteractionEnabled = false
        focusPeakingSurface.isOpaque = false
        focusPeakingSurface.backgroundColor = .clear
        focusPeakingSurface.clearColor = MTLClearColorMake(0, 0, 0, 0)
        focusPeakingSurface.frame = bounds
        focusPeakingRenderer = FocusPeakingOverlayRenderer(view: focusPeakingSurface)
        focusPeakingSurface.isHidden = true
        addSubview(focusPeakingSurface)
        bringSubviewToFront(focusPeakingSurface)
    }

    private func setupConversionLayer() {
        conversionPreviewLayer.videoGravity = .resizeAspectFill
        // Keep the system preview layer around for tap-to-focus coordinate
        // conversion and rotation metadata, but render the visible preview from
        // the sample-buffer path so photo mode matches capture more closely.
        conversionPreviewLayer.isHidden = true
        layer.insertSublayer(conversionPreviewLayer, at: 0)
    }

    private func setupPhotoMeteringHandles() {
        photoFocusHandleView.addGestureRecognizer(photoFocusPanGestureRecognizer)
        photoExposureHandleView.addGestureRecognizer(photoExposurePanGestureRecognizer)
        addSubview(photoFocusHandleView)
        addSubview(photoExposureHandleView)
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
        previewPoint(fromLayerPoint: gesture.location(in: self))
    }

    private func previewPoint(fromLayerPoint point: CGPoint) -> CGPoint {
        guard bounds.width > 0, bounds.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }

        return CGPoint(
            x: min(max(point.x / bounds.width, 0), 1),
            y: min(max(point.y / bounds.height, 0), 1)
        )
    }

    private func layerPoint(from previewPoint: CGPoint) -> CGPoint {
        CGPoint(x: previewPoint.x * bounds.width, y: previewPoint.y * bounds.height)
    }

    private func capturePoint(fromLayerPoint point: CGPoint) -> CGPoint {
        conversionPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
    }

    @objc private func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        if currentCaptureMode == .photo {
            let location = gesture.location(in: self)
            let previewPoint = previewPoint(fromLayerPoint: location)
            showPhotoMeteringHandles(at: previewPoint)
            onPhotoMeteringSelection?(.both, capturePoint(fromLayerPoint: location))
            return
        }
        onFocusSelection?(capturePoint(from: gesture), previewPoint(from: gesture), false)
    }

    @objc private func handleLongPressToLock(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        if currentCaptureMode == .photo {
            showPhotoMeteringHandles(at: previewPoint(from: gesture))
        }
        onFocusSelection?(capturePoint(from: gesture), previewPoint(from: gesture), true)
    }

    @objc private func handlePhotoFocusPan(_ gesture: UIPanGestureRecognizer) {
        guard currentCaptureMode == .photo else { return }
        handlePhotoMeteringPan(gesture, kind: .focus)
    }

    @objc private func handlePhotoExposurePan(_ gesture: UIPanGestureRecognizer) {
        guard currentCaptureMode == .photo else { return }
        handlePhotoMeteringPan(gesture, kind: .exposure)
    }

    private func updatePreviewSurfaceLayout() {
        let normalizedAngle = abs(Int(currentPreviewRotationAngle.rounded())) % 360
        let swapsAxes = normalizedAngle == 90 || normalizedAngle == 270
        let baseSize = bounds.size
        let rotatedSize = swapsAxes
            ? CGSize(width: baseSize.height, height: baseSize.width)
            : baseSize

        previewSurface.transform = .identity
        zebraSurface.transform = .identity
        focusPeakingSurface.transform = .identity
        previewSurface.frame = CGRect(
            x: (bounds.width - rotatedSize.width) / 2,
            y: (bounds.height - rotatedSize.height) / 2,
            width: rotatedSize.width,
            height: rotatedSize.height
        )
        zebraSurface.frame = CGRect(
            x: (bounds.width - rotatedSize.width) / 2,
            y: (bounds.height - rotatedSize.height) / 2,
            width: rotatedSize.width,
            height: rotatedSize.height
        )
        focusPeakingSurface.frame = CGRect(
            x: (bounds.width - rotatedSize.width) / 2,
            y: (bounds.height - rotatedSize.height) / 2,
            width: rotatedSize.width,
            height: rotatedSize.height
        )

        var transform = CGAffineTransform(rotationAngle: currentPreviewRotationAngle * (.pi / 180))
        if activeDevice?.position == .front {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        previewSurface.transform = transform
        zebraSurface.transform = transform
        focusPeakingSurface.transform = transform
    }

    private func updateVisiblePreviewMode() {
        let showSampleBufferPreview = previewRenderer != nil
        previewSurface.isHidden = !showSampleBufferPreview
        previewSurface.alpha = 1
        conversionPreviewLayer.isHidden = showSampleBufferPreview
        if showSampleBufferPreview {
            bringSubviewToFront(previewSurface)
        }
        if isZebraEnabled {
            bringSubviewToFront(zebraSurface)
        }
        if isFocusPeakingEnabled {
            bringSubviewToFront(focusPeakingSurface)
        }
        if currentCaptureMode == .photo {
            bringSubviewToFront(photoFocusHandleView)
            bringSubviewToFront(photoExposureHandleView)
        }
    }

    private func showPhotoMeteringHandles(at previewPoint: CGPoint) {
        let wasVisible = photoFocusPreviewPoint != nil || photoExposurePreviewPoint != nil
        photoFocusPreviewPoint = previewPoint
        photoExposurePreviewPoint = previewPoint
        photoFocusHandleView.isHidden = false
        photoExposureHandleView.isHidden = false
        bringSubviewToFront(photoFocusHandleView)
        bringSubviewToFront(photoExposureHandleView)
        updatePhotoMeteringHandleLayout()
        if !wasVisible {
            onPhotoMeteringHandlesVisibilityChanged?(true)
        }
    }

    private func hidePhotoMeteringHandles() {
        let wasVisible = photoFocusPreviewPoint != nil || photoExposurePreviewPoint != nil
        photoFocusPreviewPoint = nil
        photoExposurePreviewPoint = nil
        photoFocusHandleView.isHidden = true
        photoExposureHandleView.isHidden = true
        if wasVisible {
            onPhotoMeteringHandlesVisibilityChanged?(false)
        }
    }

    private func updatePhotoMeteringHandleLayout() {
        updatePhotoMeteringHandleLayout(
            handleView: photoFocusHandleView,
            previewPoint: photoFocusPreviewPoint
        )
        updatePhotoMeteringHandleLayout(
            handleView: photoExposureHandleView,
            previewPoint: photoExposurePreviewPoint
        )
    }

    private func updatePhotoMeteringHandleLayout(handleView: UIView,
                                                 previewPoint: CGPoint?) {
        guard currentCaptureMode == .photo,
              let previewPoint else {
            handleView.isHidden = true
            return
        }

        handleView.center = layerPoint(from: previewPoint)
        handleView.isHidden = false
    }

    private func handlePhotoMeteringPan(_ gesture: UIPanGestureRecognizer,
                                        kind: PhotoMeteringHandleKind) {
        let location = gesture.location(in: self)
        let normalizedPreviewPoint = previewPoint(fromLayerPoint: location)
        let effectiveKind: PhotoMeteringHandleKind = photoMeteringPointsLinked ? .both : kind

        switch effectiveKind {
        case .focus:
            photoFocusPreviewPoint = normalizedPreviewPoint
        case .exposure:
            photoExposurePreviewPoint = normalizedPreviewPoint
        case .both:
            photoFocusPreviewPoint = normalizedPreviewPoint
            photoExposurePreviewPoint = normalizedPreviewPoint
        }

        updatePhotoMeteringHandleLayout()

        guard gesture.state == .began || gesture.state == .changed || gesture.state == .ended else { return }
        onPhotoMeteringSelection?(effectiveKind, capturePoint(fromLayerPoint: layerPoint(from: normalizedPreviewPoint)))
    }

    func applyConnectionConfiguration(from cameraManager: CameraManager) {
        if let connection = conversionPreviewLayer.connection {
            cameraManager.applyPreviewConnectionConfiguration(connection)
        }
    }
}
