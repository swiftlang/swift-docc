/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import ArgumentParser

/// A parsable argument for an optional directory path.
///
/// This option validates the provided path exists and that it's a directory.
public protocol DirectoryPathOption: ParsableArguments {
    /// The path to a directory.
    var url: URL? { get }
}

extension DirectoryPathOption {
    /// The provided ``url`` or the "current directory" if the user didn't provide an argument.
    public var urlOrFallback: URL {
        return url ?? URL(fileURLWithPath: ".", isDirectory: true)
    }

    public mutating func validate() throws {
        guard let url else {
            return
        }

        // Validate that the URL represents a directory
        guard url.hasDirectoryPath == true else {
            throw ValidationError("No documentation directory exists at '\(url.path)'.")
        }
    }
}
