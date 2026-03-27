import CoreGraphics
import Foundation

struct PreviewLUTCube {
    let dimension: Int
    let data: Data
}

final class PreviewLUTProcessor {
    let outputColorSpace = CGColorSpace(name: CGColorSpace.itur_709) ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    private lazy var appleLogCube = loadCube(named: "AppleLogToRec709")
    private lazy var appleLog2Cube = loadCube(named: "AppleLog2ToRec709")

    func cube(for profile: CaptureColorProfile) -> PreviewLUTCube? {
        switch profile {
        case .appleLog2:
            return appleLog2Cube ?? appleLogCube
        case .appleLog:
            return appleLogCube
        case .unavailable:
            return nil
        }
    }

    private func loadCube(named resourceName: String) -> PreviewLUTCube? {
        let url = Bundle.main.url(forResource: resourceName, withExtension: "cube", subdirectory: "LUTs")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "cube")

        guard let url,
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        var dimension = 0
        var values: [Float] = []

        for rawLine in contents.components(separatedBy: .newlines) {
            let lineWithoutComment = rawLine
                .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !lineWithoutComment.isEmpty else { continue }

            if lineWithoutComment.hasPrefix("LUT_3D_SIZE") {
                let parts = lineWithoutComment.split(whereSeparator: \.isWhitespace)
                if let rawValue = parts.last, let parsedDimension = Int(rawValue) {
                    dimension = parsedDimension
                }
                continue
            }

            if lineWithoutComment.hasPrefix("TITLE") || lineWithoutComment.hasPrefix("DOMAIN_") {
                continue
            }

            let components = lineWithoutComment.split(whereSeparator: \.isWhitespace)
            guard components.count == 3,
                  let red = Float(components[0]),
                  let green = Float(components[1]),
                  let blue = Float(components[2]) else {
                continue
            }

            values.append(red)
            values.append(green)
            values.append(blue)
            values.append(1)
        }

        guard dimension > 1,
              values.count == dimension * dimension * dimension * 4 else {
            return nil
        }

        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        return PreviewLUTCube(dimension: dimension, data: data)
    }
}
