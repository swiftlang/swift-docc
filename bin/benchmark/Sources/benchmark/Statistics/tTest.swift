/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

struct TTestResult {
    var seriesAreProbablyTheSame: Bool {
        return nullHypothesisIsAccepted
    }
    fileprivate let nullHypothesisIsAccepted: Bool
    
    let tStatistic: Double
    let criticalValue: Double
    let degreesOfFreedom: Int
}

/// Performs a Student's t-test for two unpaired samples.
///
/// - Note: This assumes that both samples follow a normal distribution and that the two samples are "unpaired".
///
/// - Returns: The conclusion of the t-test within a 95% confidence interval.
func independentTTest(_ lhs: [Double], _ rhs: [Double]) -> TTestResult {
    let mean1 = lhs.mean()
    let mean2 = rhs.mean()
    
    let std1 = lhs.standardDeviation(degreesOfFreedom: 1)
    let std2 = rhs.standardDeviation(degreesOfFreedom: 1)
    
    let standardError1 = std1 / Double(lhs.count).squareRoot()
    let standardError2 = std2 / Double(rhs.count).squareRoot()
    
    let standardErrorOnDifference = (standardError1*standardError1 + standardError2*standardError2).squareRoot()
    let tStatistic = (mean1 - mean2) / standardErrorOnDifference
    
    let degreesOfFreedom = lhs.count + rhs.count - 2

    // For a fixed significant / confidence we look up the critical value in a table.
    guard degreesOfFreedom < 30, degreesOfFreedom > 0 else {
        fatalError("Larger samples size than size of t-distribution table.")
    }
    let criticalValue = twoSidedTDistributionFor95PercentConfidence[degreesOfFreedom + 1]
    
    let nullHypothesisIsAccepted = tStatistic.magnitude <= criticalValue
    
    return TTestResult(
        nullHypothesisIsAccepted: nullHypothesisIsAccepted,
        tStatistic: tStatistic,
        criticalValue: criticalValue,
        degreesOfFreedom: degreesOfFreedom
    )
}

// For our use case we don't need to dynamically create any p-value for any confidence interval and any number of degrees of freedom.
//
// Instead we only use a 95% confidence interval and hardcode a table of known p-values for the first 30 degrees of freedom, which is
// sufficient for two series of 16 benchmark runs each.
//
// Tables of t-distributions can be found in statistic text books.
// These values are from https://en.wikipedia.org/wiki/Student%27s_t-distribution
private let twoSidedTDistributionFor95PercentConfidence: [Double] = [
    12.710, // 1 degree of freedom
    4.303,
    3.182,
    2.776,
    2.571, // 5 degrees of freedom
    2.447,
    2.365,
    2.306,
    2.262,
    2.228, // 10 degrees of freedom
    2.201,
    2.179,
    2.160,
    2.145,
    2.131, // 15 degrees of freedom
    2.120,
    2.110,
    2.101,
    2.093,
    2.086, // 20 degrees of freedom
    2.080,
    2.074,
    2.069,
    2.064,
    2.060, // 25 degrees of freedom
    2.056,
    2.052,
    2.048,
    2.045,
    2.042, // 30 degrees of freedom
]

