/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Markdown
@testable import SwiftDocC

class DiagnosticFileWriterTests: XCTestCase {
    
    func testWritesDiagnosticsWhenFinalized() throws {
        let diagnosticFileURL = try createTemporaryDirectory().appendingPathComponent("test-diagnostics.json")
        let writer = DiagnosticFileWriter(outputPath: diagnosticFileURL)
        
        let source = URL(string: "/path/to/file.md")!
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
            XCTAssertFalse(FileManager.default.fileExists(atPath: diagnosticFileURL.pathExtension))
        }
        
        do {
            let firstSolutionSummary = "Test first solution summary!"  // end with punctuation
            let secondSolutionSummary = "Test second solution summary" // end without punctuation
            let firstSolution = Solution(summary: firstSolutionSummary, replacements: [replacement])
            let secondSolution = Solution(summary: secondSolutionSummary, replacements: [])
            
            let diagnostic = Diagnostic(source: source, severity: .information, range: range, identifier: identifier, summary: summary, explanation: explanation)
            let problem = Problem(diagnostic: diagnostic, possibleSolutions: [firstSolution, secondSolution])
            
            writer.receive([problem])
            XCTAssertFalse(FileManager.default.fileExists(atPath: diagnosticFileURL.pathExtension))
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
            XCTAssertFalse(FileManager.default.fileExists(atPath: diagnosticFileURL.pathExtension))
        }
        
        try writer.flush()
        XCTAssert(FileManager.default.fileExists(atPath: diagnosticFileURL.path))
        
        let diagnosticFile = try JSONDecoder().decode(DiagnosticFile.self, from: Data(contentsOf: diagnosticFileURL))
        
        XCTAssertEqual(diagnosticFile.version, DiagnosticFile.currentVersion)
        XCTAssertEqual(diagnosticFile.diagnostics.count, 3)
        
        do {
            let diagnostic = try XCTUnwrap(diagnosticFile.diagnostics.first)
            XCTAssertEqual(diagnostic.source, source)
            XCTAssertEqual(diagnostic.range?.start.line, 1)
            XCTAssertEqual(diagnostic.range?.start.column, 8)
            XCTAssertEqual(diagnostic.range?.end.line, 10)
            XCTAssertEqual(diagnostic.range?.end.column, 21)
            XCTAssertEqual(diagnostic.severity, .warning)
            XCTAssertEqual(diagnostic.summary, summary)
            XCTAssertEqual(diagnostic.explanation, explanation)
            XCTAssertEqual(diagnostic.solutions.count, 1, "Found unexpected solutions: \(diagnostic.solutions)")
            let solution = try XCTUnwrap(diagnostic.solutions.first)
            XCTAssertEqual(solution.summary, solutionSummary)
            XCTAssertEqual(solution.replacements.count, 1, "Found unexpected replacements: \(solution.replacements)")
            let replacement = try XCTUnwrap(solution.replacements.first)
            XCTAssertEqual(replacement.text, "Replacement text")
            XCTAssertEqual(replacement.range.start.line, replacementRange.lowerBound.line)
            XCTAssertEqual(replacement.range.start.column, replacementRange.lowerBound.column)
            XCTAssertEqual(replacement.range.end.line, replacementRange.upperBound.line)
            XCTAssertEqual(replacement.range.end.column, replacementRange.upperBound.column)
            XCTAssertEqual(diagnostic.notes.count, 0, "Found unexpected notes: \(diagnostic.notes)")
        }
        
        do {
            let diagnostic = try XCTUnwrap(diagnosticFile.diagnostics.dropFirst().first)
            XCTAssertEqual(diagnostic.source, source)
            XCTAssertEqual(diagnostic.range?.start.line, 1)
            XCTAssertEqual(diagnostic.range?.start.column, 8)
            XCTAssertEqual(diagnostic.range?.end.line, 10)
            XCTAssertEqual(diagnostic.range?.end.column, 21)
            XCTAssertEqual(diagnostic.severity, .note)
            XCTAssertEqual(diagnostic.summary, summary)
            XCTAssertEqual(diagnostic.explanation, explanation)
            XCTAssertEqual(diagnostic.solutions.count, 2, "Found unexpected solutions: \(diagnostic.solutions)")
            do {
                let solution = try XCTUnwrap(diagnostic.solutions.first)
                XCTAssertEqual(solution.summary, "Test first solution summary!")
                XCTAssertEqual(solution.replacements.count, 1, "Found unexpected replacements: \(solution.replacements)")
                let replacement = try XCTUnwrap(solution.replacements.first)
                XCTAssertEqual(replacement.text, "Replacement text")
                XCTAssertEqual(replacement.range.start.line, replacementRange.lowerBound.line)
                XCTAssertEqual(replacement.range.start.column, replacementRange.lowerBound.column)
                XCTAssertEqual(replacement.range.end.line, replacementRange.upperBound.line)
                XCTAssertEqual(replacement.range.end.column, replacementRange.upperBound.column)
            }
            do {
                let solution = try XCTUnwrap(diagnostic.solutions.dropFirst().first)
                XCTAssertEqual(solution.summary, "Test second solution summary")
                XCTAssertEqual(solution.replacements.count, 0, "Found unexpected replacements: \(solution.replacements)")
            }
            XCTAssertEqual(diagnostic.notes.count, 0, "Found unexpected notes: \(diagnostic.notes)")
        }
        
