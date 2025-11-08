#if os(iOS)
import Foundation

enum MeasurementDisplay {
    private static let feetPerMeter = 3.280839895
    private static let feetPerMile = 5280.0

    static func accuracy(_ meters: Double, useMetric: Bool) -> String {
        if useMetric {
            if meters < 100 {
                return String(format: "%.1f m", meters)
            } else {
                return String(format: "%.0f m", meters)
            }
        } else {
            let feet = meters * feetPerMeter
            if feet < feetPerMile {
                return String(format: "%.0f ft", feet)
            } else {
                let miles = feet / feetPerMile
                return String(format: "%.2f mi", miles)
            }
        }
    }

    static func distance(_ meters: Double, useMetric: Bool) -> String {
        if useMetric {
            if meters < 1000 {
                return String(format: "%.1f m", meters)
            } else {
                return String(format: "%.2f km", meters / 1000)
            }
        } else {
            let feet = meters * feetPerMeter
            if feet < feetPerMile {
                return String(format: "%.0f ft", feet)
            } else {
                let miles = feet / feetPerMile
                return String(format: "%.2f mi", miles)
            }
        }
    }
}
#endif
