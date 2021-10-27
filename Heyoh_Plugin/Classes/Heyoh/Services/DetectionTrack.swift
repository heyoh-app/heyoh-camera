//
//  DetectionTrack.swift
//  Heyoh
//
//  Created by Markiyan Kostiv on 27.09.2021.
//

import Foundation

class DetectionTrack {
    let side: SideType
    let maxPropagateCount: Int
    let minNumPredictions: Int

    var history: [(CGRect, DetectionType)]
    var propagateCount: Int

    let xFilter = OneEuroFilter(freq: 120, mincutoff: 0.9, beta: 0.05, dcutoff: 1.0)
    let yFilter = OneEuroFilter(freq: 120, mincutoff: 0.9, beta: 0.05, dcutoff: 1.0)
    let widthFilter = OneEuroFilter(freq: 120, mincutoff: 0.3, beta: 0.005, dcutoff: 1.0)
    let heightFilter = OneEuroFilter(freq: 120, mincutoff: 0.3, beta: 0.005, dcutoff: 1.0)

    init(side: SideType, maxPropagateCount: Int = 5, minNumPredictions: Int = 10) {
        self.side = side
        history = []
        propagateCount = 0
        self.maxPropagateCount = maxPropagateCount
        self.minNumPredictions = minNumPredictions
    }

    func getCoordinates(prediction: (rect: CGRect, detectionType: DetectionType)?) -> (rect: CGRect, detectionType: DetectionType)? {
        guard let prediction = prediction else {
            if history.count < minNumPredictions {
                resetHistory()
                return nil
            }
            return propagete()
        }

        // Reset history when the gesture changes
        if let detectionType = history.last?.1, detectionType != prediction.detectionType {
            resetHistory()
            return nil
        }

        var rect = prediction.rect
        let x = xFilter.filter(Double(rect.origin.x))
        let y = yFilter.filter(Double(rect.origin.y))
        let width = widthFilter.filter(Double(rect.width))
        let height = heightFilter.filter(Double(rect.height))
        rect = CGRect(x: x, y: y, width: width, height: height)

        history.append((rect, prediction.detectionType))
        propagateCount = 0

        if history.count < minNumPredictions {
            return nil
        }

        return history.last
    }

    private func propagete() -> (CGRect, DetectionType)? {
        guard propagateCount <= maxPropagateCount else {
            resetHistory()
            return nil
        }

        guard let prediction = history.last else {
            return nil
        }
        propagateCount += 1
        return prediction
    }

    private func resetHistory() {
        history.removeAll()
        propagateCount = 0
    }
}
