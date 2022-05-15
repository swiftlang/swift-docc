/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A remote repository that hosts source code.
public struct SourceRepository {
    /// The path at which the repository is cloned locally.
    public var checkoutPath: String
    
    /// The base URL where the service hosts the repository's contents.
    public var sourceServiceBaseURL: URL
    
    /// A function that formats a line number to be included in a URL.
    public var formatLineNumber: (Int) -> String
    
    /// Creates a source code repository.
    /// - Parameters:
    ///   - checkoutPath: The path at which the repository is checked out locally and from which its symbol graphs were generated.
    ///   - sourceServiceBaseURL: The base URL where the service hosts the repository's contents.
    ///   - formatLineNumber: A function that formats a line number to be included in a URL.
    public init(
        checkoutPath: String,
        sourceServiceBaseURL: URL,
        formatLineNumber: @escaping (Int) -> String
    ) {
        self.checkoutPath = checkoutPath
        self.sourceServiceBaseURL = sourceServiceBaseURL
        self.formatLineNumber = formatLineNumber
    }
    
    /// Formats a local source file URL to a URL hosted by the remote source code service.
    /// - Parameters:
    ///   - sourceFileURL: The location of the source file on disk.
    ///   - lineNumber: A line number in the source file, 1-indexed.
    /// - Returns: The URL of the file hosted by the remote source code service if it could be constructed, otherwise, `nil`.
    public func format(sourceFileURL: URL, lineNumber: Int? = nil) -> URL? {
        guard sourceFileURL.path.hasPrefix(checkoutPath) else {
            return nil
        }
        
        let path = sourceFileURL.path.dropFirst(checkoutPath.count).removingLeadingSlash
        return sourceServiceBaseURL
            .appendingPathComponent(path)
            .withFragment(lineNumber.map(formatLineNumber))
    }
}

public extension SourceRepository {
    /// Creates a source repository hosted by the GitHub service.
    /// - Parameters:
    ///   - checkoutPath: The path of the local checkout.
    ///   - sourceServiceBaseURL: The base URL where the service hosts the repository's contents.
    static func github(checkoutPath: String, sourceServiceBaseURL: URL) -> SourceRepository {
        SourceRepository(
            checkoutPath: checkoutPath,
            sourceServiceBaseURL: sourceServiceBaseURL,
            formatLineNumber: { line in "L\(line)" }
        )
    }
    
    /// Creates a source repository hosted by the GitLab service.
    /// - Parameters:
    ///   - checkoutPath: The path of the local checkout.
    ///   - sourceServiceBaseURL: The base URL where the service hosts the repository's contents.
    static func gitlab(checkoutPath: String, sourceServiceBaseURL: URL) -> SourceRepository {
        SourceRepository(
            checkoutPath: checkoutPath,
            sourceServiceBaseURL: sourceServiceBaseURL,
            formatLineNumber: { line in "L\(line)" }
        )
    }
    
    /// Creates a source repository hosted by the BitBucket service.
    /// - Parameters:
    ///   - checkoutPath: The path of the local checkout.
    ///   - sourceServiceBaseURL: The base URL where the service hosts the repository's contents.
    static func bitbucket(checkoutPath: String, sourceServiceBaseURL: URL) -> SourceRepository {
        SourceRepository(
            checkoutPath: checkoutPath,
            sourceServiceBaseURL: sourceServiceBaseURL,
            formatLineNumber: { line in "lines-\(line)" }
        )
    }
}
