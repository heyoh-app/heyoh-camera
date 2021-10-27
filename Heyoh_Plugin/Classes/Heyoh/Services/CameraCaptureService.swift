//
//  CameraCaptureService.swift
//  Heyoh
//
//  Created by Oleg Sehelin on 28.09.2021.
//

import AVFoundation
import Cocoa
import Foundation

protocol CameraCaptureServiceProtocol: AnyObject {
    func displayOutputRenderedFrame(_ image: CIImage)
}

class CameraCaptureService: NSObject {
    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], autoreleaseFrequency: .workItem)
    private let captureSession = AVCaptureSession()

    fileprivate weak var deviceService: DeviceService?
    fileprivate var modelService = ModelDetectionService()
    fileprivate var originalImageFrame: CIImage?
    fileprivate var contentView: NSView?
    fileprivate var ciContext: CIContext!
    fileprivate lazy var watermark: CIImage = {
        guard let watermarkImage = loadImage(image_name: "watermark").image(opacity: 0.3) else {
            fatalError("Watermark was not loaded")
        }
        return watermarkImage
    }()

    weak var delegate: CameraCaptureServiceProtocol?

    lazy var context: CIContext = {
        CIContext(options: nil)
    }()

    init(withCameraView view: NSView?, service: DeviceService?) {
        super.init()
        contentView = view
        deviceService = service
        modelService.loadImagesInMemory()
        modelService.delegate = self
        startSesionProcess()
    }

    func startSesionProcess() {
        sessionQueue.async {
            self.configureSession()
            self.captureSession.startRunning()
        }
    }

    fileprivate func configureSession() {
        guard let captureDevice = DeviceService.formedDefaultVideoDevice() else {
            return
        }

        captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        do {
            let webcamInput: AVCaptureDeviceInput = (try AVCaptureDeviceInput(device: captureDevice))
            captureSession.addInput(webcamInput)

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))

            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]

            videoOutput.alwaysDiscardsLateVideoFrames = true
            captureSession.addOutput(videoOutput)
        } catch {
            print(" ERROR HERE \(error.localizedDescription)")
        }
    }

    func stopSession() {
        captureSession.stopRunning()
        originalImageFrame = nil
        showOutputFrame()
    }

    func refreshSessionInputDevice() {
        if let captureDevice = DeviceService.formedDefaultVideoDevice() {
            // Indicate that some changes will be made to the session
            captureSession.beginConfiguration()

            // Remove existing input
            if let currentCameraInput: AVCaptureInput = captureSession.inputs.first {
                captureSession.removeInput(currentCameraInput)
            }

            var videoDeviceInput: AVCaptureDeviceInput?
            do {
                videoDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
            } catch let err as NSError {
                print("Could not create video device input: \(err)")
            }

            if videoDeviceInput != nil {
                captureSession.addInput(videoDeviceInput!)
            }

            // Commit all the configuration changes at once
            captureSession.commitConfiguration()
        }
    }

    func startRenderingProcess(_ sampleBuffer: CMSampleBuffer) {
        saveOriginalFrameImage(sampleBuffer)
        modelService.getModelMatrixResult(sampleBuffer)
    }
}

extension CameraCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
        startRenderingProcess(sampleBuffer)
    }

    fileprivate func saveOriginalFrameImage(_ sampleBuffer: CMSampleBuffer) {
        let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        originalImageFrame = CIImage(cvPixelBuffer: pixelBuffer).oriented(.upMirrored)
    }
}

extension CameraCaptureService: ModelDetectionServiceProtocol {
    func getVideoSize() -> CMVideoDimensions {
        if let input = captureSession.inputs.first as? AVCaptureDeviceInput {
            let dims: CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(input.device.activeFormat.formatDescription)
            return dims
        }
        return CMVideoDimensions(width: 0, height: 0)
    }

    func drawOverlaysOnPreviewLayer(_ overlays: [OutputStruct], smileOverlay: CIImage? = nil) {
        guard originalImageFrame != nil, overlays.count > 0 || smileOverlay != nil else {
            showOutputFrame()
            return
        }

        for overlay in overlays {
            var inputImage = overlay.image
            inputImage = scaleImage(image: inputImage, scale: max(overlay.frame.width, overlay.frame.height) / max(inputImage.extent.width, inputImage.extent.height) * overlay.sizeMultiplier)

            let x = originalImageFrame!.extent.size.width - overlay.frame.origin.x - inputImage.extent.width / 2
            let y = overlay.frame.origin.y - inputImage.extent.height / 2
            let toTransform = CGAffineTransform(translationX: x,
                                                y: y)
            inputImage = inputImage.transformed(by: toTransform)

            let sourceOverCompositingFilter = CIFilter(name: "CISourceOverCompositing")!
            sourceOverCompositingFilter.setValue(inputImage, forKey: kCIInputImageKey)
            sourceOverCompositingFilter.setValue(originalImageFrame!, forKey: kCIInputBackgroundImageKey)

            if let outputImage = sourceOverCompositingFilter.outputImage {
                originalImageFrame = outputImage.cropped(to: originalImageFrame!.extent)
            }
        }

        if let smileOverlay = smileOverlay {
            originalImageFrame = smileOverlay.composited(over: originalImageFrame!)
        }

        showOutputFrame()
    }

    fileprivate func showOutputFrame() {
        if originalImageFrame != nil {
            originalImageFrame = addWatermark(inputImage: originalImageFrame!)
            let rep = NSCIImageRep(ciImage: originalImageFrame!)
            let finalImage = NSImage(size: rep.size)
            finalImage.addRepresentation(rep)
            delegate?.displayOutputRenderedFrame(originalImageFrame!)

            DispatchQueue.main.async {
                self.contentView?.layer?.contents = finalImage
            }
        } else {
            DispatchQueue.main.async {
                self.contentView?.layer?.contents = nil
            }
        }
    }

    fileprivate func addWatermark(inputImage: CIImage) -> CIImage? {
        guard var watermarkImage = watermark.copy() as? CIImage else {
            return nil
        }
        let toTransform = CGAffineTransform(translationX: inputImage.extent.size.width - watermark.extent.size.width - 20,
                                            y: inputImage.extent.size.height - watermark.extent.size.height - 20)
        watermarkImage = watermarkImage.transformed(by: toTransform)

        let sourceOverCompositingFilter = CIFilter(name: "CISourceOverCompositing")!
        sourceOverCompositingFilter.setValue(watermarkImage, forKey: kCIInputImageKey)
        sourceOverCompositingFilter.setValue(inputImage, forKey: kCIInputBackgroundImageKey)
        return sourceOverCompositingFilter.outputImage
    }

    func scaleImage(image: CIImage, scale: CGFloat) -> CIImage {
        let returnImage = image.applyingFilter("CILanczosScaleTransform", parameters: ["inputScale": scale])
        return returnImage
    }
}
