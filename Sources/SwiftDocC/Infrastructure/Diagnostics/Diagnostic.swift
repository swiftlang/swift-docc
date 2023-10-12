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
public struct Diagnostic {
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

    /// A brief summary that describe the problem or issue.
    public var summary: String
    
    @available(*, deprecated, renamed: "summary")
    public var localizedSummary: String {
        return summary
    }

    /// Additional details that explain the problem or issue to the end-user in plain language.
    public var explanation: String?
    
    @available(*, deprecated, renamed: "explanation")
    public var localizedExplanation: String? {
        return explanation
    }

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
        self.summary = summary
        self.explanation = explanation
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
}

// MARK: Deprecated

@available(*, deprecated, message: "Use 'DiagnosticConsoleWriter.formattedDescription(for:options:)' instead.")
extension Diagnostic: DescribedError {
    @available(*, deprecated, message: "Use 'DiagnosticConsoleWriter.formattedDescription(for:options:)' instead.")
    var localizedDescription: String {
        return DiagnosticConsoleWriter.formattedDescription(for: self)
    }

    @available(*, deprecated, message: "Use 'DiagnosticConsoleWriter.formattedDescription(for:options:)' instead.")
    public var errorDescription: String {
        return DiagnosticConsoleWriter.formattedDescription(for: self)
    }
}
