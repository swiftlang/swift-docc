/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import ArgumentParser

/// Resolves and validates a URL value that provides the path to a documentation directory.
public protocol DocumentationOption: ParsableArguments {
    var url: URL? { get }
}

extension DocumentationOption {
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
