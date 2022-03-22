/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation

/// Resolves and validates a URL value that provides the path to a documentation catalog.
///
/// This option is used by the ``Docc/Convert`` subcommand.
public struct DocumentationCatalogOption: DirectoryPathOption {

    public init() {}

    /// The name of the command line argument used to specify a source catalog path.
    static let argumentValueName = "source-catalog-path"

    /// The path to a catalog to be compiled by DocC.
    @Argument(
        help: ArgumentHelp(
            "Path to a documentation catalog directory.",
            discussion: "The '.docc' catalog docc will build.",
            valueName: argumentValueName),
        transform: URL.init(fileURLWithPath:))
    public var url: URL?
}

@available(*, deprecated, renamed: "DocumentationCatalogOption")
public typealias DocumentationBundleOption = DocumentationCatalogOption
