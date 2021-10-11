/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

let envURL = URL(fileURLWithPath: "/usr/bin/env")
extension String: Error { }

extension Array where Element == Double {
    // Returns the median value in an array.
    var median: Double {
        let sortedSelf = sorted()
        if (count % 2 == 0) {
            return (sortedSelf[count / 2 - 1] + sortedSelf[count / 2]) / 2.0
        }
        return sortedSelf[count / 2]
    }
}

/// Runs an external process.
func runTask(_ url: URL, directory: URL? = nil, arguments: [String] = [], environment: [String: String] = [:]) throws {
    let task = Process()
    task.currentDirectoryURL = directory
    task.executableURL = url
    task.arguments = arguments
    task.environment = ProcessInfo.processInfo.environment.merging(environment, uniquingKeysWith: +)
    task.launch()
    task.waitUntilExit()

    guard task.terminationStatus == 0 else {
        throw "Exit status (\(task.terminationStatus)) \(task.terminationReason)"
    }
}

enum Benchmark {
    /// A metric data model.
    struct Metric {
        /// A metric value.
        enum Value: CustomStringConvertible {
            /// An integer metric value.
            case integer(Int64)
            /// A number metric value.
            case number(Double)
            /// A string metric value.
            case string(String)
            /// Formatted value for printing.
            var description: String {
                switch self {
                case .integer(let integer): return integer.description
                case .number(let number): return String(format: "%.2f", number)
                case .string(let string): return string
                }
            }
        }
        
        let id: String
        let name: String
        let value: Value
    }
    
    /// Loads the metrics from a given JSON file.
    static func loadFile(_ url: URL) throws -> [Metric] {
        let data = try Data(contentsOf: url)
        
        guard let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let metrics = object["metrics"] as? [[String: Any]] else {
            throw "Unexpected JSON format at \(url.path)."
        }
        
        return try metrics.compactMap({ item in
            guard let id = item["identifier"] as? String,
                let name = item["displayName"] as? String,
                let result = item["result"] else {
                return nil
            }
            
            let value: Metric.Value
            if let valueString = result as? String {
                value = .string(valueString)
            } else if let valueNumber = result as? Double {
                value = .number(valueNumber)
            } else {
                throw "Unexpected metric value: '\(String(describing: result))'"
            }
            return Metric(id: id, name: name, value: value)
        })
    }
    
    /// Write a benchmark file with median values.
    static func writeBenchmarkFile(to: URL, base: URL, metrics allMetrics: [[Metric]]) throws {
        let object = try JSONSerialization.jsonObject(with: try Data(contentsOf: base), options: [.mutableContainers]) as! [String: Any]
        // Get the median values for numeric metrics
        var metrics = object["metrics"] as! [[String: Any]]
        for (index, metric) in metrics.enumerated() {
            if let _ = metric["result"] as? Double, let metricID = metric["identifier"] as? String {
                let allMetricValues = try allMetrics.map({ metrics -> Double in
                    let metric = metrics
                        .first(where: { metric in
                            guard case Metric.Value.number = metric.value, metric.id == metricID else { return false }
                            return true
                        })!
                    guard case let Metric.Value.number(number) = metric.value else { throw "Data consistency error" }
                    return number
                })
                print("\(metric["identifier"]!) median:")
                let median = allMetricValues.median
                print("  \(String(format: "%.2f", median)) in \(allMetricValues.sorted().map{ String(format: "%.2f", $0) })")
                metrics[index]["result"] = median
            }
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
        try data.write(to: to)
    }
    
    /// Waits a given timeout while the machine is in at least fair thermal state.
    static func waitUntilReadyForNextStep(wait: Int) throws {
        print("Preparing for next stage", terminator: " ")
        
        let timeout = 120
        var current = 0
        
        while (current < wait + timeout) {
            sleep(1)
            current += 1
            print(".", terminator: "")
            #if os(macOS)
            fflush(__stdoutp)
            let fairState = (ProcessInfo.processInfo.thermalState == .nominal || ProcessInfo.processInfo.thermalState == .fair)
            #else
            let fairState = true
            #endif
            if current > wait && fairState {
                print()
                return
            }
        }
        
        throw "Timed out while waiting machine to cool down"
    }
    
    static let usage = "\n\nUsage: $swift benchmark.swift [--repetitions 5] [--output output/path] [--base-benchmark path/to/benchmark.json] convert path/to/bundle\n\n"
        + "  --repetitions how many times to run the conversion\n"
        + "  --output the path to write the output benchmark-median.json file\n"
        + "  --base-benchmark a benchmark json file to compare the current results against\n"
    
    /// Run the main CLI workflow.
    static func main(arguments: [String]) throws {
        var arguments = arguments
        
        let projectURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // benchmark.swift
            .deletingLastPathComponent() // containing dir
        guard FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("Package.swift").path) else {
            throw "Could not find the project source files in \(projectURL.path)."
        }
        
        // Print usage.
        if arguments.count < 2 {
            print(usage)
            return
        }
        
        // Fetch arguments
        guard let convertIndex = arguments.firstIndex(of: "convert") else {
            throw "Specify convert command and its arguments.\(usage)"
        }
        
        // Replace original source with temp folder
        guard convertIndex.advanced(by: 1) < arguments.count else {
            throw "Specify source bundle.\(usage)"
        }
        let sourceBundleURL = URL(fileURLWithPath: arguments[convertIndex.advanced(by: 1)])
        
        guard sourceBundleURL.pathExtension == "docc",
            FileManager.default.fileExists(atPath: sourceBundleURL.path) else {
            throw "Specify a valid source bundle path with a .docc extension.\(usage)"
        }
        
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString.appending(".docc"))
        try FileManager.default.copyItem(at: sourceBundleURL, to: tempURL)
        arguments[convertIndex.advanced(by: 1)] = tempURL.path
        
