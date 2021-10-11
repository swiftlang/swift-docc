/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An encodable value which is either a number or a string.
///
/// Using either number or string values allows benchmark reports
/// to be compared without having a predefined list of possible value types.
///
/// For example when comparing two benchmark reports a delta can be produced
/// for any numeric value without the understanding whether a number is a duration
/// in seconds or megabytes.
///
/// Similarly, string values can be checked for equality without understanding
/// what the metric represents.
public enum MetricValue: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
            case .number(let num): try container.encode(num)
            case .integer(let integer): try container.encode(integer)
            case .string(let string): try container.encode(string)
        }
    }
    
    /// A textual metric to produce match/no match deltas.
    case string(String)
    
    /// A number metric which can be used to produce percentage delta changes.
    case number(Double)
    
    /// An integer metric suitable for counters or other non-floating numbers.
    case integer(Int64)
}

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

/// A metric that runs over a period of time and needs
/// to be started and stopped to produce its result.
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
