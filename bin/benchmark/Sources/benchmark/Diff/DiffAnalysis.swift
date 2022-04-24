/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension DiffResults {
    enum Error: Swift.Error, CustomStringConvertible {
        case typeMismatchComparingBenchmarkValues(id: String)
        
        var description: String {
            switch self {
                case .typeMismatchComparingBenchmarkValues(let id):
                    return "Type mismatch when comparing benchmark values for metric with ID \(id)"
            }
        }
    }
    
    static func analyze(before beforeMetric: BenchmarkResultSeries.MetricSeries?, after afterMetric: BenchmarkResultSeries.MetricSeries) throws -> DiffResults.MetricAnalysis {
        guard let beforeMetric = beforeMetric else {
            return DiffResults.MetricAnalysis(
                metricName: afterMetric.displayName,
                metricID: afterMetric.id,
                change: .notApplicable,
                before: nil,
                after: afterMetric.values.formatted()
            )
        }
        
        let delta: MetricAnalysis.Change
        
        switch (beforeMetric.values, afterMetric.values) {
            case (.duration(let beforeValues), .duration(let afterValues)):
                let beforeNumber = beforeValues.map { Double($0) }.mean()
                let afterNumber = afterValues.map { Double($0) }.mean()
                
                let change = (1 - Double(afterNumber) / Double(beforeNumber)) * 100.0
                if abs(change) < 0.009 {
                    delta = .same
                } else {
                    delta = .differentNumeric(percentage: change)
                }
                
            case (.bytesInMemory(let beforeValues), .bytesInMemory(let afterValues)):
                let beforeNumber = beforeValues.map { Double($0) }.mean()
                let afterNumber = afterValues.map { Double($0) }.mean()
                
                let change = (1 - Double(afterNumber) / Double(beforeNumber)) * 100.0
                if abs(change) < 0.009 {
                    delta = .same
                } else {
                    delta = .differentNumeric(percentage: change)
                }
                
            case (.bytesOnDisk(let beforeValues), .bytesOnDisk(let afterValues)):
                let beforeNumber = beforeValues.map { Double($0) }.mean()
                let afterNumber = afterValues.map { Double($0) }.mean()
                
                let change = (1 - Double(afterNumber) / Double(beforeNumber)) * 100.0
                if abs(change) < 0.009 {
                    delta = .same
                } else {
                    delta = .differentNumeric(percentage: change)
                }
                
            case (.checksum(let beforeValues), .checksum(let afterValues)):
                delta = beforeValues[0] == afterValues[0] ? .same : .differentChecksum
                
            default:
                throw DiffResults.Error.typeMismatchComparingBenchmarkValues(id: afterMetric.id)
        }
        
        return DiffResults.MetricAnalysis(
            metricName: afterMetric.displayName,
            metricID: afterMetric.id,
            change: delta,
            before: beforeMetric.values.formatted(),
            after: afterMetric.values.formatted()
        )
    }
}

extension BenchmarkResultSeries.MetricSeries.ValueSeries {
    func formatted() -> String {
        switch self {
            case .duration(let value):
                let average = value.mean()
                return durationFormatter.string(from: Measurement(value: average, unit: UnitDuration.seconds))
                
            case .bytesInMemory(let value):
                let average = value.map { Double($0) }.mean().rounded()
                return ByteCountFormatter.string(fromByteCount: Int64(average), countStyle: .memory)
                
            case .bytesOnDisk(let value):
                let average = value.map { Double($0) }.mean().rounded()
                return ByteCountFormatter.string(fromByteCount: Int64(average), countStyle: .file)
                
            case .checksum(let value):
                return value[0]
        }
    }
}

private let durationFormatter: MeasurementFormatter = {
    let fmt = MeasurementFormatter()
    fmt.unitStyle = .medium
    return fmt
}()

private extension Collection where Element == Double {
    func mean() -> Double {
        precondition(!isEmpty, "Can't calculate the mean/average of an empty collection. Benchmark values should never be empty.")
        return reduce(0.0, +) / Double(count)
    }
}
