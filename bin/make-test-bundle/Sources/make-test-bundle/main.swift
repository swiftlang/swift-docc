/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// Usage: $swift run make-test-bundle --output path/to/folder --sizeFactor 5

import Foundation

/// Creates a test framework and its documentation bundle on disk.
enum MakeTestBundle {
    static func main(arguments: [String]) throws {
        guard arguments.count == 4 else {
            print("Usage: 'swift run make-test-bundle --output path/to/folder --sizeFactor 10'")
            exit(1)
        }
        
        // Read output folder argument.
        guard let outputIndex = arguments.firstIndex(of: "--output"), outputIndex.advanced(by: 1) < arguments.endIndex else {
            throw "Specify output path: --output path/to/output/folder"
        }
        let outputURL = URL(fileURLWithPath: arguments[outputIndex.advanced(by: 1)])
        
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: outputURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw "\(outputURL.path) directory does not exist"
        }
        
        // Read size argument.
        guard let factorIndex = arguments.firstIndex(of: "--sizeFactor"), factorIndex.advanced(by: 1) < arguments.endIndex, let factor = UInt(arguments[factorIndex.advanced(by: 1)]), factor > 1 else {
            throw "Specify size factor greater than 1: --sizeFactor 10"
        }
        
        // Create the bundle
        let bundle = OutputBundle(outputURL: outputURL, sizeFactor: factor)
        try bundle.createOutputDirectory()
        try bundle.createContent()
        try bundle.createSymbolGraph()
        try bundle.createInfoPlist()
        
        // Summary
        if let summary = bundle.summary() {
            print()
            print("Output: \(bundle.outputURL.path), \(summary)")
            print()
        }
    }
}

#if os(macOS)
do {
    try MakeTestBundle.main(arguments: Array(CommandLine.arguments[1...]))
} catch {
    print(error)
    exit(1)
}
#else
print("make-test-bundle is only supported on macOS.")
#endif
