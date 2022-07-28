/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

///A metric value which is either a duration, a number of bytes, or a checksum.
public typealias MetricValue = BenchmarkResults.Metric.Value

/// A generic, named metric.
public protocol BenchmarkMetric {
    /// A textual identifier for the metric.
    static var identifier: String { get }
    /// A human-friendly display name for the metric.
    static var displayName: String { get }
    /// The result of the metric.
    var result: MetricValue? { get }
}

/// A metric which could dynamically provide a custom id and name.
public protocol DynamicallyIdentifiableMetric: BenchmarkMetric {
    var identifier: String { get }
    var displayName: String { get }
}

/// A metric that runs over a period of time and needs to be started and stopped to produce its result.
public protocol BenchmarkBlockMetric: BenchmarkMetric {
    func begin() -> Void
    func end() -> Void
}

/// A metric result which can be encoded.
public struct BenchmarkResult: Encodable {
    public var identifier: String
    public var displayName: String
    public var result: MetricValue?
}
