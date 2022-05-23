/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation

/// Resolves and validates a link resolve executable URL that points to a link resolver executable.
///
/// This value can be is set via an environment variable.
public struct OutOfProcessLinkResolverOption: ParsableArguments {

    public init() {}

    /// The environment variable key that can be used to set the ``linkResolverExecutableURL`` property.
    private static let environmentVariableKey = "DOCC_LINK_RESOLVER_EXECUTABLE"

    /// The path to an executable to be used during link resolution as provided by
    /// the environment variable `DOCC_LINK_RESOLVER_EXECUTABLE`.
    var linkResolverExecutableURL: URL? {
        ProcessInfo.processInfo.environment[OutOfProcessLinkResolverOption.environmentVariableKey]
            .map { URL(fileURLWithPath: $0, isDirectory: false) }
    }

    public mutating func validate() throws {
        // If the user-provided an explicit link resolver URL, first validate that it exists,
        // and then that it is executable
        try URLArgumentValidator.validateFileExists(linkResolverExecutableURL,
            forArgumentDescription: """
            '\(OutOfProcessLinkResolverOption.environmentVariableKey)' environment variable")
            """)
        
        try URLArgumentValidator.validateIsExecutableFile(linkResolverExecutableURL,
            forArgumentDescription: """
                '\(OutOfProcessLinkResolverOption.environmentVariableKey)' environment variable")
                """)
    }
}
