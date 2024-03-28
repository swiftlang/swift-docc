/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
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

    /// The path to a '.docc' documentation catalog directory of markup files and assets.
    @Argument(
        help: ArgumentHelp(
            "Path to a '.docc' documentation catalog directory.",
            valueName: "catalog-path"),
        transform: URL.init(fileURLWithPath:))
    public var url: URL?
}

@available(*, deprecated, renamed: "DocumentationCatalogOption", message: "Use 'DocumentationCatalogOption' instead. This deprecated API will be removed after 6.0 is released")
public typealias DocumentationBundleOption = DocumentationCatalogOption
