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

struct CompareTo: ParsableCommand {
    @Argument(
        help: "The baseline 'commit-ish' to compare the current checkout against."
    )
    var commitHash: String
    
    @OptionGroup
    var measureOptions: MeasureOptions
    
    @Option(
        name: .customLong("output-dir"),
        help: "The directory to write the output benchmark measurements files.",
        transform: { URL(fileURLWithPath: $0) }
    )
    var outputDirectory: URL?
    var outputDirectoryOrFallback: URL {
        return outputDirectory ?? URL(fileURLWithPath: ".") // fallback to the current directory
    }
    
    mutating func run() throws {
        let currentDocCExecutable = try MeasureAction.buildDocC(at: doccProjectRootURL)
        let currentBenchmarkResult = try MeasureAction.gatherMeasurements(
            doccExecutable: currentDocCExecutable,
            repeatCount: measureOptions.repeatCount,
            doccConvertCommand: measureOptions.doccConvertCommand,
            computeMissingOutputSizeMetrics: measureOptions.computeMissingOutputSizeMetrics
        )
        
        let currentOutputFile = outputDirectoryOrFallback.appendingPathComponent("benchmark-current.json")
        try MeasureAction.writeResults(currentBenchmarkResult, to: currentOutputFile)
        
        let commitBenchmarkResult = try gatherMeasurementsForDocCCommit(
            commitHash,
            repeatCount: measureOptions.repeatCount,
            doccConvertCommand: measureOptions.doccConvertCommand,
            computeMissingOutputSizeMetrics: measureOptions.computeMissingOutputSizeMetrics
        )
        let commitOutputFile = outputDirectoryOrFallback.appendingPathComponent("benchmark-\(commitHash).json")
        try MeasureAction.writeResults(commitBenchmarkResult, to: commitOutputFile)
        
        try DiffAction(beforeFile: commitOutputFile, afterFile: currentOutputFile).run()
    }
}

struct MeasureCommits: ParsableCommand {
    // This has to be an Option to avoid conflicting with the `MeasureOptions.doccConvertCommand` Argument
    // which unconditionally consumes the remaining values.
    @Argument(
        help: "The commit hashes to gather measurements for."
    )
    var commitHashes: [String]
    
    @Option(
        name: .customLong("output-dir"),
        help: "The directory to write the output benchmark measurements files.",
        transform: { URL(fileURLWithPath: $0) }
    )
    var outputDirectory: URL?
    var outputDirectoryOrFallback: URL {
        return outputDirectory ?? URL(fileURLWithPath: ".") // fallback to the current directory
    }
    
    @OptionGroup
    var measureOptions: MeasureOptions
    
    mutating func run() throws {
        for commitHash in commitHashes {
            let commitBenchmarkResult = try gatherMeasurementsForDocCCommit(
                commitHash,
                repeatCount: measureOptions.repeatCount,
                doccConvertCommand: measureOptions.doccConvertCommand,
                computeMissingOutputSizeMetrics: measureOptions.computeMissingOutputSizeMetrics
            )
            let commitOutputFile = outputDirectoryOrFallback.appendingPathComponent("benchmark-\(commitHash).json")
            try MeasureAction.writeResults(commitBenchmarkResult, to: commitOutputFile)
        }
    }
}

func gatherMeasurementsForDocCCommit(
    _ commitHash: String,
    repeatCount: Int,
    doccConvertCommand: [String],
    computeMissingOutputSizeMetrics: Bool
) throws -> BenchmarkResultSeries {
    print("===== Gathering benchmark results for swift-docc \(commitHash) ========".styled(.bold))
    return try runWithDocCCommit(commitHash) { doccRootURL in
        let doccURL = try MeasureAction.buildDocC(at: doccRootURL)
        
        return try MeasureAction.gatherMeasurements(
            doccExecutable: doccURL,
            repeatCount: repeatCount,
            doccConvertCommand: doccConvertCommand,
            computeMissingOutputSizeMetrics: computeMissingOutputSizeMetrics
        )
    }
}
