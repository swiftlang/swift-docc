/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
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
            valueName: "documentation-title"
        )
    )
    public var documentationTitle: String = "Documentation"
    
    /// The catalog output path.
    ///
    /// Defaults to the current directory when invoked.
    @Option(
        name: .long,
        help: ArgumentHelp(
            "The location where the documention catalog will be written",
            valueName: "catalog-output-path"
        )
    )
    public var catalogOutputPath: String = FileManager().currentDirectoryPath
    
    /// The catalog template to initialize.
    ///
    /// Defaults to init.
    @Option(
        name: .long,
        help: ArgumentHelp(
            "The catalog template to initialize.",
            valueName: "template"
        )
    )
    public var catalogTemplate: CatalogTemplateKind = .base
    
    /// A user-provided value that is true if the documentation catalog should contain a tutorial template.
    ///
    /// Defaults to false.
    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Outputs a tutorial template as part of the documentation catalog",
            valueName: "include-tutorial"
        )
    )
    public var includeTutorial: Bool = false
}

extension CatalogTemplateKind: ExpressibleByArgument {}
