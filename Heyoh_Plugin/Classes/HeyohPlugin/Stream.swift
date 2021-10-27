import AVFoundation
import Cocoa
import Foundation

extension NSImage {
    func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let options = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ] as [String: Any]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorSystemDefault,
                                         Int(width),
                                         Int(height),
                                         kCVPixelFormatType_32ARGB,
                                         options as CFDictionary,
                                         &pixelBuffer)

        guard let resultPixelBuffer = pixelBuffer, status == kCVReturnSuccess else {
            return nil
        }

        CVPixelBufferLockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(resultPixelBuffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData,
                                      width: Int(width),
                                      height: Int(height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(resultPixelBuffer),
                                      space: rgbColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)

        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()

        CVPixelBufferUnlockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

        return resultPixelBuffer
    }
}

class Stream: NSObject, Object {
    var objectID: CMIOObjectID = 0
    let name = "HeyohPlugin"
    var width = 1280
    var height = 720
    let frameRate = 30

    fileprivate var deviceService: DeviceService?
    fileprivate var cameraService: CameraCaptureService?
    private var sequenceNumber: UInt64 = 0
    private var queueAlteredProc: CMIODeviceStreamQueueAlteredProc?
    private var queueAlteredRefCon: UnsafeMutableRawPointer?

    var pixelBufferVar: CVPixelBuffer?
    private var ciContext: CIContext!
    private var outputBuffer: CVPixelBuffer?

    private lazy var formatDescription: CMVideoFormatDescription? = {
        var formatDescription: CMVideoFormatDescription?
        let error = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32ARGB,
            width: Int32(width), height: Int32(height),
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        guard error == noErr else {
            log("CMVideoFormatDescriptionCreate Error: \(error)")
            return nil
        }
        return formatDescription
    }()

    private lazy var clock: CFTypeRef? = {
        var clock: Unmanaged<CFTypeRef>?

        let error = CMIOStreamClockCreate(
            kCFAllocatorDefault,
            "SimpleDALPlugin clock" as CFString,
            Unmanaged.passUnretained(self).toOpaque(),
            CMTimeMake(value: 1, timescale: 10),
            100, 10,
            &clock
        )
        guard error == noErr else {
            log("CMIOStreamClockCreate Error: \(error)")
            return nil
        }
        return clock?.takeUnretainedValue()
    }()

    private lazy var queue: CMSimpleQueue? = {
        var queue: CMSimpleQueue?
        let error = CMSimpleQueueCreate(
            allocator: kCFAllocatorDefault,
            capacity: 30,
            queueOut: &queue
        )
        guard error == noErr else {
            log("CMSimpleQueueCreate Error: \(error)")
            return nil
        }
        return queue
    }()

    lazy var properties: [Int: Property] = [
        kCMIOObjectPropertyName: Property(name),
        kCMIOStreamPropertyFormatDescription: Property(formatDescription!),
        kCMIOStreamPropertyFormatDescriptions: Property([formatDescription!] as CFArray),
        kCMIOStreamPropertyDirection: Property(UInt32(0)),
        kCMIOStreamPropertyFrameRate: Property(Float64(frameRate)),
        kCMIOStreamPropertyFrameRates: Property(Float64(frameRate)),
        kCMIOStreamPropertyMinimumFrameRate: Property(Float64(frameRate)),
        kCMIOStreamPropertyFrameRateRanges: Property(AudioValueRange(mMinimum: Float64(frameRate), mMaximum: Float64(frameRate))),
        kCMIOStreamPropertyClock: Property(CFTypeRefWrapper(ref: clock!)),
    ]

