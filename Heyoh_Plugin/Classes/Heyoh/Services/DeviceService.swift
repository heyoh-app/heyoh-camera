//
//  DeviceService.swift
//  Heyoh
//
//  Created by Oleg Sehelin on 27.09.2021.
//

import AVFoundation
import Cocoa
import Foundation

extension UserDefaults {
    @objc dynamic var selectedDeviceId: String? {
        return string(forKey: "selectedDeviceId")
    }
}

class DeviceMenuItem: NSMenuItem {
    var deviceId: String = ""
}

let userDefaults = UserDefaults(suiteName: "com.heyoh.camera.defaults")!

class DeviceService: NSObject {
    fileprivate var listOfDevices = [AVCaptureDevice]()

    func getDevicesList() -> [AVCaptureDevice] {
        if listOfDevices.count == 0 {
            listOfDevices = DeviceService.allVideoDevices()
        }

        return listOfDevices
    }

    func updateCaptureDevice(_ deviceId: String) {
        userDefaults.setValue(deviceId, forKey: "Heyoh_camera_deviceId")
        userDefaults.synchronize()

        let center = DistributedNotificationCenter.default()
        center.postNotificationName(NSNotification.Name("HEYOH.CAMERA.DEVICE"), object: deviceId, userInfo: nil, deliverImmediately: true)
    }

    class func allVideoDevices() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.externalUnknown, .builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        var result = [AVCaptureDevice]()
        for device in discoverySession.devices {
            if !device.localizedName.contains("Heyoh") {
                result.append(device)
            }
        }

        return result
    }

    class func formedDefaultVideoDevice() -> AVCaptureDevice? {
        let deviceKey = "Heyoh_camera_deviceId"
        if let modelId = userDefaults.string(forKey: deviceKey), let device = DeviceService.allVideoDevices().filter({ $0.uniqueID == modelId }).first {
            return device
        }

        return AVCaptureDevice.default(for: AVMediaType.video)
    }
}
