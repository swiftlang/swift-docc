/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation

/// Resolves and validates a URL value that provides the path to a documentation bundle.
public struct DocumentationBundleOption: ParsableArguments {

    public init() {}

    /// The name of the command line argument used to specify a source bundle path.
    static let argumentValueName = "source-bundle-path"

    /// The path to a bundle to be compiled by DocC.
    @Argument(
        help: ArgumentHelp(
            "Path to a data directory of JSON files from a compiled documentation archive.",
            discussion: "The '.docc' bundle docc will build.",
            valueName: argumentValueName),
        transform: URL.init(fileURLWithPath:))
    public var url: URL?
    
    public var urlOrFallback: URL {
        return url ?? URL(fileURLWithPath: ".")
    }
    
    public mutating func validate() throws {
        guard let url = url else {
            return
        }
        
        // Validate that the URL represents a directory
        guard url.hasDirectoryPath == true else {
            throw ValidationError("No documentation directory exist at '\(url.path)'.")
        }
    }
}
