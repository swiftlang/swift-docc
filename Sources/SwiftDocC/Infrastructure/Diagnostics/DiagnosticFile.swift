/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import struct Markdown.SourceLocation

struct DiagnosticFile: Codable {
    var version: SemanticVersion
    var diagnostics: [Diagnostic]
    
    init(version: SemanticVersion = Self.currentVersion, _ diagnostics: [SwiftDocC.Diagnostic]) {
        self.version = version
        self.diagnostics = diagnostics.map { .init($0) }
    }
    
    // This file format follows semantic versioning.
    // Breaking changes should increment the major version component.
    // Non breaking additions should increment the minor version.
    // Bug fixes should increment the patch version.
    static var currentVersion = SemanticVersion(major: 1, minor: 1, patch: 0, prerelease: nil, buildMetadata: nil)
    
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
        var id: String
        var groupID: String?
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
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(SemanticVersion.self, forKey: .version)
        try Self.verifyIsSupported(version)
        
        diagnostics = try container.decode([Diagnostic].self, forKey: .diagnostics)
    }
}

// MARK: Initialization

extension DiagnosticFile.Diagnostic {
    init(_ diagnostic: Diagnostic) {
        self.id          = diagnostic.identifier
        self.groupID     = diagnostic.groupIdentifier
        self.source      = diagnostic.source
        self.range       = diagnostic.range.map { .init($0) }
        self.severity    = .init(diagnostic.severity)
        self.summary     = diagnostic.summary
        self.explanation = diagnostic.explanation
        self.solutions   = diagnostic.solutions.map { .init($0) }
        self.notes       = diagnostic.notes.map { .init($0) }
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
    init(_ replacement: Solution.Replacement) {
        self.range = .init(replacement.range)
        self.text  = replacement.replacement
    }
}

extension DiagnosticFile.Diagnostic.Note {
    init(_ note: Diagnostic.Note) {
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
