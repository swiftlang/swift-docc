/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation

/// Resolves and validates the arguments needed to run the init catalog actions.
///
/// These options are used by the ``Docc/Init`` subcommand.

public struct InitOptions: ParsableArguments {
    
    public init() { }
    
    /// The catalog directory name and top level article title.
    ///
    /// Defaults to `Documentation`.
    @Option(
        name: .long,
        help: ArgumentHelp(
            "Name to use as the catalog directory name, the top level article title and file name",
            valueName: "name"
        )
    )
    public var name: String
    
    /// A user-provided location where the init action writes the generated catalog documentation.
    @Option(
        name: [.customLong("output-dir"), .customShort("o")],
        help: ArgumentHelp(
            "The location where the documention catalog will be written",
            valueName: "output-dir"
        ),
        transform: URL.init(fileURLWithPath:)
    )
    var providedCatalogOutputDirURL: URL
    
    public func validate() throws {
        // Verify that the directory exist for the output location.
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: providedCatalogOutputDirURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ValidationError("No directory exists at '\(providedCatalogOutputDirURL.path)'.")
        }
        
    }
    
    /// The catalog template to initialize.
    ///
    /// Defaults to init.
    @Option(
        name: .long,
        help: ArgumentHelp(
            "The catalog template to initialize. If not provided, the template will default to 'article-only",
            valueName: "template"
        )
    )
    public var catalogTemplate: CatalogTemplateKind = .articleOnly
}

extension CatalogTemplateKind: ExpressibleByArgument {}
