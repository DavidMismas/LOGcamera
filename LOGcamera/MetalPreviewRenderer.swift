import AVFoundation
import CoreImage
import CoreVideo
import MetalKit

enum PreviewYCbCrMatrix {
    case rec601
    case rec709
}

final class PreviewFrame {
    let pixelBuffer: CVPixelBuffer
    let profile: CaptureColorProfile
    let yCbCrMatrix: PreviewYCbCrMatrix
    let isFullRange: Bool

    init(pixelBuffer: CVPixelBuffer,
         profile: CaptureColorProfile,
         yCbCrMatrix: PreviewYCbCrMatrix,
         isFullRange: Bool) {
        self.pixelBuffer = pixelBuffer
        self.profile = profile
        self.yCbCrMatrix = yCbCrMatrix
        self.isFullRange = isFullRange
    }
}

final class MetalPreviewRenderer: NSObject, MTKViewDelegate {
    private weak var view: MTKView?
    private let commandQueue: MTLCommandQueue
    private let managedContext: CIContext
    private let cubeContext: CIContext
    private let lutProcessor = PreviewLUTProcessor()
    private let stateQueue = DispatchQueue(label: "com.logcamera.metalPreviewState")
    private let rec709ColorSpace = CGColorSpace(name: CGColorSpace.itur_709) ?? CGColorSpace(name: CGColorSpace.sRGB)!

    private var latestFrame: PreviewFrame?
    private var previewLookMode: PreviewLookMode = .log

    init?(view: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }

        self.view = view
        self.commandQueue = commandQueue
        self.managedContext = CIContext(
            mtlDevice: device,
            options: [.cacheIntermediates: false]
        )
        self.cubeContext = CIContext(
            mtlDevice: device,
            options: [
                .cacheIntermediates: false,
                .workingColorSpace: NSNull()
            ]
        )

        super.init()

        view.device = device
        view.delegate = self
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = false
        view.isOpaque = true
        view.backgroundColor = .black
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
    }

    func setPreviewLookMode(_ mode: PreviewLookMode) {
        stateQueue.async {
            self.previewLookMode = mode
        }
    }

    func enqueue(_ frame: PreviewFrame) {
        stateQueue.async {
            self.latestFrame = frame
        }
    }

    func clear() {
        stateQueue.async {
            self.latestFrame = nil
        }
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }

        let (frame, lookMode) = stateQueue.sync { (latestFrame, previewLookMode) }
        guard let frame,
              let renderRequest = makeRenderRequest(for: frame, lookMode: lookMode),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let bounds = CGRect(origin: .zero, size: view.drawableSize)
        guard bounds.width > 0, bounds.height > 0 else { return }

        let outputImage = renderRequest.image.transformed(
            by: aspectFillTransform(for: renderRequest.image.extent, in: bounds)
        )

        renderRequest.context.render(
            outputImage,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: bounds,
            colorSpace: renderRequest.outputColorSpace
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    private struct RenderRequest {
        let image: CIImage
        let context: CIContext
        let outputColorSpace: CGColorSpace
    }

    private func makeRenderRequest(for frame: PreviewFrame, lookMode: PreviewLookMode) -> RenderRequest? {
        let pixelBuffer = frame.pixelBuffer
        let rawImage = CIImage(
            cvPixelBuffer: pixelBuffer,
            options: [
                .applyCleanAperture: true,
                .colorSpace: NSNull()
            ]
        )

        switch lookMode {
        case .log:
            var options: [CIImageOption: Any] = [
                .applyCleanAperture: true
            ]
            if let sourceColorSpace = sourceColorSpace(for: pixelBuffer) {
                options[.colorSpace] = sourceColorSpace
            }
            let managedImage = CIImage(cvPixelBuffer: pixelBuffer, options: options)
            return RenderRequest(
                image: managedImage,
                context: managedContext,
                outputColorSpace: rec709ColorSpace
            )

        case .rec709:
            if let cube = lutProcessor.cube(for: frame.profile),
               let filter = CIFilter(name: "CIColorCube") {
                filter.setValue(rawImage, forKey: kCIInputImageKey)
                filter.setValue(cube.dimension, forKey: "inputCubeDimension")
                filter.setValue(cube.data, forKey: "inputCubeData")

                if let outputImage = filter.outputImage?.cropped(to: rawImage.extent) {
                    return RenderRequest(
                        image: outputImage,
                        context: cubeContext,
                        outputColorSpace: rec709ColorSpace
                    )
                }
            }

            return RenderRequest(
                image: rawImage,
                context: cubeContext,
                outputColorSpace: rec709ColorSpace
            )
        }
    }

    private func sourceColorSpace(for pixelBuffer: CVPixelBuffer) -> CGColorSpace? {
        if let directColorSpace = CVImageBufferGetColorSpace(pixelBuffer) {
            return directColorSpace.takeUnretainedValue()
        }

        guard let attachments = CVBufferCopyAttachments(pixelBuffer, .shouldPropagate) else {
            return nil
        }

        return CVImageBufferCreateColorSpaceFromAttachments(attachments as CFDictionary)?.takeRetainedValue()
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
