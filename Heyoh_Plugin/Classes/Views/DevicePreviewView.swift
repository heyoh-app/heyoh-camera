//
//  DevicePreviewView.swift
//  Heyoh
//
//  Created by Oleg Sehelin on 27.09.2021.
//

import AVFoundation
import Cocoa
import Foundation

class DevicePreviewView: NSView, LoadableView {
    var mainView: NSView?
    fileprivate var cameraService: CameraCaptureService?
    @IBOutlet var camera: NSView!

    init() {
        super.init(frame: NSRect.zero)

        if load(fromNIBNamed: "DevicePreviewView") {}
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func startVideo(_ service: DeviceService?) {
        if camera != nil {
            camera.wantsLayer = true
            camera.layer?.contentsGravity = .resizeAspectFill
            cameraService = CameraCaptureService(withCameraView: camera, service: service)
        }
    }

    func stopVideo() {
        cameraService?.stopSession()
    }
}
