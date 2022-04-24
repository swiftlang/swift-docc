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

struct Measure: ParsableCommand {
    
    @Option(
        name: .customLong("repetitions"),
        help: "How many times to run the 'docc convert' command. Defaults to 5 times.")
    var repeatCount: Int = 5
    
    @Option(
        name: .customLong("output"),
        help: "The path to write the output benchmark measurements file.",
        transform: { URL(fileURLWithPath: $0) }
    )
    var outputLocation: URL
    
    @Option(
        help: "An optional base benchmark to `diff` gathered measurements against.",
        transform: { URL(fileURLWithPath: $0) }
    )
    var baseBenchmark: URL?
    
    @Argument(
        parsing: .unconditionalRemaining,
        help: "docc convert command to gather measurements for")
    var doccConvertCommand: [String]
    
    func validate() throws {
        let minimalRepeatCount = 1
        let maximumRepeatCount = 30
        
        guard repeatCount >= minimalRepeatCount else {
            throw ArgumentParser.ValidationError("""
                Too few repetitions. Benchmark needs to run at least \(minimalRepeatCount) time.
                Pass a `--repetitions` value between \(minimalRepeatCount) and \(maximumRepeatCount).
                """)
        }
        guard repeatCount < maximumRepeatCount else {
            throw ArgumentParser.ValidationError("""
                Too many repetitions. Statistical analysis is only implemented up to \(maximumRepeatCount) samples.
                Pass a `--repetitions` value between \(minimalRepeatCount) and \(maximumRepeatCount).
                """)
        }
        
        guard doccConvertCommand.count >= 2, doccConvertCommand.first == "convert" else {
            throw ArgumentParser.ValidationError("""
                Missing `convert` action and arguments to run `docc` with.
                Pass `convert /path/to/bundle.docc [other-docc-flags]` after the main benchmark flags.
                """)
        }
    }
    
    enum Error: Swift.Error, CustomStringConvertible {
        case doccBuildFailed(URL)
        case cooldownTimeout
        case benchmarkFileNotFound(URL)
        case subtaskTerminated(Int32, Process.TerminationReason)
        
        var description: String {
            switch self {
            case .doccBuildFailed(let url):
                return "Encountered error building docc or built executable couldn't be found at \(url.path)"
            case .cooldownTimeout:
                return "Timed out waiting for machine to reach fair thermal state. Aborting to avoid biased measurements."
            case .benchmarkFileNotFound(let url):
                return "Encountered error running docc with benchmark or benchmark measurements file couldn't be found at \(url.path)"
                case .subtaskTerminated(let code, let reason):
                    return "Subtask terminated with status: (\(code)), reason: \(reason)"
            }
        }
    }
    
    mutating func run() throws {
        // Compile the project for release
        print("Building docc in release configuration")
        
        try runTask(envURL, directory: doccProjectRootURL, arguments: ["swift", "build", "-c", "release", "--product", "docc"])
        let doccURL = doccProjectRootURL.appendingPathComponent(".build").appendingPathComponent("release").appendingPathComponent("docc")
        guard FileManager.default.fileExists(atPath: doccURL.path) else {
            throw Error.doccBuildFailed(doccURL)
        }
        
        let temporaryOutputLocation = FileManager.default.temporaryDirectory.appendingPathComponent("docc-benchmark-\(ProcessInfo.processInfo.globallyUniqueString)")
        defer {
            try? FileManager.default.removeItem(at: temporaryOutputLocation)
        }
        
        try FileManager.default.createDirectory(at: temporaryOutputLocation, withIntermediateDirectories: false)
        
        let doccOutputLocation = temporaryOutputLocation.appendingPathComponent(".docc-build")
        let benchmarkFileLocation = doccOutputLocation.appendingPathComponent("benchmark.json")
        
        // Replace the docc arguments with a custom output directory
        var doccArguments = doccConvertCommand
        if let outputDirOptionIndex = doccArguments.firstIndex(of: "--output-dir") {
            let outputDirValueIndex = doccArguments.index(after: outputDirOptionIndex)
            if outputDirValueIndex < doccArguments.count {
                doccArguments[outputDirValueIndex] = doccOutputLocation.path
            } else {
                doccArguments.append(doccOutputLocation.path)
            }
        } else {
            doccArguments.append(contentsOf: ["--output-dir", doccOutputLocation.path])
        }
        
        // This adds some extra wait time before the first measurement.
        try waitUntilFairThermalState(minimumWait: 5)
        
        var benchmarkSeries = BenchmarkResultSeries.empty
        
        for conversionIndex in 1...repeatCount {
            try waitUntilFairThermalState(minimumWait: 10)
            
            print("Measuring data for sample [\(conversionIndex) / \(repeatCount)]")
            try runTask(doccURL, arguments: doccArguments, environment: ["DOCC_BENCHMARK": "YES"])
            
            guard FileManager.default.fileExists(atPath: benchmarkFileLocation.path) else {
                throw Error.benchmarkFileNotFound(benchmarkFileLocation)
            }
            
            let benchmarkResult = try JSONDecoder().decode(BenchmarkResults.self, from: Data(contentsOf: benchmarkFileLocation))
            try benchmarkSeries.add(benchmarkResult)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let outputData = try encoder.encode(benchmarkSeries)
        try outputData.write(to: outputLocation)
        
        print("Result: \(outputLocation.path)")
        
        // Run a diff command if a base benchmark was provided.
        guard let baseBenchmark = baseBenchmark else {
            return
        }
        
        try DiffAction(beforeFile: baseBenchmark, afterFile: outputLocation).run()
    }
}

private let envURL = URL(fileURLWithPath: "/usr/bin/env")

private func runTask(_ url: URL, directory: URL? = nil, arguments: [String] = [], environment: [String: String] = [:]) throws {
    let task = Process()
    if #available(macOS 10.13, *) {
        task.currentDirectoryURL = directory
    } else if let directoryPath = directory?.path {
        task.currentDirectoryPath = directoryPath
    }
    if #available(macOS 10.13, *) {
        task.executableURL = url
    } else {
        task.launchPath = url.path
    }
    task.arguments = arguments
    task.environment = ProcessInfo.processInfo.environment.merging(environment, uniquingKeysWith: +)
    
    task.launch()
    task.waitUntilExit()
    
    
    guard task.terminationStatus == 0 else {
        throw Measure.Error.subtaskTerminated(task.terminationStatus, task.terminationReason)
    }
}

private func waitUntilFairThermalState(minimumWait: Int) throws {
    print("Preparing for next stage", terminator: " ")
    
    let timeout = 120
    var current = 0
    
    while (current < minimumWait + timeout) {
        sleep(1)
        current += 1
        print(".", terminator: "")
#if os(macOS)
        fflush(__stdoutp)
        let fairState = (ProcessInfo.processInfo.thermalState == .nominal || ProcessInfo.processInfo.thermalState == .fair)
#else
        let fairState = true
#endif
        if current > minimumWait && fairState {
            print()
            return
        }
    }
    
    throw Measure.Error.cooldownTimeout
}
