/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import struct Markdown.SourceLocation

struct DiagnosticFile: Codable {
    var version: SemanticVersion
    var diagnostics: [Diagnostic]
    
    init(version: SemanticVersion = Self.currentVersion, problems: [Problem]) {
        self.version = version
        self.diagnostics = problems.map { .init($0) }
    }
    
    // This file format follows semantic versioning.
    // Breaking changes should increment the major version component.
    // Non breaking additions should increment the minor version.
    // Bug fixes should increment the patch version.
    static var currentVersion = SemanticVersion(major: 1, minor: 0, patch: 0, prerelease: nil, buildMetadata: nil)
    
    enum Error: Swift.Error {
        case unknownMajorVersion(found: SemanticVersion, latestKnown: SemanticVersion)
    }
    
    static func verifyIsSupported(_ version: SemanticVersion, current: SemanticVersion = Self.currentVersion) throws {
        guard version.major == current.major else {
            throw Error.unknownMajorVersion(found: version, latestKnown: current)
        }
    }
    
    struct Diagnostic: Codable {
        struct Range: Codable {
            var start: Location
            var end: Location
            struct Location: Codable {
                var line: Int
                var column: Int
            }
        }
        var source: URL?
        var range: Range?
        var severity: Severity
        var summary: String
        var explanation: String?
        var solutions: [Solution]
        struct Solution: Codable {
            var summary: String
            var replacements: [Replacement]
            struct Replacement: Codable {
                var range: Range
                var text: String
            }
        }
        var notes: [Note]
        struct Note: Codable {
            var source: URL?
            var range: Range?
            var message: String
        }
        enum Severity: String, Codable {
            case error, warning, note, remark
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case version, diagnostics
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(SemanticVersion.self, forKey: .version)
        try Self.verifyIsSupported(version)
        
        diagnostics = try container.decode([Diagnostic].self, forKey: .diagnostics)
    }
}

// MARK: Initialization

extension DiagnosticFile.Diagnostic {
    init(_ problem: Problem) {
        self.source      = problem.diagnostic.source
        self.range       = problem.diagnostic.range.map { .init($0) }
        self.severity    = .init(problem.diagnostic.severity)
        self.summary     = problem.diagnostic.summary
        self.explanation = problem.diagnostic.explanation
        self.solutions   = problem.possibleSolutions.map { .init($0) }
        self.notes       = problem.diagnostic.notes.map { .init($0) }
    }
}

extension DiagnosticFile.Diagnostic.Range {
    init(_ sourceRange: Range<SourceLocation>) {
        start = .init(sourceRange.lowerBound)
        end   = .init(sourceRange.upperBound)
    }
}

extension DiagnosticFile.Diagnostic.Range.Location {
    init(_ sourceLocation: SourceLocation) {
        self.line   = sourceLocation.line
        self.column = sourceLocation.column
    }
}

extension DiagnosticFile.Diagnostic.Solution {
    init(_ solution: Solution) {
        self.summary      = solution.summary
        self.replacements = solution.replacements.map { .init($0) }
    }
}

extension DiagnosticFile.Diagnostic.Solution.Replacement {
    init(_ replacement: Replacement) {
        self.range = .init(replacement.range)
        self.text  = replacement.replacement
    }
}

extension DiagnosticFile.Diagnostic.Note {
    init(_ note: DiagnosticNote) {
        self.source  = note.source
        self.range   = .init(note.range)
        self.message = note.message
    }
}

extension DiagnosticFile.Diagnostic.Severity {
    init(_ severity: DiagnosticSeverity) {
        switch severity {
        case .error:
            self = .error
        case .warning:
            self = .warning
        case .information, .hint:
            self = .note
        }
    }
}
