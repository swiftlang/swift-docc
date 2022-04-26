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

struct Diff: ParsableCommand {
    @Argument(
        help: "The benchmark.json file to treat as the 'before' values in the diff.",
        transform: { URL(fileURLWithPath: $0) }
    )
    var beforeFile: URL
    
    @Argument(
        help: "The benchmark.json file to treat as the 'after' values in the diff.",
        transform: { URL(fileURLWithPath: $0) }
    )
    var afterFile: URL
    
    @Option(
        name: .customLong("json-output-path"),
        help: "The path to an optional JSON file to write the the diff results to.",
        transform: { URL(fileURLWithPath: $0) }
    )
    var jsonOutputFile: URL?
    
    mutating func run() throws {
        try DiffAction(
            beforeFile: beforeFile,
            afterFile: afterFile,
            jsonOutputFile: jsonOutputFile
        ).run()
    }
}

// For running (which can easily be created from other run methods)

struct DiffAction {
    var beforeFile: URL
    var afterFile: URL
    var jsonOutputFile: URL?
    
    func run() throws {
        let beforeMetrics = try JSONDecoder().decode(BenchmarkResultSeries.self, from: Data(contentsOf: beforeFile)).metrics
        let afterMetrics = try JSONDecoder().decode(BenchmarkResultSeries.self, from: Data(contentsOf: afterFile)).metrics
        
        var result = DiffResults.empty
        
        // The metrics are sorted for presentation but it's possible that the order has changed over time so we match the before
        for afterMetric in afterMetrics {
            let beforeMetric = beforeMetrics.first(where: { $0.id == afterMetric.id })
            try result.analysis.append(DiffResults.analyze(before: beforeMetric, after: afterMetric))
        }
        
        DiffResultsTable.columns[2] = tableColumnInfo(file: beforeFile)
        DiffResultsTable.columns[3] = tableColumnInfo(file: afterFile)
        
        let table = DiffResultsTable(results: result)
        print(table.output)
        
        if let jsonOutputFile = jsonOutputFile {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(result).write(to: jsonOutputFile)
        }
    }
}

private func tableColumnInfo(file: URL) -> (String, Int) {
    var name = file.deletingPathExtension().lastPathComponent
    if name.hasPrefix("benchmark-") {
        name = String(name.dropFirst("benchmark-".count))
    }
    
    let width = min(40, max(20, name.count))
    return (name, width)
}
