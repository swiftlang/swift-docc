/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// The results of a single benchmark run.
public struct BenchmarkResults: Codable {
    /// The name of the platform where the benchmark ran.
    public let platformName: String
    
    /// The timestamp for when the benchmark started.
    public let timestamp: Date
    
    /// The arguments that Swift-DocC ran with when gathering benchmark data.
    public let doccArguments: [String]
    
    /// Creates a new benchmark result to gather measurement results into.
    ///
    /// - Parameters:
    ///   - platformName: The name of the platform that the benchmark ran on.
    ///   - timestamp: The timestamp when benchmark started.
    ///   - doccArguments: The arguments that Swift-DocC ran with when gathering benchmark data.
    ///   - unorderedMetrics: A list of unordered metrics for this benchmark.
    public init(
        platformName: String,
        timestamp: Date = Date(),
        doccArguments: [String] = Array(CommandLine.arguments.dropFirst()),
        unorderedMetrics: [Metric]
    ) {
        self.platformName = platformName
        self.timestamp = timestamp
        self.doccArguments = doccArguments
        self.metrics = Self.sortedMetrics(unorderedMetrics)
    }
    
    /// A private convenience method for sorting metrics in a stable order based on their
    fileprivate static func sortedMetrics(_ unorderedMetrics: [Metric]) -> [Metric] {
        // Sort by value type and then by name
        return unorderedMetrics.sorted { (lhs, rhs) in
            if lhs.value.kindSortOrder == rhs.value.kindSortOrder {
                return lhs.displayName < rhs.displayName
            } else {
                return lhs.value.kindSortOrder < rhs.value.kindSortOrder
            }
        }
    }
    
    /// The list of metrics gathered in this benchmark.
    ///
    /// - Note: The metrics are sorted based on presentation priority.
    public var metrics: [Metric]
    
    /// A gathered metric.
    public struct Metric: Codable, Equatable {
        /// The ID for this gathered metric.
        ///
        /// Use the ID to match up metrics across benchmarks to compare results.
        public var id: String
        /// The name that describe this gathered metric. Suitable for presentation.
        public var displayName: String
        /// The gathered value for this metric.
        public var value: Value
        
        /// Creates a new metric to represent gathered measurements.
        /// - Parameters:
        ///   - id: The ID for this gathered metric.
        ///   - displayName: The name that describe this gathered metric.
        ///   - value: The gathered value for this metric.
        public init(id: String, displayName: String, value: BenchmarkResults.Metric.Value) {
            self.id = id
            self.displayName = displayName
            self.value = value
        }
        
        /// The gathered value for a metric.
        public enum Value: Codable, Equatable {
            /// A duration in seconds.
            case duration(Double)
            /// A number of bytes for a memory measurement.
            case bytesInMemory(Int64)
            /// A number of bytes for a storage measurement.
            case bytesOnDisk(Int64)
            /// A checksum.
            case checksum(String)
            
            enum CodingKeys: CodingKey {
                case type, value
            }
            private enum ValueKind: String, Codable {
                case duration, bytesInMemory, bytesOnDisk, checksum
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                switch try container.decode(ValueKind.self, forKey: .type) {
                    case .bytesInMemory:
                        self = try .bytesInMemory(container.decode(Int64.self, forKey: .value))
                    case .bytesOnDisk:
                        self = try .bytesOnDisk(container.decode(Int64.self, forKey: .value))
                    case .duration:
                        self = try .duration(container.decode(Double.self, forKey: .value))
                    case .checksum:
                        self = try .checksum(container.decode(String.self, forKey: .value))
                }
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                switch self {
                    case .bytesInMemory(let value):
                        try container.encode(ValueKind.bytesInMemory, forKey: .type)
                        try container.encode(value, forKey: .value)
                    case .bytesOnDisk(let value):
                        try container.encode(ValueKind.bytesOnDisk, forKey: .type)
                        try container.encode(value, forKey: .value)
                    case .duration(let value):
                        try container.encode(ValueKind.duration, forKey: .type)
                        try container.encode(value, forKey: .value)
                    case .checksum(let value):
                        try container.encode(ValueKind.checksum, forKey: .type)
                        try container.encode(value, forKey: .value)
                }
            }
        }
    }
}

// MARK: Legacy format

extension BenchmarkResults {
    private enum LegacyCodingKeys: String, CodingKey {
        case platform, date, arguments, metrics
    }
    
    private enum LegacyMetricCodingKeys: String, CodingKey {
        case identifier, displayName, result
    }
    
    public enum CodingKeys: CodingKey {
        case platformName, timestamp, doccArguments, metrics
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if container.contains(.platformName) {
            self.platformName = try container.decode(String.self, forKey: .platformName)
            self.timestamp = try container.decode(Date.self, forKey: .timestamp)
            self.doccArguments = try container.decode([String].self, forKey: .doccArguments)
            self.metrics = try container.decode([Metric].self, forKey: .metrics)
        } else {
            // Legacy format
            let container = try decoder.container(keyedBy: LegacyCodingKeys.self)
            
            self.platformName = try container.decode(String.self, forKey: .platform)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            guard let date = try dateFormatter.date(from: container.decode(String.self, forKey: .date)) else {
                throw DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "Unable to decode benchmark Date value from legacy benchmark.json format.")
            }
                    
            self.timestamp = date
            self.doccArguments = try container.decode([String].self, forKey: .arguments)
            
            var metricsContainer = try container.nestedUnkeyedContainer(forKey: .metrics)
            var unsortedMetrics: [Metric] = []
            if let containerCount = metricsContainer.count {
                unsortedMetrics.reserveCapacity(containerCount)
            }
            while !metricsContainer.isAtEnd {
                let metricContainer = try metricsContainer.nestedContainer(keyedBy: LegacyMetricCodingKeys.self)
                let id = try metricContainer.decode(String.self, forKey: .identifier)
                let name = try metricContainer.decode(String.self, forKey: .displayName)
                
                if name.hasSuffix(" (msec)") {
                    let value = try metricContainer.decode(Double.self, forKey: .result)
                    unsortedMetrics.append(.init(id: id, displayName: String(name.dropLast(7)), value: .duration(value / 1000.0)))
                    continue
                } else if name.hasSuffix("memory footprint (bytes)") {
                    let value = try metricContainer.decode(Int64.self, forKey: .result)
                    unsortedMetrics.append(.init(id: id, displayName: String(name.dropLast(8)), value: .bytesInMemory(value)))
                    continue
                } else if name.hasSuffix(" (bytes)") {
                    let value = try metricContainer.decode(Int64.self, forKey: .result)
                    unsortedMetrics.append(.init(id: id, displayName: String(name.dropLast(8)), value: .bytesOnDisk(value)))
                    continue
                } else {
                    let value = try metricContainer.decode(String.self, forKey: .result)
                    unsortedMetrics.append(.init(id: id, displayName: name, value: .checksum(value)))
                    continue
                }
            }
            
            self.metrics = Self.sortedMetrics(unsortedMetrics)
        }
    }
}

private extension BenchmarkResults.Metric.Value {
    var kindSortOrder: Int {
        switch self {
            case .duration:
                return 0
            case .bytesInMemory:
                return 1
            case .bytesOnDisk:
                return 2
            case .checksum:
                return 3
        }
    }
}

