//
//  DetectionStruct.swift
//  Heyoh
//
//  Created by Oleg Sehelin on 28.09.2021.
//

import Cocoa
import Foundation
import Vision

public enum DetectionType: Int {
    case normalFace, smile, thumbUp, thumbDown, hand, none
}

public enum SideType: Int {
    case left, right
}

struct DetectionStruct {
    let classType: DetectionType
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let offsetX: Double
    let offsetY: Double
    let sidePrediction: SideType

    init(withMatrix matrix: MLMultiArray, columnNumber: NSNumber) {
        classType = DetectionType(rawValue: matrix[[columnNumber, 0]].intValue) ?? .none
        y = matrix[[columnNumber, 1]].doubleValue
        x = matrix[[columnNumber, 2]].doubleValue
        offsetY = matrix[[columnNumber, 3]].doubleValue
        offsetX = matrix[[columnNumber, 4]].doubleValue
        sidePrediction = SideType(rawValue: matrix[[columnNumber, 5]].doubleValue > 0 ? 1 : 0) ?? .left
        width = 0
        height = 0
    }

    init(coords: MLMultiArray,
         sizeWidth: MLMultiArray,
         sizeHeight: MLMultiArray,
         side: MLMultiArray,
         rowNumber: NSNumber,
         sizeNorm: Double = 128, outputStride: Double = 2)
    {
        classType = DetectionType(rawValue: coords[[rowNumber, 0]].intValue) ?? .none
        y = coords[[rowNumber, 1]].doubleValue * outputStride
        x = coords[[rowNumber, 2]].doubleValue * outputStride
        offsetY = 0
        offsetX = 0
        width = sizeWidth[[rowNumber]].doubleValue * sizeNorm
        height = sizeHeight[[rowNumber]].doubleValue * sizeNorm
        sidePrediction = side[[rowNumber]].doubleValue > 0.5 ? .left : .right
    }

    init(classType: DetectionType, sidePrediction: SideType, x: Double, y: Double, width: Double, height: Double) {
        self.classType = classType
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        offsetX = 0
        offsetY = 0
        self.sidePrediction = sidePrediction
    }
}

struct OutputStruct {
    let image: CIImage
    let frame: NSRect
    let sizeMultiplier: CGFloat
}
