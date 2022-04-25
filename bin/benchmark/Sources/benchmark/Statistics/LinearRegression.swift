/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Collection where Element == Double {
    /// Analyses the metric series' values for signs of bias in the data.
    ///
    /// - Note: This is not a scientific measurement.
    /// Use this to highlight values that a human might want to double check to ensure the validity of other automated analysis.
    ///
    /// - Returns: `false` if the values show signs of a linear trend.
    func looksReasonablyNonBiased() -> Bool {
        // As a crude way of detecting if a series of values shows bias, we compute the linear curve `y = const + x * slope`
        //
        //    △
        //    │
        //    | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀o⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        //    | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        //    | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀o⣀⣀⣀⣀⣀⡠⠤
        //    | ⣀⣀⣀⣀⣀⣀⠤o⠤⠤⠤⠤⠤⠒⠒⠒⠒⠒⠒⠒⠉⠉⠉⠉⠉⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀
        //    | o⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        //    | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀o⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        //    | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        //    | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        //    ┼──────────────────────────────────────────▷
        //
        // Then compute the slope of the `max` and `min` values
        //
        //    △
        //    │ ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀╭⠀──⠀──⠀──⠀──⠀─╮⠀⠀⠀⠀⠀⠀⠀
        //    | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀x⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀▼⠀⠀⢀⣀⠤⠤
        //    | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀o⠒⠉⠀⠀⠀⠀
        //    | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⠤⠤⠒⠊⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀
        //    | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⡠⠤⠒⠒⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        //    | ⠀⠀⠀⠀⠀⠀⣀⡠⠤⠔⠒⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        //    | o⠤⠔⠒⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀x⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        //    | ▲⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        //    | ╰⠀─⠀─⠀─⠀─⠀─⠀─⠀─⠀─⠀─⠀─⠀╯⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        //    ┼─────────────────────────────────────────▷
        //
        // If the linear regression slope is at least half the magnitude of the min-max slope, then we signal that the metric
        // series shows some signs of having linear bias in its data.
        //
        // We only care about linear bias because it could be an indication that the measurements are impacted by thermal throttling.
        
        let (_, slope) = fitSimpleLinearRegression(Array(self))
        
        let (_, minMaxSlope) = fitSimpleLinearRegression([
            (x: 0.0, y: self.min()!),
            (x: Double(self.count), y: self.max()!)
        ])
        
        if (self.max()! - self.min()!) < self.mean().ulp {
            // The range of the samples is smaller than the precision of the mean value. A series of values like that looks reasonably non-biased.
            return true
        }
        
        return slope.magnitude < (minMaxSlope.magnitude * 0.5)
    }
    
    func mean() -> Double {
        precondition(!isEmpty, "Can't calculate the mean/average of an empty collection. Benchmark values should never be empty.")
        return reduce(0.0, +) / Double(count)
    }
    
    func standardDeviation(degreesOfFreedom: Int) -> Double {
        let mean = self.mean()
        let v = self.reduce(0, { $0 + ($1-mean)*($1-mean) })
        return (v / Double(self.count - degreesOfFreedom)).squareRoot()
    }
}

/// Performs a "simple linear regression" to fit a series of y-values (where x is the index of each value) to a line described by `y = constant + slope * x`
///
/// - Parameter values: The values to fit to line.
/// - Returns: The constant and slope for the line that best fit this series of values.
func fitSimpleLinearRegression(_ values: [Double]) -> (constant: Double, slope: Double) {
    return fitSimpleLinearRegression(zip(1..., values).map { (x: Double($0.0), $0.1) })
}

/// Performs a "simple linear regression" to fit a series of (x, y) points to a line described by `y = constant + slope * x`
///
/// - Parameter points: The points to fit to line.
/// - Returns: The constant and slope for the line that best fit this series of points.
func fitSimpleLinearRegression(_ points: [(x: Double, y: Double)]) -> (constant: Double, slope: Double) {
    let n = Double(points.count)
        
    var sumX = 0.0
    var sumY = 0.0
    var sumXsquare = 0.0
    var sumYsquare = 0.0
    var sumXY = 0.0
    
    for (x, y) in points {
        sumX += x
        sumY += y
        sumXsquare += x*x
        sumYsquare += y*y
        sumXY += x*y
    }
    
    let slope = (n * sumXY - sumX * sumY) / (n * sumXsquare - sumX * sumX)
    let constant = (1.0/n) * (sumY - slope * sumX)
    
    return (constant, slope)
}
