import Foundation

public class OneEuroFilter {
    var frequency: Double
    var minCutOff: Double
    var beta: Double
    var dCutOff: Double

    var x: LowPassFilter
    var dx: LowPassFilter

    var lastTime: Double

    var currValue: Double

    init(freq: Double, mincutoff: Double = 1.0, beta: Double = 0.0, dcutoff: Double = 1.0) {
        lastTime = -1.0
        currValue = 0.0
        frequency = freq
        minCutOff = mincutoff
        self.beta = beta
        dCutOff = dcutoff

        x = LowPassFilter(alpha: OneEuroFilter.alpha(cutoff: mincutoff, frequency: freq))
        dx = LowPassFilter(alpha: OneEuroFilter.alpha(cutoff: dcutoff, frequency: freq))
    }

    class func alpha(cutoff: Double, frequency: Double) -> Double {
        let te = 1.0 / frequency
        let tau = 1.0 / (2.0 * .pi * cutoff)
        return 1.0 / (1.0 + tau / te)
    }

    func alpha(_ cutoff: Double) -> Double {
        let te: Double = 1.0 / frequency
        let tau: Double = 1.0 / (2.0 * .pi * cutoff)
        return 1.0 / (1.0 + tau / te)
    }

    public func filter(_ value: Double, timestamp: Double = -1.0) -> Double {
        if lastTime != -1.0, timestamp != -1.0 {
            frequency = 1.0 / (timestamp - lastTime)
        }
        lastTime = timestamp
        let dValue = x.initialized ? (value - x.lastRawValue) * frequency : 0.0
        let edValue = dx.filterWithAlpha(value: dValue, alpha: alpha(dCutOff))
        let cutoff = minCutOff + beta * abs(edValue)
        currValue = x.filterWithAlpha(value: value, alpha: alpha(cutoff))

        return currValue
    }
}
