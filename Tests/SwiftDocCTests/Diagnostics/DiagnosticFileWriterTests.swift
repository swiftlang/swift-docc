/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Foundation
import Markdown
@testable import SwiftDocC
import DocCTestUtilities

struct DiagnosticFileWriterTests {
    @Test
    func writesFileWhenOnlyWhenFinalized() throws {
        let testFileSystem = try TestFileSystem(folders: [
            Folder(name: "path", content: [
                Folder(name: "to", content: [])
            ])
        ])
        
        let diagnosticFileURL = URL(fileURLWithPath: "/path/to/some-custom-diagnostics-file.json")
        let writer = DiagnosticFileWriter(outputPath: diagnosticFileURL, fileManager: testFileSystem)
        
        let source = URL(fileURLWithPath: "/path/to/file.md")
        let range = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 10, column: 21, source: source)
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let solutionSummary = "Test solution summary"
        let explanation = "Test diagnostic explanation."
        
        let replacementRange = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 1, column: 24, source: source)
        let replacement = Replacement(range: replacementRange, replacement: "Replacement text")
        
        do {
            let solution = Solution(summary: solutionSummary, replacements: [replacement])
            let diagnostic = Diagnostic(source: source, severity: .warning, range: range, identifier: identifier, summary: summary, explanation: explanation)
            let problem = Problem(diagnostic: diagnostic, possibleSolutions: [solution])
            
            writer.receive([problem])
            #expect(testFileSystem.fileExists(atPath: diagnosticFileURL.path) == false)
        }
        
        do {
            let firstSolutionSummary = "Test first solution summary!"  // end with punctuation
            let secondSolutionSummary = "Test second solution summary" // end without punctuation
            let firstSolution = Solution(summary: firstSolutionSummary, replacements: [replacement])
            let secondSolution = Solution(summary: secondSolutionSummary, replacements: [])
            
            let diagnostic = Diagnostic(source: source, severity: .information, range: range, identifier: identifier, summary: summary, explanation: explanation)
            let problem = Problem(diagnostic: diagnostic, possibleSolutions: [firstSolution, secondSolution])
            
            writer.receive([problem])
            #expect(testFileSystem.fileExists(atPath: diagnosticFileURL.path) == false)
        }
        
        let firstInsertRange = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 1, column: 8, source: source)
        let secondInsertRange = SourceLocation(line: 1, column: 14, source: source)..<SourceLocation(line: 1, column: 14, source: source)
        let firstReplacement = Replacement(range: firstInsertRange, replacement: "ABC")
        let secondReplacement = Replacement(range: secondInsertRange, replacement: "abc")
        
        do {
            let solution = Solution(summary: solutionSummary, replacements: [firstReplacement, secondReplacement])
            
            let diagnostic = Diagnostic(source: source, severity: .error, range: range, identifier: identifier, summary: summary, explanation: explanation)
            let problem = Problem(diagnostic: diagnostic, possibleSolutions: [solution])
            
            writer.receive([problem])
            #expect(testFileSystem.fileExists(atPath: diagnosticFileURL.path) == false)
        }
        
        try writer.flush()
        #expect(testFileSystem.fileExists(atPath: diagnosticFileURL.path))
        
        let diagnosticFile = try JSONDecoder().decode(DiagnosticFile.self, from: testFileSystem.contents(of: diagnosticFileURL))
        
        #expect(diagnosticFile.version == DiagnosticFile.currentVersion)
        #expect(diagnosticFile.diagnostics.count == 3)
        
        do {
            let diagnostic = try #require(diagnosticFile.diagnostics.first)
            #expect(diagnostic.source == source)
            #expect(diagnostic.range?.start.line == 1)
            #expect(diagnostic.range?.start.column == 8)
            #expect(diagnostic.range?.end.line == 10)
            #expect(diagnostic.range?.end.column == 21)
            #expect(diagnostic.severity == .warning)
            #expect(diagnostic.summary == summary)
            #expect(diagnostic.explanation == explanation)
            #expect(diagnostic.solutions.count == 1, "Found unexpected solutions: \(diagnostic.solutions)")
            let solution = try #require(diagnostic.solutions.first)
            #expect(solution.summary == solutionSummary)
            #expect(solution.replacements.count == 1, "Found unexpected replacements: \(solution.replacements)")
            let replacement = try #require(solution.replacements.first)
            #expect(replacement.text == "Replacement text")
            #expect(replacement.range.start.line == replacementRange.lowerBound.line)
            #expect(replacement.range.start.column == replacementRange.lowerBound.column)
            #expect(replacement.range.end.line == replacementRange.upperBound.line)
            #expect(replacement.range.end.column == replacementRange.upperBound.column)
            #expect(diagnostic.notes.count == 0, "Found unexpected notes: \(diagnostic.notes)")
        }
        
        do {
            let diagnostic = try #require(diagnosticFile.diagnostics.dropFirst().first)
            #expect(diagnostic.source == source)
            #expect(diagnostic.range?.start.line == 1)
            #expect(diagnostic.range?.start.column == 8)
            #expect(diagnostic.range?.end.line == 10)
            #expect(diagnostic.range?.end.column == 21)
            #expect(diagnostic.severity == .note)
            #expect(diagnostic.summary == summary)
            #expect(diagnostic.explanation == explanation)
            #expect(diagnostic.solutions.count == 2, "Found unexpected solutions: \(diagnostic.solutions)")
            do {
                let solution = try #require(diagnostic.solutions.first)
                #expect(solution.summary == "Test first solution summary!")
                #expect(solution.replacements.count == 1, "Found unexpected replacements: \(solution.replacements)")
                let replacement = try #require(solution.replacements.first)
                #expect(replacement.text == "Replacement text")
                #expect(replacement.range.start.line == replacementRange.lowerBound.line)
                #expect(replacement.range.start.column == replacementRange.lowerBound.column)
                #expect(replacement.range.end.line == replacementRange.upperBound.line)
                #expect(replacement.range.end.column == replacementRange.upperBound.column)
            }
            do {
                let solution = try #require(diagnostic.solutions.dropFirst().first)
                #expect(solution.summary == "Test second solution summary")
                #expect(solution.replacements.count == 0, "Found unexpected replacements: \(solution.replacements)")
            }
            #expect(diagnostic.notes.count == 0, "Found unexpected notes: \(diagnostic.notes)")
        }
        
        do {
            let diagnostic = try #require(diagnosticFile.diagnostics.dropFirst(2).first)
            #expect(diagnostic.source == source)
            #expect(diagnostic.range?.start.line == 1)
            #expect(diagnostic.range?.start.column == 8)
            #expect(diagnostic.range?.end.line == 10)
            #expect(diagnostic.range?.end.column == 21)
            #expect(diagnostic.severity == .error)
            #expect(diagnostic.summary == summary)
            #expect(diagnostic.explanation == explanation)
            #expect(diagnostic.solutions.count == 1, "Found unexpected solutions: \(diagnostic.solutions)")
            let solution = try #require(diagnostic.solutions.first)
            #expect(solution.summary == solutionSummary)
            #expect(solution.replacements.count == 2, "Found unexpected replacements: \(solution.replacements)")
            do {
                let replacement = try #require(solution.replacements.first)
                #expect(replacement.text == "ABC")
                #expect(replacement.range.start.line == firstInsertRange.lowerBound.line)
                #expect(replacement.range.start.column == firstInsertRange.lowerBound.column)
                #expect(replacement.range.end.line == firstInsertRange.upperBound.line)
                #expect(replacement.range.end.column == firstInsertRange.upperBound.column)
            }
            do {
                let replacement = try #require(solution.replacements.dropFirst().first)
                #expect(replacement.text == "abc")
                #expect(replacement.range.start.line == secondInsertRange.lowerBound.line)
                #expect(replacement.range.start.column == secondInsertRange.lowerBound.column)
                #expect(replacement.range.end.line == secondInsertRange.upperBound.line)
                #expect(replacement.range.end.column == secondInsertRange.upperBound.column)
            }
            #expect(diagnostic.notes.count == 0, "Found unexpected notes: \(diagnostic.notes)")
        }
    }
    
    @Test
    func throwsErrorAboutUnsupportedVersionForDecoding() throws {
        let version1_0_0 = SemanticVersion(major: 1, minor: 0, patch: 0)
        let version1_0_1 = SemanticVersion(major: 1, minor: 0, patch: 1)
        let version1_2_3 = SemanticVersion(major: 1, minor: 2, patch: 3)
        let version2_0_0 = SemanticVersion(major: 2, minor: 0, patch: 0)
        
        try DiagnosticFile.verifyIsSupported(version1_0_0, current: version1_0_0)
        try DiagnosticFile.verifyIsSupported(version1_0_0, current: version1_0_1)
        try DiagnosticFile.verifyIsSupported(version1_0_0, current: version1_2_3)
        #expect(throws: DiagnosticFile.Error.self) { try DiagnosticFile.verifyIsSupported(version1_0_0, current: version2_0_0) }
        
        try DiagnosticFile.verifyIsSupported(version1_0_1, current: version1_0_0)
        try DiagnosticFile.verifyIsSupported(version1_0_1, current: version1_0_1)
        try DiagnosticFile.verifyIsSupported(version1_0_1, current: version1_2_3)
        #expect(throws: DiagnosticFile.Error.self) { try DiagnosticFile.verifyIsSupported(version1_0_1, current: version2_0_0) }
        
        try DiagnosticFile.verifyIsSupported(version1_2_3, current: version1_0_0)
        try DiagnosticFile.verifyIsSupported(version1_2_3, current: version1_0_1)
        try DiagnosticFile.verifyIsSupported(version1_2_3, current: version1_2_3)
        #expect(throws: DiagnosticFile.Error.self) { try DiagnosticFile.verifyIsSupported(version1_2_3, current: version2_0_0) }
        
        #expect(throws: DiagnosticFile.Error.self) { try DiagnosticFile.verifyIsSupported(version2_0_0, current: version1_0_0) }
        #expect(throws: DiagnosticFile.Error.self) { try DiagnosticFile.verifyIsSupported(version2_0_0, current: version1_0_1) }
        #expect(throws: DiagnosticFile.Error.self) { try DiagnosticFile.verifyIsSupported(version2_0_0, current: version1_2_3) }
        try DiagnosticFile.verifyIsSupported(version2_0_0, current: version2_0_0)
    }
}
