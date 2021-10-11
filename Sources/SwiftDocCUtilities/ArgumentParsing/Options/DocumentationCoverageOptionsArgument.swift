/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
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

    static var noCoverage: DocumentationCoverageOptionsArgument {
        var value = DocumentationCoverageOptionsArgument()
        value.level = .none
        return value
    }

    public init() { }

    @Flag(help: """
                Generates documentation coverage output. (currently Experimental)
                """)
    var experimentalDocumentationCoverage: Bool = false

    /// The desired level of documentation coverage. Options are `none`, `brief`, and `detailed`. The default is `none`
    @Option(
        name: .long, // TODO: `.customLong("level", withSingleDash: true)` doesn't work with `swift run docc …`
        parsing: .next,
        help: ArgumentHelp(
            "Desired level of documentation coverage output."))
    public var level: DocumentationCoverageLevel = .none

    @Option(
        name: .long,
        parsing: ArrayParsingStrategy.upToNextOption,
        help: ArgumentHelp(
            "The kinds of entities to filter generated documentation for.",
            valueName: "kind"))
    public var kinds: [DocumentationCoverageOptions.KindFilterOptions.BitFlagRepresentation] = []

}

// SwiftDocCUtilities imports SwiftDocC. SwiftDocC does not link against ArgumentParser (because it isn't about CLI). We conform here because this is the first place that we can. We implement in DocC.
extension DocumentationCoverageLevel: ExpressibleByArgument {}
extension DocumentationCoverageOptions.KindFilterOptions.BitFlagRepresentation: ExpressibleByArgument {}

extension DocumentationCoverageOptions {
    public init(from argumentInstance: DocumentationCoverageOptionsArgument) {

        if argumentInstance.experimentalDocumentationCoverage {
            self = DocumentationCoverageOptions(
                level: argumentInstance.level,
                kindFilterOptions: DocumentationCoverageOptions.KindFilterOptions(bitFlags: argumentInstance.kinds))
        } else {
            self = .noCoverage
        }
    }
}
