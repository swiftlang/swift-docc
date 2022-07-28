/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// The results of a series of benchmark runs.
struct BenchmarkResultSeries: Codable, Equatable {
    /// The name of the platform where the benchmark ran.
    public var platformName: String
    
    /// The timestamp for when the benchmark started.
    public var timestamp: Date
    
    /// The arguments that Swift-DocC ran with when gathering benchmark data.
    public var doccArguments: [String]
    
    /// A series of gathered metrics.
    public struct MetricSeries: Codable, Equatable {
        /// The ID for this gathered metric.
        ///
        /// Use the ID to match up metrics across benchmarks to compare results.
        public var id: String
        /// The name that describe this gathered metric. Suitable for presentation.
        public var displayName: String
        /// The gathered value for this metric.
        public var values: ValueSeries
        
        /// The gathered value for a metric series.
        public enum ValueSeries: Codable, Equatable {
            /// A duration in seconds.
            case duration([Double])
            /// A number of bytes for a memory measurement.
            case bytesInMemory([Int64])
            /// A number of bytes for a storage measurement.
            case bytesOnDisk([Int64])
            /// A checksum.
            case checksum([String])
            
            init(_ value: BenchmarkResults.Metric.Value) {
                switch value {
                    case .duration(let value):
                        self = .duration([value])
                    case .bytesInMemory(let value):
                        self = .bytesInMemory([value])
                    case .bytesOnDisk(let value):
                        self = .bytesOnDisk([value])
                    case .checksum(let value):
                        self = .checksum([value])
                }
            }
            
            mutating func append(_ value: BenchmarkResults.Metric.Value) throws {
                switch (self, value) {
                    case (.duration(let values), .duration(let value)):
                        self = .duration(values + [value])
                    case (.bytesInMemory(let values), .bytesInMemory(let value)):
                        self = .bytesInMemory(values + [value])
                    case (.bytesOnDisk(let values), .bytesOnDisk(let value)):
                        self = .bytesOnDisk(values + [value])
                    case (.checksum(let values), .checksum(let value)):
                        self = .checksum(values + [value])
                    default:
                        throw Error.addedResultHasDifferentConfiguration
                }
            }
        }
    }
    
    /// The list of metrics gathered in these benchmark runs.
    public var metrics: [MetricSeries]
    
    static var empty = BenchmarkResultSeries(platformName: "", timestamp: Date(), doccArguments: [], metrics: [])
    
    enum Error: Swift.Error, CustomStringConvertible {
        case addedResultHasDifferentConfiguration
        case typeMismatchAccumulatingValues
        
        var description: String {
            switch self {
                case .addedResultHasDifferentConfiguration:
                    return "Unable to collect results for different platforms or different docc arguments."
                case .typeMismatchAccumulatingValues:
                    return "Type mismatch when accumulating benchmark values"
            }
        }
    }
    
    mutating func add(_ results: BenchmarkResults) throws {
        if doccArguments.isEmpty {
            // First result
            timestamp = results.timestamp
            platformName = results.platformName
            doccArguments = results.doccArguments
            metrics = results.metrics.map {
                .init(id: $0.id, displayName: $0.displayName, values: .init($0.value))
            }
            return
        }
        
        guard platformName == results.platformName,
              doccArguments == results.doccArguments,
              metrics.count == results.metrics.count else {
            throw Error.addedResultHasDifferentConfiguration
        }
        
        for i in metrics.indices {
            try metrics[i].values.append(results.metrics[i].value)
        }
    }
}

// MARK: Codable

extension BenchmarkResultSeries.MetricSeries.ValueSeries {
    enum CodingKeys: CodingKey {
        case type, values
    }
    private enum ValueKind: String, Codable {
        case duration, bytesInMemory, bytesOnDisk, checksum
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        switch try container.decode(ValueKind.self, forKey: .type) {
            case .bytesInMemory:
                self = try .bytesInMemory(container.decode([Int64].self, forKey: .values))
            case .bytesOnDisk:
                self = try .bytesOnDisk(container.decode([Int64].self, forKey: .values))
            case .duration:
                self = try .duration(container.decode([Double].self, forKey: .values))
            case .checksum:
                self = try .checksum(container.decode([String].self, forKey: .values))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
            case .bytesInMemory(let value):
                try container.encode(ValueKind.bytesInMemory, forKey: .type)
                try container.encode(value, forKey: .values)
            case .bytesOnDisk(let value):
                try container.encode(ValueKind.bytesOnDisk, forKey: .type)
                try container.encode(value, forKey: .values)
            case .duration(let value):
                try container.encode(ValueKind.duration, forKey: .type)
                try container.encode(value, forKey: .values)
            case .checksum(let value):
                try container.encode(ValueKind.checksum, forKey: .type)
                try container.encode(value, forKey: .values)
        }
    }
}
