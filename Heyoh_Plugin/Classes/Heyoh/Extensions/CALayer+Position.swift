//
//  CALayer+Position.swift
//  Heyoh
//
//  Created by Oleg Sehelin on 29.09.2021.
//

import Cocoa
import Foundation

extension CALayer {
    func bringToFront() {
        guard let sLayer = superlayer else {
            return
        }
        removeFromSuperlayer()
        sLayer.insertSublayer(self, at: UInt32(sLayer.sublayers?.count ?? 0))
    }

    func sendToBack() {
        guard let sLayer = superlayer else {
            return
        }
        removeFromSuperlayer()
        sLayer.insertSublayer(self, at: 0)
    }
}
