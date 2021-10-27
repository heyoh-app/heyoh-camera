//
//  AppDelegate.swift
//  Heyoh
//
//  Created by Oleg Sehelin on 28.09.2021.
//

import Cocoa
import ServiceManagement

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var previewView: DevicePreviewView?
    
    fileprivate var deviceService: DeviceService?
    
    @IBOutlet weak var menu: NSMenu?
    @IBOutlet weak var devicesMenuItem: NSMenuItem?
    @IBOutlet weak var videoMenuItem: NSMenuItem?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        SMLoginItemSetEnabled("com.heyoh.camera.launcher" as CFString,
                              true)
        
        DistributedNotificationCenter.default().postNotificationName(.killLauncher, object: nil, userInfo: nil, deliverImmediately: true)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
     
        deviceService = DeviceService()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let itemImage = NSImage(named: "Heyoh_toolbar")
        itemImage?.isTemplate = true
        statusItem?.button?.image = itemImage
        
        if let menu = menu {
            menu.delegate = self
            statusItem?.menu = menu
        }
        
        if let item = videoMenuItem {
            previewView = DevicePreviewView()
            previewView?.frame = NSRect(x: 0.0, y: 0.0, width: 604.0, height: 340.0)
            item.view = previewView
        }
        
        if let cameras = devicesMenuItem, let list = deviceService?.getDevicesList() {
            let devicesMenu = NSMenu()
            for device in list {
                let item = DeviceMenuItem(title: device.localizedName, action: #selector(deviceMenuPressed(_:)), keyEquivalent: "")
                item.deviceId = device.uniqueID
                devicesMenu.addItem(item)
            }
            cameras.submenu = devicesMenu
        }
    }
    
    fileprivate func refreshSelectedDeviceCheckmark() {
        if  let currentDevice = DeviceService.formedDefaultVideoDevice(), let cameras = devicesMenuItem, let menu = cameras.submenu?.items as? [DeviceMenuItem] {
            for item in menu {
                item.state = currentDevice.uniqueID == item.deviceId ? .on : .off
            }
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        refreshSelectedDeviceCheckmark()
        previewView?.startVideo(deviceService)
    }
    
    func menuDidClose(_ menu: NSMenu) {
        previewView?.stopVideo()
    }
    
    @objc fileprivate func deviceMenuPressed(_ item: DeviceMenuItem) {
        deviceService?.updateCaptureDevice(item.deviceId)
    }
 }
