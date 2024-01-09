/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation
import SwiftDocC

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
    
    @Option(help: .hidden)
    @available(*, deprecated, renamed: "summaryLevel", message: "Use 'summaryLevel' instead. This deprecated API will be removed after 5.12 is released")
    public var level: DocumentationCoverageLevel = .none

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
    
    @Option(parsing: ArrayParsingStrategy.upToNextOption, help: .hidden)
    @available(*, deprecated, renamed: "symbolKindFilter", message: "Use 'symbolKindFilter' instead. This deprecated API will be removed after 5.12 is released")
    public var kinds: [DocumentationCoverageOptions.KindFilterOptions.BitFlagRepresentation] = []
    
    @available(*, deprecated) // This deprecation silences the access of the deprecated `level` and `kind` options.
    public mutating func validate() throws {
        Docc.Convert.warnAboutDeprecatedOptionIfNeeded("level", message: "Use '--coverage-summary-level' instead.")
        Docc.Convert.warnAboutDeprecatedOptionIfNeeded("kinds", message: "Use '--coverage-symbol-kind-filter' instead.")
        
        if !ProcessInfo.processInfo.arguments.contains("--coverage-summary-level"), level != .none {
            summaryLevel = level
        }
        symbolKindFilter.append(contentsOf: kinds)
    }
}

// SwiftDocCUtilities imports SwiftDocC. SwiftDocC does not link against ArgumentParser (because it isn't about CLI). We conform here because this is the first place that we can. We implement in DocC.
extension DocumentationCoverageLevel: ExpressibleByArgument {}
extension DocumentationCoverageOptions.KindFilterOptions.BitFlagRepresentation: ExpressibleByArgument {}

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
