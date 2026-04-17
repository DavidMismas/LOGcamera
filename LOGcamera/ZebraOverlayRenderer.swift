import CoreImage
import CoreVideo
import MetalKit

final class ZebraOverlayRenderer: NSObject, MTKViewDelegate {
    private weak var view: MTKView?
    private let commandQueue: MTLCommandQueue
    private let context: CIContext
    private let lutProcessor = PreviewLUTProcessor()
    private let stateQueue = DispatchQueue(label: "com.logcamera.zebraOverlayState")
    private let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    private var latestFrame: PreviewFrame?
    private var isEnabled = false
    private var threshold: Float = 0.95
    private var channel: ZebraChannel = .red
    private var previewLookMode: PreviewLookMode = .log

    private static let zebraKernel: CIColorKernel? = {
        let source = """
        kernel vec4 zebra(__sample image,
                          float threshold,
                          float softness,
                          float stripeWidth,
                          float channelIndex,
                          float stripeRed,
                          float stripeGreen,
                          float stripeBlue) {
            float3 rgb = clamp(image.rgb, 0.0, 1.0);
            float signal = channelIndex < 0.5 ? rgb.r : (channelIndex < 1.5 ? rgb.g : rgb.b);
            float mask = smoothstep(threshold - softness, threshold + softness, signal);
            if (mask <= 0.001) {
                return vec4(0.0, 0.0, 0.0, 0.0);
            }

            vec2 p = destCoord();
            float stripe = step(0.5, fract((p.x + p.y) / stripeWidth));
            if (stripe > 0.0) {
                return vec4(stripeRed, stripeGreen, stripeBlue, 0.90 * mask);
            }

            return vec4(0.0, 0.0, 0.0, 0.60 * mask);
        }
        """
        return CIColorKernel(source: source)
    }()

    init?(view: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }

        self.view = view
        self.commandQueue = commandQueue
        self.context = CIContext(
            mtlDevice: device,
            options: [.cacheIntermediates: false]
        )

        super.init()

        view.device = device
        view.delegate = self
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = false
        view.isOpaque = false
        view.backgroundColor = .clear
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
    }

    func setEnabled(_ isEnabled: Bool) {
        stateQueue.async {
            self.isEnabled = isEnabled
        }
    }

    func setThreshold(_ threshold: Float) {
        stateQueue.async {
            self.threshold = min(max(threshold, 0.80), 1.0)
        }
    }

    func setChannel(_ channel: ZebraChannel) {
        stateQueue.async {
            self.channel = channel
        }
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
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let frame = stateQueue.sync { latestFrame }
        let overlayEnabled = stateQueue.sync { isEnabled }
        let threshold = stateQueue.sync { self.threshold }
        let channel = stateQueue.sync { self.channel }
        let previewLookMode = stateQueue.sync { self.previewLookMode }
        let bounds = CGRect(origin: .zero, size: view.drawableSize)
        guard bounds.width > 0, bounds.height > 0 else { return }

        let outputImage: CIImage
        if overlayEnabled,
           let frame,
           let zebraImage = makeZebraImage(
            for: frame,
            in: bounds,
            threshold: threshold,
            channel: channel,
            lookMode: previewLookMode
           ) {
            outputImage = zebraImage
        } else {
            outputImage = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: bounds)
        }

        context.render(
            outputImage,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: bounds,
            colorSpace: outputColorSpace
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    private func makeZebraImage(for frame: PreviewFrame,
                                in bounds: CGRect,
                                threshold: Float,
                                channel: ZebraChannel,
                                lookMode: PreviewLookMode) -> CIImage? {
        guard let kernel = Self.zebraKernel else { return nil }
        guard let sourceImage = monitoringImage(for: frame, lookMode: lookMode) else { return nil }
        let measurementImage = sourceImage
            .clampedToExtent()
            .applyingFilter(
                "CIGaussianBlur",
                parameters: [kCIInputRadiusKey: 1.2]
            )
            .cropped(to: sourceImage.extent)
        let stripeColor = channel.colorComponents
        guard let overlayImage = kernel.apply(
            extent: measurementImage.extent,
            arguments: [
                measurementImage,
                threshold,
                0.015,
                18.0,
                channel.kernelIndex,
                stripeColor.red,
                stripeColor.green,
                stripeColor.blue
            ]
        ) else {
            return nil
        }

        return overlayImage.transformed(
            by: aspectFillTransform(for: sourceImage.extent, in: bounds)
        )
    }

    private func monitoringImage(for frame: PreviewFrame, lookMode: PreviewLookMode) -> CIImage? {
        switch lookMode {
        case .log:
            var options: [CIImageOption: Any] = [.applyCleanAperture: true]
            if let sourceColorSpace = sourceColorSpace(for: frame.pixelBuffer) {
                options[.colorSpace] = sourceColorSpace
            }
            return CIImage(cvPixelBuffer: frame.pixelBuffer, options: options)

        case .rec709:
            let rawImage = CIImage(
                cvPixelBuffer: frame.pixelBuffer,
                options: [
                    .applyCleanAperture: true,
                    .colorSpace: NSNull()
                ]
            )

            guard let cube = lutProcessor.cube(for: frame.profile),
                  let filter = CIFilter(name: "CIColorCube") else {
                return rawImage
            }

            filter.setValue(rawImage, forKey: kCIInputImageKey)
            filter.setValue(cube.dimension, forKey: "inputCubeDimension")
            filter.setValue(cube.data, forKey: "inputCubeData")
            return filter.outputImage?.cropped(to: rawImage.extent) ?? rawImage
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
