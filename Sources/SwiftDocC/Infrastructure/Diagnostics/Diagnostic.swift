/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import SymbolKit

// Keeping this around for backwards compatibility with older clients (rdar://73049176)
@available(*, deprecated, message: "This typealias will be removed in the future. Use Diagnostic instead.")
public typealias BasicDiagnostic = Diagnostic

/// A diagnostic explains a problem or issue that needs the end-user's attention.
public struct Diagnostic: DescribedError {

    /// The origin of the diagnostic, such as a file or process.
    public var source: URL?

    /// The diagnostic's severity.
    public var severity: DiagnosticSeverity

    /// The diagnostic's source range if the diagnostic originated at a source document, else `nil`.
    public var range: SourceRange?

    /// A unique reverse-DNS-style string identifier used for looking up explanations for diagnostics.
    ///
    /// ## Example
    ///
    /// `org.swift.docc.SummaryContainsLink`
    public var identifier: String

    /// Provides the short, localized abstract provided by ``localizedExplanation`` in plain text if an
    /// explanation is available.
    ///
    /// At a bare minimum, all diagnostics must have at least one paragraph or sentence describing what the diagnostic is.
    public var localizedSummary: String 

    /// Provides a markup document for this diagnostic in the end-user's most preferred language, the base language
    /// if one isn't available, or `nil` if no explanations are provided for this diagnostic's identifier.
    ///
    /// - Note: All diagnostics *must have* an explanation. If a diagnostic can't be explained in plain language
    /// and easily understood by the reader, it should not be shown.
    ///
    /// An explanation should have at least the following items:
    ///
    /// - Document
    ///  - Abstract: A summary paragraph; one or two sentences.
    ///  - Discussion: A discussion of the situation and why it's interesting or a problem for the end-user.
    ///     This discussion should implicitly justify the diagnostic's existence.
    ///  - Heading, level 2, text: "Example"
    ///  - Problem Example: Show an example of the problematic situation and highlight important areas.
    ///  - Heading, level 2, text: "Solution"
    ///  - Solution: Explain what the end-user needs to do to correct the problem in plain language.
    ///  - Solution Example: Show the *Problem Example* as corrected and highlight the changes made.
    public var localizedExplanation: String?

    /// Extra notes to tack onto the editor for additional information.
    ///
    /// For example, if you're diagnosing the fact that there are multiple *X* in a document, you might diagnose on
    /// the second *X* while adding a note on the first *X* to note that it was the first occurrence.
    public var notes = [DiagnosticNote]()
    
    public init(
        source: URL? = nil,
        severity: DiagnosticSeverity,
        range: SourceRange? = nil,
        identifier: String,
        summary: String,
        explanation: String? = nil,
        notes: [DiagnosticNote] = []
    ) {
        self.source = source
        self.severity = severity
        self.range = range
        self.identifier = identifier
        self.localizedSummary = summary
        self.localizedExplanation = explanation
        self.notes = notes
    }
}

public extension Diagnostic {

    /// Offsets the diagnostic using a certain SymbolKit `SourceRange`.
    ///
    /// Useful when validating a doc comment that needs to be projected in its containing file "space".
    mutating func offsetWithRange(_ docRange: SymbolGraph.LineList.SourceRange) {
        // If there is no location information in the source diagnostic, the diagnostic might be removed for safety reasons.
        range?.offsetWithRange(docRange)
        
    }

    var localizedDescription: String {
        return DiagnosticConsoleWriter.formattedDescriptionFor(self)
    }

    var errorDescription: String {
        return DiagnosticConsoleWriter.formattedDescriptionFor(self)
    }
}

