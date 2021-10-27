//
//  SmileOverlay.swift
//  Heyoh
//
//  Created by Markiyan Kostiv on 02.10.2021.
//

import Cocoa
import CoreImage
import Foundation

class SmileOverlay {
    private let maxPropagateCount: Int = 60
    private let minNumPredictions: Int = 6

    private var counter: Int = 0
    private var propagateCount = 0

    private let positiveOpacityStep: Double = 1.0 / 60
    private let negativeOpacityStep: Double = 1.0 / 60

    private var opacityValue: Double = 0.0
    private var overlayOpacity: Double {
        set {
            opacityValue = clamp(value: newValue, lower: 0.0, upper: 1.0)
        }
        get {
            return opacityValue
        }
    }

    var size: CGSize? {
        didSet {
            if oldValue != size {
                let imagePaths = stride(from: 0, to: 1, by: 1).map { "smile\($0)" }
                overlays = imagePaths.compactMap { loadImage(image_name: $0, size: size) }
            }
        }
    }

    var overlays: [CIImage] = []

    var currentOverlay: CIImage? {
        let index = counter % overlays.count
        guard index < overlays.count else {
            return nil
        }
        return overlays[counter % overlays.count].image(opacity: CGFloat(overlayOpacity))
    }

    func getOverlay(isSmiling: Bool) -> CIImage? {
        guard isSmiling else {
            if counter < minNumPredictions {
                resetHistory()
                return nil
            }
            return propagete()
        }

        counter += 1

        overlayOpacity += positiveOpacityStep
        return currentOverlay
    }

    private func propagete() -> CIImage? {
        guard propagateCount <= maxPropagateCount else {
            resetHistory()
            return nil
        }

        propagateCount += 1
        overlayOpacity -= negativeOpacityStep
        return currentOverlay
    }

    private func resetHistory() {
        overlayOpacity = 0.0
        propagateCount = 0
        counter = 0
    }

    func loadImage(image_name: String, size: CGSize? = nil) -> CIImage {
        let bundle = Bundle(for: type(of: self))
        guard let rotatedImage = bundle.image(forResource: image_name), let data = rotatedImage.tiffRepresentation, let ciImage = CIImage(data: data) else {
            assertionFailure()
            return CIImage()
        }

        let imageWidth = ciImage.extent.width
        let imageHeight = ciImage.extent.height

        guard let size = size else {
            return ciImage
        }

        let videoWidth = size.width
        let videoHeight = size.height

        let scaleX = CGFloat(videoWidth) / CGFloat(imageWidth)
        let scaleY = CGFloat(videoHeight) / CGFloat(imageHeight)

        let scale = min(scaleX, scaleY)
        let scaledImage = scaleImage(image: ciImage, scale: scale)

        return CIImage(cgImage: cidContext.createCGImage(scaledImage, from: scaledImage.extent)!)
    }
}

private func clamp<T: Comparable>(value: T, lower: T, upper: T) -> T {
    return min(max(value, lower), upper)
}

extension CIImage {
    func image(opacity: CGFloat) -> CIImage? {
        guard let overlayFilter = CIFilter(name: "CIColorMatrix") else { fatalError() }
        let overlayRgba: [CGFloat] = [0, 0, 0, opacity]
        let alphaVector = CIVector(values: overlayRgba, count: 4)
        overlayFilter.setValue(self, forKey: kCIInputImageKey)
        overlayFilter.setValue(alphaVector, forKey: "inputAVector")
        return overlayFilter.outputImage
    }
}

private let cidContext = CIContext(options: [CIContextOption.useSoftwareRenderer: true])

func scaleImage(image: CIImage, scale: CGFloat) -> CIImage {
    let returnImage = image.applyingFilter("CILanczosScaleTransform", parameters: ["inputScale": scale])
    return returnImage
}
