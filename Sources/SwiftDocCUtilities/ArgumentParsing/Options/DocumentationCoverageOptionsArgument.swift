/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import ArgumentParser
import Foundation
public import SwiftDocC

/// Resolves and validates the arguments needed to enable the documentation coverage feature.
///
/// These options are used by the ``Docc/Convert`` subcommand.
public struct DocumentationCoverageOptionsArgument: ParsableArguments {
    public init() {}

    fileprivate static let noCoverage = DocumentationCoverageOptionsArgument()

    // The way the '--experimental-documentation-coverage' flag and the '--coverage-summary-level' option work together
    // doesn't match the possible values for `DocumentationCoverageLevel`.
    
    @Flag(
        help: ArgumentHelp("Generate documentation coverage output.", discussion: """
        Detailed documentation coverage information will be written to 'documentation-coverage.json' in the output directory.
        """)
    )
    var experimentalDocumentationCoverage: Bool = false

    /// The desired level of documentation coverage. Options are `none`, `brief`, and `detailed`. The default is `.brief`
    @Option(
        name: .customLong("coverage-summary-level"),
        help: ArgumentHelp("The level of documentation coverage information to write on standard out.", discussion: """
        The '--coverage-summary-level' level has no impact on the information in the 'documentation-coverage.json' file.
        The supported coverage summary levels are 'brief' and 'detailed'.
        """,
        valueName: "symbol-kind")
    )
    var summaryLevel: DocumentationCoverageLevel = .brief

    var effectiveSummaryLevel: DocumentationCoverageLevel {
        guard experimentalDocumentationCoverage else {
            return .none
        }
        switch summaryLevel {
        case .detailed:
            return .detailed
        case .none, .brief:
            return .brief
        }
    }
    
    @Option(
        name: .customLong("coverage-symbol-kind-filter"),
        parsing: ArrayParsingStrategy.upToNextOption,
        help: ArgumentHelp("Filter documentation coverage to only analyze symbols of the specified symbol kinds.", discussion: """
        Specify a list of symbol kind values to filter the documentation coverage to only those types symbols.
        The supported symbol kind values are: \ 
        \(DocumentationCoverageOptions.KindFilterOptions.BitFlagRepresentation.allValueStrings.sorted().joined(separator: ", "))
        """,
        valueName: "symbol-kind")
    )
    public var symbolKindFilter: [DocumentationCoverageOptions.KindFilterOptions.BitFlagRepresentation] = []
    
    public mutating func validate() throws {
        Docc.Convert.warnAboutDeprecatedOptionIfNeeded("level", message: "Use '--coverage-summary-level' instead.")
        Docc.Convert.warnAboutDeprecatedOptionIfNeeded("kinds", message: "Use '--coverage-symbol-kind-filter' instead.")
    }
}

// Use fully-qualified types to silence a warning about retroactively conforming a type from another module to a new protocol (SE-0364).
// The `@retroactive` attribute is new in the Swift 6 compiler. The backwards compatible syntax for a retroactive conformance is fully-qualified types.
//
// It is safe to add a retroactively conformance here because the other module (SwiftDocC) is in the same package.
//
// These conforming types are defined in SwiftDocC and extended in SwiftDocCUtilities, because SwiftDocC doesn't link against ArgumentParse (since it isn't about CLI).
// We conform here because this is the first place that we can add the conformance. The implementation is in SwiftDocC.
extension SwiftDocC.DocumentationCoverageLevel: ArgumentParser.ExpressibleByArgument {}
extension SwiftDocC.DocumentationCoverageOptions.KindFilterOptions.BitFlagRepresentation: ArgumentParser.ExpressibleByArgument {}

extension DocumentationCoverageOptions {
    public init(from arguments: DocumentationCoverageOptionsArgument) {
        guard arguments.experimentalDocumentationCoverage else {
            self = .noCoverage
            return
        }
        
        self = DocumentationCoverageOptions(
            level: arguments.effectiveSummaryLevel,
            kindFilterOptions: .init(bitFlags: arguments.symbolKindFilter)
        )
    }
}
