/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// Usage: $swift benchmark-diff.swift benchmark1.json benchmark2.json

import Foundation

extension String: Error {
    /// Pads the string with spaces
    func padded(_ size: Int = 20) -> String {
        return padding(toLength: size, withPad: " ", startingAt: 0)
    }
}

/// Reads a before and after benchmark files and prints a report.
enum BenchmarkDiff {
    struct Metric {
        enum Value: CustomStringConvertible {
            case integer(Int64)
            case number(Double)
            case string(String)
            var description: String {
                switch self {
                case .integer(let integer): return integer.description
                case .number(let number): return String(format: "%.2f", number)
                case .string(let string): return string
                }
            }
        }
        
        let id: String
        var name: String
        var value: Value
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
            } else if let valueInt = result as? Int64 {
                value = .integer(valueInt)
            } else if let valueNumber = result as? Double {
                value = .number(valueNumber)
            } else {
                throw "Unexpected metric value: '\(String(describing: result))'"
            }
            return Metric(id: id, name: name, value: value)
        })
    }
    
    /// Loads two JSON files and prints the diff
    static func main(arguments: [String]) throws {
        guard arguments.count >= 2 else {
            print("Usage 'swift benchmark-diff.swift benchmark1.json benchmark2.json'")
            exit(0)
        }
        
        let before = try loadFile(URL(fileURLWithPath: arguments[0]))
        let after = try loadFile(URL(fileURLWithPath: arguments[1]))
        
        print("+\(String(repeating: "-", count: 101))+")
        print("| \("Metric".padded(40)) | \("Change".padded(10)) | \("Before".padded()) | \("After".padded()) |")
        print("+\(String(repeating: "-", count: 101))+")
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        
        after.sorted(by: { $0.name < $1.name }).enumerated().forEach { (index, metric) in
            guard var beforeValue = before.first(where: { $0.id == metric.id })?.value
                else { return }
            
            var metric = metric
            
            // Convert to seconds for presentation
            if metric.name.contains("(msec)"), case Metric.Value.integer(let msecs) = metric.value,
                case Metric.Value.integer(let beforeMSecs) = beforeValue {
                metric.name = metric.name.replacingOccurrences(of: "(msec)", with: "(sec)")
                metric.value = .number(Double(msecs) / 1000.0)
                beforeValue = .number(Double(beforeMSecs) / 1000.0)
            }

            // Convert to MB for presentation
            if metric.name.contains("(bytes)"), case Metric.Value.integer(let bytes) = metric.value,
                case Metric.Value.integer(let beforeBytes) = beforeValue {
                metric.name = metric.name.replacingOccurrences(of: "(bytes)", with: "(MB)")
                metric.value = .number(Double(bytes) / (1024.0 * 1024.0))
                beforeValue = .number(Double(beforeBytes) / (1024.0 * 1024.0))
            }
            
            let delta: String
            var before = beforeValue.description
            var after = metric.value.description
            switch (beforeValue, metric.value) {
            
            case (let .number(beforeNumber), let .number(afterNumber)):
                let change = (1 - afterNumber / beforeNumber) * 100.0
                if abs(change) < 0.009 {
                    delta = "no change"
                } else {
                    delta = (change > 0 ? "-\(String(format: "%.2f%%", change))" : "+\(String(format: "%.2f%%", abs(change)))")
                }
            case (let .integer(beforeNumber), let .integer(afterNumber)):
                let change = (1 - Double(afterNumber) / Double(beforeNumber)) * 100.0
                if abs(change) < 0.009 {
                    delta = "no change"
                } else {
                    delta = (change > 0 ? "-\(String(format: "%.2f%%", change))" : "+\(String(format: "%.2f%%", abs(change)))")
                }
                if let formattedBeforeValue = formatter.string(for: beforeNumber) {
                    before = formattedBeforeValue
                }
                if let formattedAfterValue = formatter.string(for: afterNumber) {
                    after = formattedAfterValue
                }
            case (let .string(beforeString), let .string(afterString)):
                delta = beforeString == afterString ? "no change" : "changed"
            default: delta = "n/a"
            }
            
            print("| \(metric.name.padded(40)) | \(delta.padded(10)) | \(before.padded()) | \(after.padded()) |")
        }
        print("+\(String(repeating: "-", count: 101))+")
    }
}

let main: Void = {
    try! BenchmarkDiff.main(arguments: Array(CommandLine.arguments[1...]))
}()
