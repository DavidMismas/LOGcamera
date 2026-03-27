import AVFoundation
import CoreImage
import MetalKit

struct PreviewFrame {
    let sampleBuffer: CMSampleBuffer
    let profile: CaptureColorProfile
}

final class MetalPreviewRenderer: NSObject, MTKViewDelegate {
    private weak var view: MTKView?
    private let ciContext: CIContext
    private let lutProcessor = PreviewLUTProcessor()
    private let stateQueue = DispatchQueue(label: "com.logcamera.metalPreviewState")
    private let smoothingAmount: Float = 0.22

    private var latestFrame: PreviewFrame?
    private var previousRenderedImage: CIImage?

    init?(view: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }

        self.view = view
        self.ciContext = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])

        super.init()

        view.device = device
        view.delegate = self
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = false
        view.isOpaque = false
        view.backgroundColor = .clear
        view.enableSetNeedsDisplay = false
        view.isPaused = true
    }

    func enqueue(_ frame: PreviewFrame) {
        stateQueue.async {
            self.latestFrame = frame
        }

        DispatchQueue.main.async { [weak self] in
            self?.view?.draw()
        }
    }

    func clear() {
        stateQueue.async {
            self.latestFrame = nil
            self.previousRenderedImage = nil
        }
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }

        let frame = stateQueue.sync { latestFrame }
        guard let frame,
              let cube = lutProcessor.cube(for: frame.profile),
              let pixelBuffer = CMSampleBufferGetImageBuffer(frame.sampleBuffer),
              let filter = CIFilter(name: "CIColorCubeWithColorSpace") else {
            return
        }

        let image = CIImage(cvPixelBuffer: pixelBuffer)
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(cube.data, forKey: "inputCubeData")
        filter.setValue(cube.dimension, forKey: "inputCubeDimension")
        filter.setValue(lutProcessor.outputColorSpace, forKey: "inputColorSpace")

        guard let outputImage = filter.outputImage else { return }

        let smoothedImage = blendedImage(for: outputImage)

        let drawableBounds = CGRect(origin: .zero, size: view.drawableSize)
        let scaledImage = smoothedImage.transformed(by: aspectFillTransform(for: smoothedImage.extent, in: drawableBounds))

        ciContext.render(
            scaledImage,
            to: drawable.texture,
            commandBuffer: nil,
            bounds: drawableBounds,
            colorSpace: lutProcessor.outputColorSpace
        )

        drawable.present()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    private func blendedImage(for currentImage: CIImage) -> CIImage {
        let previousImage = stateQueue.sync { previousRenderedImage }
        let outputImage: CIImage

        if let previousImage,
           let transition = CIFilter(name: "CIDissolveTransition") {
            transition.setValue(previousImage.cropped(to: currentImage.extent), forKey: kCIInputImageKey)
            transition.setValue(currentImage, forKey: kCIInputTargetImageKey)
            transition.setValue(smoothingAmount, forKey: kCIInputTimeKey)
            outputImage = transition.outputImage?.cropped(to: currentImage.extent) ?? currentImage
        } else {
            outputImage = currentImage
        }

        stateQueue.async {
            self.previousRenderedImage = outputImage
        }

        return outputImage
    }

    private func aspectFillTransform(for sourceRect: CGRect, in targetRect: CGRect) -> CGAffineTransform {
        guard sourceRect.width > 0,
              sourceRect.height > 0,
              targetRect.width > 0,
              targetRect.height > 0 else {
            return .identity
        }

        let scale = max(targetRect.width / sourceRect.width, targetRect.height / sourceRect.height)
        let scaledWidth = sourceRect.width * scale
        let scaledHeight = sourceRect.height * scale
        let translateX = targetRect.midX - scaledWidth / 2 - sourceRect.minX * scale
        let translateY = targetRect.midY - scaledHeight / 2 - sourceRect.minY * scale

        return CGAffineTransform(scaleX: scale, y: scale)
            .translatedBy(x: translateX / scale, y: translateY / scale)
    }
}
