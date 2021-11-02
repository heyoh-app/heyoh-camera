// https://github.com/fritzlabs/fritz-ai-ios-sdk/blob/master/Source/FritzVision/PoseEstimation/Smoothing/OneEuroFilter.swift
import Foundation

class LowPassFilter {
    var lastRawValue: Double
    var smoothedResult: Double
    var alpha: Double
    var initialized = false

    init(alpha: Double, y: Double = 0, s: Double = 0) {
        lastRawValue = y
        smoothedResult = s
        self.alpha = alpha
    }

    func filter(value: Double) -> Double {
        // Don't update filter if the last value was a NaN
        if value.isNaN {
            return value
        }

        var result: Double!
        if !initialized {
            initialized = true
            result = value
        } else {
            result = alpha * value + (1.0 - alpha) * smoothedResult
        }

        lastRawValue = value
        smoothedResult = result
        return result
    }

    func filterWithAlpha(value: Double, alpha: Double) -> Double {
        self.alpha = alpha
        return filter(value: value)
    }
}
