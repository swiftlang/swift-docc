/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation

/// Resolves and validates a URL value that provides the path to a documentation archive.
public struct DocCArchiveOption: DirectoryPathOption {

    public init(){}

    /// The name of the command line argument used to specify a source bundle path.
    static let argumentValueName = "source-archive-path"
    static let expectedContent: Set<String> = ["data"]

    /// The path to a archive to be used by DocC.
    @Argument(
        help: ArgumentHelp(
            "Path to the DocC Archive ('.doccarchive') that should be processed.",
            valueName: argumentValueName),
        transform: URL.init(fileURLWithPath:))
    public var url: URL?

    public mutating func validate() throws {

        // Validate that the URL represents a directory
        guard urlOrFallback.hasDirectoryPath == true else {
            throw ValidationError("'\(urlOrFallback.path)' is not a valid DocC Archive.")
        }
        
        var archiveContents: [String]
        do {
            archiveContents = try FileManager.default.contentsOfDirectory(atPath: urlOrFallback.path)
        } catch {
            throw ValidationError("'\(urlOrFallback.path)' is not a valid DocC Archive: \(error)")
        }
        
        guard DocCArchiveOption.expectedContent.isSubset(of: Set(archiveContents)) else {
            let missing = Array(Set(DocCArchiveOption.expectedContent).subtracting(archiveContents))
            throw ValidationError("'\(urlOrFallback.path)' is not a valid DocC Archive. Missing: \(missing)")
        }
        
    }
}