        do {
            let diagnostic = try XCTUnwrap(diagnosticFile.diagnostics.dropFirst(2).first)
            XCTAssertEqual(diagnostic.source, source)
            XCTAssertEqual(diagnostic.range?.start.line, 1)
            XCTAssertEqual(diagnostic.range?.start.column, 8)
            XCTAssertEqual(diagnostic.range?.end.line, 10)
            XCTAssertEqual(diagnostic.range?.end.column, 21)
            XCTAssertEqual(diagnostic.severity, .error)
            XCTAssertEqual(diagnostic.summary, summary)
            XCTAssertEqual(diagnostic.explanation, explanation)
            XCTAssertEqual(diagnostic.solutions.count, 1, "Found unexpected solutions: \(diagnostic.solutions)")
            let solution = try XCTUnwrap(diagnostic.solutions.first)
            XCTAssertEqual(solution.summary, solutionSummary)
            XCTAssertEqual(solution.replacements.count, 2, "Found unexpected replacements: \(solution.replacements)")
            do {
                let replacement = try XCTUnwrap(solution.replacements.first)
                XCTAssertEqual(replacement.text, "ABC")
                XCTAssertEqual(replacement.range.start.line, firstInsertRange.lowerBound.line)
                XCTAssertEqual(replacement.range.start.column, firstInsertRange.lowerBound.column)
                XCTAssertEqual(replacement.range.end.line, firstInsertRange.upperBound.line)
                XCTAssertEqual(replacement.range.end.column, firstInsertRange.upperBound.column)
            }
            do {
                let replacement = try XCTUnwrap(solution.replacements.dropFirst().first)
                XCTAssertEqual(replacement.text, "abc")
                XCTAssertEqual(replacement.range.start.line, secondInsertRange.lowerBound.line)
                XCTAssertEqual(replacement.range.start.column, secondInsertRange.lowerBound.column)
                XCTAssertEqual(replacement.range.end.line, secondInsertRange.upperBound.line)
                XCTAssertEqual(replacement.range.end.column, secondInsertRange.upperBound.column)
            }
            XCTAssertEqual(diagnostic.notes.count, 0, "Found unexpected notes: \(diagnostic.notes)")
        }
    }
    
    func testVerifyVersionIsValidForDecoding() throws {
        let version1_0_0 = SemanticVersion(major: 1, minor: 0, patch: 0)
        let version1_0_1 = SemanticVersion(major: 1, minor: 0, patch: 1)
        let version1_2_3 = SemanticVersion(major: 1, minor: 2, patch: 3)
        let version2_0_0 = SemanticVersion(major: 2, minor: 0, patch: 0)
        
        XCTAssertNoThrow(try DiagnosticFile.verifyIsSupported(version1_0_0, current: version1_0_0))
        XCTAssertNoThrow(try DiagnosticFile.verifyIsSupported(version1_0_0, current: version1_0_1))
        XCTAssertNoThrow(try DiagnosticFile.verifyIsSupported(version1_0_0, current: version1_2_3))
        XCTAssertThrowsError(try DiagnosticFile.verifyIsSupported(version1_0_0, current: version2_0_0))
        
        XCTAssertNoThrow(try DiagnosticFile.verifyIsSupported(version1_0_1, current: version1_0_0))
        XCTAssertNoThrow(try DiagnosticFile.verifyIsSupported(version1_0_1, current: version1_0_1))
        XCTAssertNoThrow(try DiagnosticFile.verifyIsSupported(version1_0_1, current: version1_2_3))
        XCTAssertThrowsError(try DiagnosticFile.verifyIsSupported(version1_0_1, current: version2_0_0))
        
        XCTAssertNoThrow(try DiagnosticFile.verifyIsSupported(version1_2_3, current: version1_0_0))
        XCTAssertNoThrow(try DiagnosticFile.verifyIsSupported(version1_2_3, current: version1_0_1))
        XCTAssertNoThrow(try DiagnosticFile.verifyIsSupported(version1_2_3, current: version1_2_3))
        XCTAssertThrowsError(try DiagnosticFile.verifyIsSupported(version1_2_3, current: version2_0_0))
        
        XCTAssertThrowsError(try DiagnosticFile.verifyIsSupported(version2_0_0, current: version1_0_0))
        XCTAssertThrowsError(try DiagnosticFile.verifyIsSupported(version2_0_0, current: version1_0_1))
        XCTAssertThrowsError(try DiagnosticFile.verifyIsSupported(version2_0_0, current: version1_2_3))
        XCTAssertNoThrow(try DiagnosticFile.verifyIsSupported(version2_0_0, current: version2_0_0))
    }
}