        // Repetitions argument
        let conversionRepetitions = arguments.firstIndex(of: "--repetitions")
            .flatMap { Int(arguments[$0.advanced(by: 1)]) }
            ?? 5

        // Before doing anything wait until machine cools down
        try waitUntilReadyForNextStep(wait: 5)

        // Compile the project for release
        print("Compile docc release build")
        try runTask(envURL, directory: projectURL, arguments: ["swift", "build", "-c", "release"])
        let doccURL = projectURL.appendingPathComponent(".build").appendingPathComponent("release").appendingPathComponent("docc")
        try waitUntilReadyForNextStep(wait: 5)
        print("Built \(doccURL.path)")

        guard FileManager.default.fileExists(atPath: doccURL.path) else {
            throw "Compiling a release build failed."
        }

        var benchmarkResults = [[Metric]]()
        let buildFolderURL = tempURL.appendingPathComponent(".docc-build")
        let benchmarkFileURL = buildFolderURL.appendingPathComponent("benchmark.json")

        // Run conversions and gather results
        for conversionIndex in 1...conversionRepetitions {
            try waitUntilReadyForNextStep(wait: 10)
            
            print("Conversion #\(conversionIndex).")
            print("Run \(doccURL.path)")
            try runTask(doccURL, arguments: Array(arguments[convertIndex...]), environment: ["DOCC_BENCHMARK": "YES"])

            guard FileManager.default.fileExists(atPath: benchmarkFileURL.path) else {
                throw "benchmark.json not found."
            }
            
            let newMetrics = try loadFile(benchmarkFileURL)
            benchmarkResults.append(newMetrics)
        }
                
        // Benchmark JSON output path.
        let outputURL = arguments.firstIndex(of: "--output")
            .flatMap { arguments[$0.advanced(by: 1)] }
            .map(URL.init(fileURLWithPath:))
            ?? sourceBundleURL.appendingPathComponent("benchmark-median.json")

        try writeBenchmarkFile(to: outputURL, base: benchmarkFileURL, metrics: benchmarkResults)
        print("Result: \(outputURL.path)")

        // Clean the temp folder
        try FileManager.default.removeItem(at: buildFolderURL)

        // Print diff if needed
        if let baseIndex = arguments.firstIndex(of: "--base-benchmark") {
            try runTask(envURL, directory: projectURL, arguments: ["swift", "bin/benchmark-diff.swift", arguments[baseIndex.advanced(by: 1)], outputURL.path])
        }
        
        print("Done.")
    }
}

let main: Void = {
    do {
        try Benchmark.main(arguments: Array(CommandLine.arguments[1...]))
    } catch {
        print(error)
        exit(1)
    }
}()
