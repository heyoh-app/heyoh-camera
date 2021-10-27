//
//  AppDelegate.swift
//  Laucnher
//
//  Created by Markiyan Kostiv on 12.09.2021.
//  Copyright © 2021 com.heyoh. All rights reserved.
//

import Cocoa

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}


class AutoLauncherAppDelegate: NSObject, NSApplicationDelegate {
    
    struct Constants {
        // Bundle Identifier of MainApplication target
        static let mainAppBundleID = "com.heyoh.camera"
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains {
            $0.bundleIdentifier == Constants.mainAppBundleID
        }

        if !isRunning {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.heyoh.camera") else {
                return
            }
            
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(self.terminate), name: .killLauncher, object: nil)


            let path = "/bin"
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = [path]
            NSWorkspace.shared.openApplication(at: url,
                                               configuration: configuration,
                                               completionHandler: nil)
        } else {
            self.terminate()
        }
        
    }
    
    @objc func terminate() {
        NSApp.terminate(nil)
    }

    
}
