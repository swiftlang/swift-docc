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

    /// The name of the command line argument used to specify a source archive path.
    static let argumentValueName = "source-archive-path"
    static let expectedContent: Set<String> = ["data"]

    /// The path to an archive to be used by DocC.
    @Argument(
        help: ArgumentHelp(
            "Path to the DocC Archive ('.doccarchive') that should be processed.",
            valueName: argumentValueName),
        transform: URL.init(fileURLWithPath:))
    public var url: URL?

    public mutating func validate() throws {

        // Validate that the URL represents a directory
        guard urlOrFallback.hasDirectoryPath else {
            throw ValidationError("'\(urlOrFallback.path)' is not a valid DocC Archive. Expected a directory but a path to a file was provided")
        }
        
        var archiveContents: [String]
        do {
            archiveContents = try FileManager.default.contentsOfDirectory(atPath: urlOrFallback.path)
        } catch {
            throw ValidationError("'\(urlOrFallback.path)' is not a valid DocC Archive: \(error)")
        }
        
        let missingContents = Array(Set(DocCArchiveOption.expectedContent).subtracting(archiveContents))
        guard missingContents.isEmpty else {
            throw ValidationError(
                """
                '\(urlOrFallback.path)' is not a valid DocC Archive.
                Expected a 'data' directory at the root of the archive.
                """
            )
        }
        
    }
}
