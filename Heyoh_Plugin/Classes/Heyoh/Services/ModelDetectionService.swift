//
//  ModelDetectionService.swift
//  Heyoh
//
//  Created by Oleg Sehelin on 28.09.2021.
//

import Cocoa
import CoreMedia
import Foundation
import Vision

protocol ModelDetectionServiceProtocol: AnyObject {
    func getVideoSize() -> CMVideoDimensions
    func drawOverlaysOnPreviewLayer(_ overlays: [OutputStruct], smileOverlay: CIImage?)
}

class ModelDetectionService: NSObject {
    weak var delegate: ModelDetectionServiceProtocol?
    fileprivate var loadedImages = [CIImage]()
    fileprivate let detectionTracks: [SideType: DetectionTrack] = [.left: DetectionTrack(side: .left),
                                                                   .right: DetectionTrack(side: .right)]
    fileprivate let smileOverlay = SmileOverlay()

    fileprivate lazy var segmentationReuqest: VNCoreMLRequest = {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        guard let mobilenet = try? detection_v5(configuration: config) else {
            fatalError("Unable to load with config")
        }

        guard let model = try? VNCoreMLModel(for: mobilenet.model) else {
            fatalError("Model not loaded!")
        }

        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFit
        return request
    }()

    func getModelMatrixResult(_ buffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            return
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([segmentationReuqest])
        let results = segmentationReuqest.results as? [VNCoreMLFeatureValueObservation]
        guard let coords = results?.filter({ $0.featureName == "coords" }).first?.featureValue.multiArrayValue,
              let sizeWidth = results?.filter({ $0.featureName == "size_width" }).first?.featureValue.multiArrayValue,
              let sizeHeight = results?.filter({ $0.featureName == "size_height" }).first?.featureValue.multiArrayValue,
              let side = results?.filter({ $0.featureName == "side_squeezed" }).first?.featureValue.multiArrayValue
        else {
            return
        }

        if let videoDimensions = delegate?.getVideoSize() {
            smileOverlay.size = CGSize(width: Int(videoDimensions.width), height: Int(videoDimensions.height))
        }

        let layersList = formedListOfOverlays(coords, sizeWidth: sizeWidth, sizeHeight: sizeHeight, side: side)

        autoreleasepool {
            delegate?.drawOverlaysOnPreviewLayer(layersList.stickers, smileOverlay: layersList.smileOverlay)
        }
    }

    fileprivate func formedListOfOverlays(_ coords: MLMultiArray,
                                          sizeWidth: MLMultiArray,
                                          sizeHeight: MLMultiArray,
                                          side: MLMultiArray) -> (smileOverlay: CIImage?, stickers: [OutputStruct]) {
        let numRows = coords.shape.first?.intValue ?? 0
        var result = [OutputStruct]()
        var detections: [DetectionStruct] = []

        var leftHandDetected = false
        var rightHandDetected = false
        for rowNumber in 0 ..< numRows {
            var detetion = DetectionStruct(coords: coords,
                                           sizeWidth: sizeWidth,
                                           sizeHeight: sizeHeight,
                                           side: side,
                                           rowNumber: NSNumber(value: rowNumber))
            detections.append(detetion)

            switch detetion.classType {
            case .thumbUp, .thumbDown, .hand:
                let track: DetectionTrack? = detectionTracks[detetion.sidePrediction]
                switch detetion.sidePrediction {
                case .left:
                    leftHandDetected = true
                case .right:
                    rightHandDetected = true
                }

                let rect = CGRect(x: detetion.x,
                                  y: detetion.y,
                                  width: detetion.width,
                                  height: detetion.height)
                guard let prediction = track?.getCoordinates(prediction: (rect, detetion.classType)) else {
                    continue
                }
                detetion = DetectionStruct(classType: detetion.classType,
                                           sidePrediction: detetion.sidePrediction,
                                           x: Double(prediction.rect.origin.x),
                                           y: Double(prediction.rect.origin.y),
                                           width: Double(prediction.rect.size.width),
                                           height: Double(prediction.rect.size.height))

                if let layer = configureThumbOverlay(detetion) {
                    result.append(layer)
                }
            default:
                continue
            }
        }

        if !leftHandDetected {
            if let layer = propagateOverlay(side: .left) {
                result.append(layer)
            }
        }

        if !rightHandDetected {
            if let layer = propagateOverlay(side: .right) {
                result.append(layer)
            }
        }

        let isSmiling = detections.filter { $0.classType == .smile }.count > 0
        let overlay = smileOverlay.getOverlay(isSmiling: isSmiling)

        return (overlay, result)
    }

    fileprivate func propagateOverlay(side: SideType) -> OutputStruct? {
        guard let prediction = detectionTracks[side]?.getCoordinates(prediction: nil) else {
            return nil
        }

        let detection = DetectionStruct(classType: prediction.detectionType,
                                        sidePrediction: side,
                                        x: Double(prediction.rect.origin.x),
                                        y: Double(prediction.rect.origin.y),
                                        width: Double(prediction.rect.size.width),
                                        height: Double(prediction.rect.size.height))

        return configureThumbOverlay(detection)
    }

    fileprivate func configureThumbOverlay(_ detection: DetectionStruct) -> OutputStruct? {
        if let videoSize = delegate?.getVideoSize() {
            let result = getCorrectImage(detection)
            guard let thumbImage = result.image else {
                return nil
            }

            // TODO: Double check the coordinates and scales
            let scaleX = Double(videoSize.width) / 256.0
            let width = detection.width * scaleX
            let height = detection.height * scaleX
            let originX = (detection.x + detection.offsetX) * scaleX
            let originY = Double(videoSize.height) - detection.y * scaleX

            let frameRect = NSRect(x: originX, y: originY, width: width, height: height)

            return OutputStruct(image: thumbImage, frame: frameRect, sizeMultiplier: result.sizeMultiplier)
        }

        return nil
    }

    func loadImage(image_name: String, isFlipped: Bool) -> CIImage {
        let bundle = Bundle(for: type(of: self))
        guard let rotatedImage = bundle.image(forResource: image_name), let data = rotatedImage.tiffRepresentation, let ciImage = CIImage(data: data) else {
            assertionFailure()
            return CIImage()
        }

        return isFlipped ? ciImage.oriented(.upMirrored) : ciImage
    }

    func loadImagesInMemory() {
        loadedImages.append(loadImage(image_name: "thumb_up", isFlipped: true))
        loadedImages.append(loadImage(image_name: "thumb_up", isFlipped: false))
        loadedImages.append(loadImage(image_name: "thumb_down", isFlipped: true))
        loadedImages.append(loadImage(image_name: "thumb_down", isFlipped: false))
        loadedImages.append(loadImage(image_name: "hand_up", isFlipped: true))
        loadedImages.append(loadImage(image_name: "hand_up", isFlipped: false))
    }

    fileprivate func getCorrectImage(_ detection: DetectionStruct) -> (image: CIImage?, sizeMultiplier: CGFloat) {
        if detection.classType == .thumbUp {
            return detection.sidePrediction == .left ? (loadedImages.first, 2.5) : (loadedImages[1], 2.5)
        } else if detection.classType == .thumbDown {
            return detection.sidePrediction == .left ? (loadedImages[2], 2.7) : (loadedImages[3], 2.7)
        } else {
            return detection.sidePrediction == .left ? (loadedImages[4], 2.5) : (loadedImages.last, 2.5)
        }
    }
}
