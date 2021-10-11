/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// Usage: $swift output-diff.swift directory1 directory2 [--ignore-array-order-for-paths path1,path2,path3] [--file-filter phrase1,phrase2] [--log-path path/to/logfile]

import Foundation

fileprivate var flagIgnoreArrayOrderForPaths = [String]()

/// A struct to decode any kind of JSON element.
indirect enum JSON: Decodable {
    case dictionary([String: JSON])
    case array([JSON])
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else if let numericValue = try? container.decode(Double.self) {
            self = .number(numericValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([JSON].self) {
            self = .array(arrayValue)
        } else {
            self = .dictionary(try container.decode([String: JSON].self))
        }
    }
    
    /// Compares two `JSON` values recursively and produces detailed summary.
    public static func compare(lhs: JSON, rhs: JSON, diff: inout [String], path: [String] = [""]) -> Bool {
        switch (lhs, rhs) {
        case let (.array(lhs), .array(rhs)):
            guard lhs.count == rhs.count else {
                diff.append("Error at path \(path.joined(separator: "/")): \(lhs.count) != \(rhs.count) array elements")
                return false
            }
            
            // Ignore the order of elements in arrays where it doesn't matter
            if flagIgnoreArrayOrderForPaths.first(where: { path.joined(separator: "/").contains($0) }) != nil {
                var result = true
                for (offset, value) in lhs.enumerated() {
                    var valueDiff = [String]()
                    let valueFound = rhs.contains(where: {
                        return JSON.compare(lhs: value, rhs: $0, diff: &valueDiff, path: [])
                    })
                    guard valueFound else {
                        let keyPath = path + ["\(offset)"]
                        diff.append("Error at path \(keyPath.joined(separator: "/")): Element not found in after version of the array.")
                        result = false
                        continue
                    }
                }
                return result
            } else {
                return lhs.enumerated().reduce(into: true) { (result, pair) in
                    var valueDiff = [String]()
                    let valueResult = JSON.compare(lhs: lhs[pair.offset], rhs: rhs[pair.offset], diff: &valueDiff, path: path + [String(pair.offset)])
                    diff.append(contentsOf: valueDiff)
                    result = result && valueResult
                }
            }
        case let (.dictionary(lhs), .dictionary(rhs)):
            guard lhs.keys == rhs.keys else {
                for change in Array(lhs.keys.sorted()).difference(from: rhs.keys.sorted()) {
                    switch change {
                        case .insert(_, let element, _): diff.append("Error at path \(path.joined(separator: "/")): Removed key '\(element)'")
                        case .remove(_, let element, _): diff.append("Error at path \(path.joined(separator: "/")): Added key '\(element)'")
                    }
                }
                return false
            }
            return lhs.keys.reduce(into: true) { (result, key) in
                var keyDiff = [String]()
                let keyResult = JSON.compare(lhs: lhs[key]!, rhs: rhs[key]!, diff: &keyDiff, path: path + [key])
                diff.append(contentsOf: keyDiff)
                result = result && keyResult
            }
        case let (.string(lhs), .string(rhs)):
            guard lhs == rhs else {
                diff.append("Error at path \(path.joined(separator: "/")): '\(lhs)' != '\(rhs)'")
                return false
            }
            return true
        case let (.number(lhs), .number(rhs)):
            guard lhs == rhs else {
                diff.append("Error at path \(path.joined(separator: "/")): '\(lhs)' != '\(rhs)'")
                return false
            }
            return true
        case let (.boolean(lhs), .boolean(rhs)):
            guard lhs == rhs else {
                diff.append("Error at path \(path.joined(separator: "/")): '\(lhs)' != '\(rhs)'")
                return false
            }
            return true
        case (.null, .null): return true
        default: return false
        }
    }
}

enum OutputDiff {
    /// Loads the recursive file listing of a given directory.
    static func loadDirectoryContents(_ directoryURL: URL, ignoreFiles: [String]? = nil) throws -> [URL] {
        var files = [URL]()
        
        if let enumerator = FileManager.default.enumerator(at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let url as URL in enumerator {
                guard try url.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile == true else { continue }
                guard url.pathExtension == "json" else {
                    continue
                }
                if let filters = ignoreFiles {
                    guard filters.first(where: { url.path.contains($0) }) == nil else { continue }
                }
                let relativePath = url.path.replacingOccurrences(of: directoryURL.path.appending("/"), with: "")
                let fileURL = URL(string: relativePath, relativeTo: directoryURL)!
                files.append(fileURL)
            }
        }
        return files
    }

    static func main(arguments: [String]) throws {
        if arguments.contains("--help") || arguments.count < 2 {
            print("Usage: $swift output-diff.swift output-directory1 output-directory2 [options]")
            print("Options:")
            print(" --log-path: a path to save the output log file")
            print(" --ignore-array-order-for-paths: comma separated list of JSON path patterns of arrays in which elements order does not need to match")
            print(" --file-filter: comma separated list of filename patterns to use to filter files in the target directories")
            exit(0)
        }
        
        if let argumentIndex = arguments.firstIndex(of: "--ignore-array-order-for-paths") {
            flagIgnoreArrayOrderForPaths = arguments[argumentIndex.advanced(by: 1)].components(separatedBy: ",")
        }
        
        var fileFilters: [String]? = nil
        if let argumentIndex = arguments.firstIndex(of: "--file-filter") {
            fileFilters = arguments[argumentIndex.advanced(by: 1)].components(separatedBy: ",")
        }

        var logPath: URL? = nil
        if let argumentIndex = arguments.firstIndex(of: "--log-path") {
            logPath = URL(fileURLWithPath: arguments[argumentIndex.advanced(by: 1)])
        }
        
        // Load deep-listings of the two folders
        let before = try loadDirectoryContents(URL(fileURLWithPath: arguments[0]), ignoreFiles: fileFilters)
        let after = try loadDirectoryContents(URL(fileURLWithPath: arguments[1]), ignoreFiles: fileFilters)
        
        // Bail out if the listings don't match exactly
        let difference = before.map({ $0.relativePath })
            .difference(from: after.map({ $0.relativePath }))
        
        guard difference.count == 0 else {
            print("Error: File listing not equal.")
            difference.forEach({
                switch $0 {
                    case .insert(let index, _, _): print("Removed '\(before[index].path)'")
                    case .remove(let index, _, _): print("Added '\(after[index].path)'")
                }
            })
            return
        }
        
        // Compare file contents; at this point we are sure the two listings match
        let decoder = JSONDecoder()
        var problems = [String]()
        var success = true
        #if os(macOS)
        var lock = os_unfair_lock_s()
        #endif
        
        var processed = 0 {
            didSet {
                if processed % 10 == 0 {
                    print("\u{1B}[1A\u{1B}[KDiffing \(String(format: "%.2f", 100 * Double(processed)/Double(before.count)))% of \(before.count) files. \(problems.count) problem(s).")
                    #if os(macOS)
                    fflush(__stdoutp)
                    #endif
                }
            }
        }
        
        let block: (Int) -> Void = { index in
            let beforeContent: JSON
            let afterContent: JSON
            var fileDiff = [String]()
            var fileSuccess: Bool = true
            
            do {
                beforeContent = try decoder.decode(JSON.self, from: try Data(contentsOf: before[index].absoluteURL))
                afterContent = try decoder.decode(JSON.self, from: try Data(contentsOf: after[index].absoluteURL))
                fileSuccess = JSON.compare(lhs: beforeContent, rhs: afterContent, diff: &fileDiff)
            } catch {
                fileDiff.append(error.localizedDescription)
                fileSuccess = false
            }
            
            #if os(macOS)
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            #endif
            
            success = success && fileSuccess
            processed += 1
            problems.append(contentsOf: fileDiff.map {
                "\($0)\nBefore: \(before[index].absoluteURL.path)\nAfter: \(after[index].absoluteURL.path)\n"
            })
        }

        // For larger bundles comparing might be very CPU intensive so we spread over more cores
        #if os(macOS)
        DispatchQueue.concurrentPerform(iterations: before.count, execute: block)
        #else
        (0..<before.count).forEach(block)
        #endif
        
        guard success else {
            // Print any problems to a log file or the console
            let output = problems.joined(separator: "\n").appending("Total of \(problems.count) problem(s) found.")
            if let logPath = logPath {
                try output.write(to: logPath, atomically: true, encoding: .utf8)
            } else {
                print(output)
            }
            return
        }
        
        print("\(before.count) files found in each folder.")
        print("Output folders' content is identical.")
    }
}

let main: Void = {
    try! OutputDiff.main(arguments: Array(CommandLine.arguments.dropFirst()))
}()