    func start() {
        ciContext = CIContext(options: nil)
        deviceService = DeviceService()

        configureOutputBuffer()
        cameraService = CameraCaptureService(withCameraView: nil, service: deviceService)
        cameraService?.delegate = self

        DistributedNotificationCenter.default().addObserver(self, selector: #selector(recievedMessage(notification:)), name: NSNotification.Name("HEYOH.CAMERA.DEVICE"), object: nil)
    }

    @objc func recievedMessage(notification: NSNotification) {
        if let deviceId = notification.object as? String {
            userDefaults.setValue(deviceId, forKey: "Heyoh_camera_deviceId")
            userDefaults.synchronize()

            configureOutputBuffer()
            cameraService?.refreshSessionInputDevice()
        }
    }

    func stop() {
        cameraService?.stopSession()
    }

    func copyBufferQueue(queueAlteredProc: CMIODeviceStreamQueueAlteredProc?, queueAlteredRefCon: UnsafeMutableRawPointer?) -> CMSimpleQueue? {
        self.queueAlteredProc = queueAlteredProc
        self.queueAlteredRefCon = queueAlteredRefCon
        return queue
    }

    private func getDeviceVideoSize() -> CMVideoDimensions {
        guard let device = DeviceService.formedDefaultVideoDevice() else {
            return CMVideoDimensions(width: 0, height: 0)
        }
        return CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
    }

    private func configureOutputBuffer() {
        let size = getDeviceVideoSize()
        if size.width != Int32(width) || size.height != Int32(height) || outputBuffer == nil {
            let attrs = [kCVPixelBufferMetalCompatibilityKey: true,
                         kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)

            guard status == kCVReturnSuccess else {
                return
            }

            width = Int(size.width) > 0 ? Int(size.width) : width
            height = Int(size.height) > 0 ? Int(size.height) : height
            outputBuffer = pixelBuffer
        }
    }

    private func enqueueBuffer() {
        guard let queue = queue else {
            log("queue is nil")
            return
        }

        guard CMSimpleQueueGetCount(queue) < CMSimpleQueueGetCapacity(queue) else {
            log("queue is full")
            return
        }

        guard let pixelBuffer = pixelBufferVar else {
            log("pixelBuffer is nil")
            return
        }

        let scale = UInt64(frameRate) * 100
        let duration = CMTime(value: CMTimeValue(scale / UInt64(frameRate)), timescale: CMTimeScale(scale))
        let timestamp = CMTime(value: duration.value * CMTimeValue(sequenceNumber), timescale: CMTimeScale(scale))

        var timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: timestamp,
            decodeTimeStamp: timestamp
        )

        var error = noErr

        error = CMIOStreamClockPostTimingEvent(timestamp, mach_absolute_time(), true, clock)
        guard error == noErr else {
            log("CMSimpleQueueCreate Error: \(error)")
            return
        }

        var formatDescription: CMFormatDescription?
        error = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard error == noErr else {
            log("CMVideoFormatDescriptionCreateForImageBuffer Error: \(error)")
            return
        }

        var sampleBufferUnmanaged: Unmanaged<CMSampleBuffer>?
        error = CMIOSampleBufferCreateForImageBuffer(
            kCFAllocatorDefault,
            pixelBuffer,
            formatDescription,
            &timing,
            sequenceNumber,
            UInt32(kCMIOSampleBufferNoDiscontinuities),
            &sampleBufferUnmanaged
        )
        guard error == noErr else {
            log("CMIOSampleBufferCreateForImageBuffer Error: \(error)")
            return
        }

        CMSimpleQueueEnqueue(queue, element: sampleBufferUnmanaged!.toOpaque())
        queueAlteredProc?(objectID, sampleBufferUnmanaged!.toOpaque(), queueAlteredRefCon)

        sequenceNumber += 1
    }
}

extension Stream: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
        cameraService?.startRenderingProcess(sampleBuffer)
    }
}

extension Stream: CameraCaptureServiceProtocol {
    func displayOutputRenderedFrame(_ image: CIImage) {
        guard let pixelBuffer = outputBuffer else {
            return
        }

        if ciContext == nil {
            ciContext = CIContext(options: nil)
        }

        ciContext.render(image.oriented(.upMirrored), to: pixelBuffer)
        pixelBufferVar = pixelBuffer
        enqueueBuffer()
    }
}
