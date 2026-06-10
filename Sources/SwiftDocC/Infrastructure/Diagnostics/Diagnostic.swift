/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown
public import SymbolKit

/// A diagnostic explains a problem or issue that needs the end-user's attention.
public struct Diagnostic {
    /// The origin of the diagnostic, such as a file or process.
    public var source: URL?

    /// The diagnostic's severity.
    public var severity: DiagnosticSeverity

    /// The diagnostic's source range if the diagnostic originated at a source document, else `nil`.
    public var range: SourceRange?

    /// An opaque identifier that diagnostic consumers and tools can use to identify specific types of diagnostics.
    public var identifier: String
    
    /// A unique string that identifies a group of diagnostics whose severity can be controlled by passing `--Werror` and `--Wwarning` flags to `docc`.
    public var groupIdentifier: String?

    /// A brief summary that describe the problem or issue.
    public var summary: String
    
    /// Additional details that explain the problem or issue to the end-user in plain language.
    public var explanation: String?

    /// Extra notes to tack onto the editor for additional information.
    ///
    /// For example, if you're diagnosing the fact that there are multiple *X* in a document, you might diagnose on
    /// the second *X* while adding a note on the first *X* to note that it was the first occurrence.
    public var notes: [Note]
    
    /// A list of possible solutions that the end-use can take to resolve the problem or issue.
    public var solutions: [Solution]
    
    public init(
        source: URL? = nil,
        severity: DiagnosticSeverity,
        range: SourceRange? = nil,
        identifier: String,
        groupIdentifier: String? = nil,
        summary: String,
        explanation: String? = nil,
        notes: [Note] = [],
        solutions: [Solution] = []
    ) {
        self.source = source
        self.severity = severity
        self.range = range
        self.identifier = identifier
        self.groupIdentifier = groupIdentifier
        self.summary = summary
        self.explanation = explanation
        self.notes = notes
        self.solutions = solutions
    }
}

public extension Diagnostic {

    /// Offsets the diagnostic using a certain SymbolKit `SourceRange`.
    ///
    /// Useful when validating a doc comment that needs to be projected in its containing file "space".
    mutating func offsetWithRange(_ docRange: SymbolGraph.LineList.SourceRange) {
        // If there is no location information in the source diagnostic, the diagnostic might be removed for safety reasons.
        range?.offsetWithRange(docRange)
        
        for solutionIndex in solutions.indices {
            for replacementIndex in solutions[solutionIndex].replacements.indices {
                solutions[solutionIndex].replacements[replacementIndex].offsetWithRange(docRange)
            }
        }
    }
    
    /// Returns the diagnostic with its range offset by the given documentation comment range.
    func withRangeOffset(by docRange: SymbolGraph.LineList.SourceRange) -> Self {
        var diagnostic = self
        diagnostic.offsetWithRange(docRange)
        return diagnostic
    }
}

extension Sequence<Diagnostic> {
    /// A Boolean value that indicates if any of the diagnostics has an`error` severity.
    package var containsAnyError: Bool {
        contains { $0.severity == .error }
    }
}
