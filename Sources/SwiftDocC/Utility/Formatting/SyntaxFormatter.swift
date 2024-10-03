/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SwiftFormat

/// Configurable formatter that can be used to format the way that a string of
/// Swift source code appears using the `swift-format` library.
struct SyntaxFormatter {
    var configuration: SwiftFormat.Configuration

    /// Initializes the formatter with a default configuration.
    init() {
        let indentWidth = 4

        configuration = SwiftFormat.Configuration()
        configuration.tabWidth = indentWidth
        configuration.indentation = .spaces(indentWidth)
        configuration.lineBreakBeforeEachArgument = true
        configuration.lineBreakBeforeEachGenericRequirement = true
        //configuration.lineBreakBetweenDeclarationAttributes = true
    }

    /// Initializes the formatter with the provided configuration.
    init(configuration: SwiftFormat.Configuration) {
        self.configuration = configuration
    }

    /// Format the given string of Swift source code and return a version of it
    /// formatted using `swift-format`.
    ///
    /// - Parameter source: The string of Swift source code.
    /// - Returns: The formatted Swift source code.
    /// - Throws: An error if `swift-format` encountered an error.
    func format(source: String) throws -> String {
        var formatted = ""

        try SwiftFormatter(configuration: configuration).format(
            source: source,
            assumingFileURL: nil,
            selection: .infinite,
            to: &formatted
        )

        return formatted
    }
}
