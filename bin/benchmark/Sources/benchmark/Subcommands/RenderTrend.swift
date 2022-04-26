/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import ArgumentParser
import SwiftDocC

// For argument parsing and validation

struct RenderTrend: ParsableCommand {
    @Option(
        name: .customLong("filter"),
        help: "A list metric IDs to render trends for. If no filters are specified, trends are rendered for all numeric metrics."
    )
    var metricFilters: [String] = []
    
    @Argument(
        help: "The list of benchmark measurements files to render a trend for.",
        transform: { URL(fileURLWithPath: $0) }
    )
    var benchmarkResults: [URL]
    
    mutating func run() throws {
        try RenderTrendAction(
            metricFilters: metricFilters,
            benchmarkResults: benchmarkResults
        ).run()
    }
}

// For running (which can easily be created from other run methods)

struct RenderTrendAction {
    var metricFilters: [String]
    var benchmarkResults: [URL]
    
    func run() throws {
        // Map the metric ID to the measured values across the benchmarks
        var trendValues: [String: [BenchmarkResultSeries.MetricSeries]] = [:]
        
        var metricIDOrder: [String] = []
        
        for file in benchmarkResults {
            let results = try JSONDecoder().decode(BenchmarkResultSeries.self, from: Data(contentsOf: file))
            
            for metric in results.metrics {
                guard metricFilters.isEmpty || metricFilters.contains(metric.id) else { continue }
                    
                switch metric.values {
                    case .duration, .bytesInMemory, .bytesOnDisk:
                       trendValues[metric.id, default: []].append(metric)
                        
                    case .checksum(_):
                        continue // Can only render trends for numeric metrics
                }
            }
            
            metricIDOrder = results.metrics.map { $0.id } // Get the order from the last result
        }
        
        for metricID in metricIDOrder {
            guard let metrics = trendValues[metricID] else {
                // Skip filtered-out metrics
                continue
            }
            
            print(metrics[0].displayName)
            print(Self.renderTrendBars(metrics: metrics))
        }
    }

    static func renderTrendBars(metrics: [BenchmarkResultSeries.MetricSeries]) -> String {
        var output = ""
        
        let baseline = metrics[0].doubleValues().mean()

        for metric in metrics {
            let percentageOfBaseLine = (metric.doubleValues().mean() / baseline)
            
            let fullBlocks = Int(percentageOfBaseLine * 80.0)
            let fraction = (percentageOfBaseLine * 80.0).truncatingRemainder(dividingBy: 1.0)
            let partialBlockIndex: Int? = {
                let i = Int(fraction * 8.0) /* because there are 8 possible characters */
                return i == 0 ? nil : i
            }()
            
            // Print the bar
            output += String(repeating: Self.partialBarCharacters[7], count: fullBlocks)
            if let partialBlockIndex = partialBlockIndex {
                output += Self.partialBarCharacters[partialBlockIndex]
            }
            output += "   \(metric.values.formatted())\n"
        }
        
        return output
    }
    
    // There are 8 blocks that increasingly fill form left to right.
    static let partialBarCharacters: [String] = [
    "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"
    ]
}

private extension BenchmarkResultSeries.MetricSeries {
    func doubleValues() -> [Double] {
        switch values {
            case .duration(let values):
                return values
                
            case .bytesInMemory(let values), .bytesOnDisk(let values):
                return values.map { Double($0) }
                
            case .checksum:
                fatalError("Checksum metrics should have already been filtered out.")
        }
    }
}
