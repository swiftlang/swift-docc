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
        
        let beforeNumbers: [Double]
        let afterNumbers: [Double]
        
        switch (beforeMetric.values, afterMetric.values) {
            case (.duration(let beforeValues), .duration(let afterValues)):
                beforeNumbers = beforeValues
                afterNumbers = afterValues
                
            case (.bytesInMemory(let beforeValues), .bytesInMemory(let afterValues)),
                 (.bytesOnDisk(let beforeValues), .bytesOnDisk(let afterValues)):
                beforeNumbers = beforeValues.map { Double($0) }
                afterNumbers = afterValues.map { Double($0) }
                
                if Set(beforeValues).count == 1, beforeValues == afterValues {
                    return MetricAnalysis(
                        metricName: afterMetric.displayName,
                        metricID: afterMetric.id,
                        change: .same,
                        before: beforeMetric.values.formatted(),
                        after: afterMetric.values.formatted()
                    )
                }
                
            case (.checksum(let beforeValues), .checksum(let afterValues)):
                return MetricAnalysis(
                    metricName: afterMetric.displayName,
                    metricID: afterMetric.id,
                    change: beforeValues[0] == afterValues[0] ? .same : .differentChecksum,
                    before: beforeMetric.values.formatted(),
                    after: afterMetric.values.formatted()
                )
                
            default:
                throw Error.typeMismatchComparingBenchmarkValues(id: afterMetric.id)
        }
        
        var warnings: [String] = []
        if !beforeNumbers.looksReasonablyNonBiased() {
            warnings.append(Self.inputBiasDescription(metricID: beforeMetric.id, sampleName: "before", numbers: beforeNumbers))
        }
        if !afterNumbers.looksReasonablyNonBiased() {
            warnings.append(Self.inputBiasDescription(metricID: afterMetric.id, sampleName: "after", numbers: afterNumbers))
        }
                
        let change: MetricAnalysis.Change
        let footnotes: [MetricAnalysis.Footnote]
        
        let tTestResult = independentTTest(beforeNumbers, afterNumbers)
        let footnoteValues: [(String, String)] = [
            ("t-statistic", footnoteNumberFormatter.string(from: NSNumber(value: tTestResult.tStatistic))!),
            ("degrees of freedom", tTestResult.degreesOfFreedom.description),
            ("critical value", footnoteNumberFormatter.string(from: NSNumber(value: tTestResult.criticalValue))!),
        ]
        
        if tTestResult.seriesAreProbablyTheSame {
            change = .same
            footnotes = [
                .init(text: "The before and after values are similar enough that the most probable explanation is that they're random samples from the same data set.", values: footnoteValues)
            ]
        } else {
            let approximateChange = beforeNumbers.mean() - afterNumbers.mean()
            change = .differentNumeric(percentage: approximateChange)
            
            footnotes = [
                .init(text: "The before and after values are different enough that the most probable explanation is that random samples from two different data sets.", values: footnoteValues)
            ]
        }
        
        return MetricAnalysis(
            metricName: afterMetric.displayName,
            metricID: afterMetric.id,
            change: change,
            before: beforeMetric.values.formatted(),
            after: afterMetric.values.formatted(),
            footnotes: footnotes,
            warnings: warnings.isEmpty ? nil : warnings
        )
    }
    
    private static func inputBiasDescription(metricID: String, sampleName: String, numbers: [Double]) -> String {
        return """
        Warning:
        The '\(metricID)' samples from the '\(sampleName)' measurements show possible signs of a linear trend.
        The benchmark diff analysis assumes that the values for each metric represents a random selection from the normal distribution of samples for that metric. If there is bias in the samples it could mean that the conclusion from the diff analysis is invalid.
        [\(numbers.map { warningNumberFormatter.string(from: NSNumber(value: $0))! }.joined(separator: ", "))]
        """
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

private let footnoteNumberFormatter: NumberFormatter = {
    let fmt = NumberFormatter()
    fmt.numberStyle = .decimal
    fmt.positivePrefix = fmt.plusSign
    fmt.alwaysShowsDecimalSeparator = true
    fmt.maximumFractionDigits = 3
    fmt.minimumFractionDigits = 3
    return fmt
}()

private let warningNumberFormatter: NumberFormatter = {
    let fmt = NumberFormatter()
    fmt.numberStyle = .decimal
    fmt.alwaysShowsDecimalSeparator = true
    fmt.maximumFractionDigits = 9
    fmt.minimumFractionDigits = 9
    return fmt
}()
