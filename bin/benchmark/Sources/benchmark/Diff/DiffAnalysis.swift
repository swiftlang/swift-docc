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
                
                if Set(beforeValues).count == 1, Set(afterValues).count == 1 {
                    return MetricAnalysis(
                        metricName: afterMetric.displayName,
                        metricID: afterMetric.id,
                        change: beforeValues == afterValues ? .same : .differentChecksum,
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
        switch beforeMetric.values {
            case .duration, .bytesInMemory:
                if !beforeNumbers.looksReasonablyNonBiased() {
                    warnings.append(Self.inputBiasDescription(metric: beforeMetric, sampleName: "before", numbers: beforeNumbers))
                }
                if !afterNumbers.looksReasonablyNonBiased() {
                    warnings.append(Self.inputBiasDescription(metric: afterMetric, sampleName: "after", numbers: afterNumbers))
                }
                    
            default:break
        }
        
        let change: MetricAnalysis.Change
        var footnotes: [MetricAnalysis.Footnote]
        
        let tTestResult = independentTTest(beforeNumbers, afterNumbers)
        let footnoteValues: [(String, String)] = [
            ("t-statistic", footnoteNumberFormatter.string(from: NSNumber(value: tTestResult.tStatistic))!),
            ("degrees of freedom", tTestResult.degreesOfFreedom.description),
            ("95% confidence critical value", footnoteNumberFormatter.string(from: NSNumber(value: tTestResult.criticalValue))!),
        ]
        
        if tTestResult.seriesAreProbablyTheSame {
            change = .same
            footnotes = [
                .init(text: """
                    No statistically significant difference.
                    The values are similar enough that the most probable explanation is that they're random samples from the same data set.
                    """, values: footnoteValues)
            ]
        } else {
            let approximateChange = (afterNumbers.mean() - beforeNumbers.mean()) / beforeNumbers.mean()
            change = .differentNumeric(percentage: approximateChange)
            
            footnotes = [
                .init(text: """
                    There's a statistically significant difference between the two benchmark measurements.
                    The values are different enough that the most probable explanation is that they're random samples from two different data sets.
                    """, values: footnoteValues)
            ]
        }
        
        if !warnings.isEmpty {
            footnotes.append(
                .init(text: "A human should check that the measurements for this metric look like random samples around a certain value to ensure the validity of this result.", values: [])
            )
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
    
    private static func inputBiasDescription(metric: BenchmarkResultSeries.MetricSeries, sampleName: String, numbers: [Double]) -> String {
        // Turn the single metric series into an array of single values metric series to render the trend bars.
        
        let metricSeries: [BenchmarkResultSeries.MetricSeries]
        switch metric.values {
            case .duration(let values):
                metricSeries = values.map {
                    .init(id: metric.id, displayName: metric.displayName, values: .duration([$0]))
                }
                
            case .bytesInMemory(let values):
                metricSeries = values.map {
                    .init(id: metric.id, displayName: metric.displayName, values: .bytesInMemory([$0]))
                }
            case .bytesOnDisk(let values):
                metricSeries = values.map {
                    .init(id: metric.id, displayName: metric.displayName, values: .bytesOnDisk([$0]))
                }
                
            case .checksum:
                // Only numeric metrics support trend bars
                fatalError("Can't compute input bias for checksum metrics.")
        }
        
        return """
        The '\(metric.id)' samples from the '\(sampleName)' measurements show \("possible".styled(.bold)) signs of bias.
        The benchmark diff analysis assumes that these values follow a normal distribution around the value that they're meant to represent. If they don't the conclusion from the diff analysis could be invalid.
        \("A human should inspect these values".styled(.bold)). If the samples look biased or look too noisy you can try gathering new metrics with more 'repetitions' or with a larger .docc catalog.
        \("Full precision values: [\(numbers.map { warningNumberFormatter.string(from: NSNumber(value: $0))! }.joined(separator: ", "))]".styled(.dim))
        \(RenderTrendAction.renderTrendBars(metrics: metricSeries))
        """
    }
}

extension BenchmarkResultSeries.MetricSeries.ValueSeries {
    func formatted() -> String {
        switch self {
            case .duration(let value):
                let average = value.mean()
            
                #if os(macOS) || os(iOS)
                return durationFormatter.string(from: Measurement(value: average, unit: UnitDuration.seconds))
                #else
                return durationFormatter.string(from: NSNumber(value: average))! + " sec"
                #endif
                
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

#if os(macOS) || os(iOS)
private let durationFormatter: MeasurementFormatter = {
    let fmt = MeasurementFormatter()
    fmt.unitStyle = .medium
    return fmt
}()
#else
private let durationFormatter: NumberFormatter = {
    let fmt = NumberFormatter()
    fmt.numberStyle = .decimal
    fmt.maximumFractionDigits = 3
    fmt.minimumFractionDigits = 1
    return fmt
}()
#endif

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
    fmt.maximumFractionDigits = 9
    fmt.minimumSignificantDigits = 6
    fmt.thousandSeparator = ""
    return fmt
}()
