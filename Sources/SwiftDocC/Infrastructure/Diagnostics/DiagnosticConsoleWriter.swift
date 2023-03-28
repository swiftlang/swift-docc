/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// Writes diagnostic messages to a text output stream.
///
/// By default, this type writes to `stderr`.
public final class DiagnosticConsoleWriter: DiagnosticFormattingConsumer {

    var outputStream: TextOutputStream
    public var formattingOptions: DiagnosticFormattingOptions
    private var diagnosticFormatter: DiagnosticConsoleFormatter
    private var problems: [Problem] = []

    /// Creates a new instance of this class with the provided output stream and filter level.
    /// - Parameter stream: The output stream to which this instance will write.
    /// - Parameter filterLevel: Determines what diagnostics should be printed. This filter level is inclusive, i.e. if a level of ``DiagnosticSeverity/information`` is specified, diagnostics with a severity up to and including `.information` will be printed.
    @available(*, deprecated, message: "Use init(_:formattingOptions:) instead")
    public convenience init(_ stream: TextOutputStream = LogHandle.standardError, filterLevel: DiagnosticSeverity = .warning) {
        self.init(stream, formattingOptions: [], baseURL: nil)
    }

    /// Creates a new instance of this class with the provided output stream.
    /// - Parameter stream: The output stream to which this instance will write.
    public init(
        _ stream: TextOutputStream = LogHandle.standardError,
        formattingOptions options: DiagnosticFormattingOptions = [],
        baseURL: URL? = nil
    ) {
        outputStream = stream
        formattingOptions = options
        diagnosticFormatter = Self.makeDiagnosticFormatter(options, baseURL: baseURL)
    }

    public func receive(_ problems: [Problem]) {
        if formattingOptions.contains(.formatConsoleOutputForTools) {
            // Add a newline after each formatter description, including the last one.
            let text = problems.map { diagnosticFormatter.formattedDescription(for: $0).appending("\n") }.joined()
            outputStream.write(text)
        } else {
            self.problems.append(contentsOf: problems)
        }
    }
    
    public func finalize() throws {
        if formattingOptions.contains(.formatConsoleOutputForTools) {
            // For tools, the console writer writes each diagnostic as they are received.
        } else {
            let text = self.diagnosticFormatter.formattedDescription(for: problems)
            outputStream.write(text)
        }
    }
    
    private static func makeDiagnosticFormatter(
        _ options: DiagnosticFormattingOptions,
        baseURL: URL?
    ) -> DiagnosticConsoleFormatter {
        if options.contains(.formatConsoleOutputForTools) {
            return IDEDiagnosticConsoleFormatter(options: options)
        } else {
            return DefaultDiagnosticConsoleFormatter(baseUrl: baseURL, options: options)
        }
    }
}

// MARK: Formatted descriptions

extension DiagnosticConsoleWriter {
    
    public static func formattedDescription<Problems>(for problems: Problems, options: DiagnosticFormattingOptions = []) -> String where Problems: Sequence, Problems.Element == Problem {
        return problems.map { formattedDescription(for: $0, options: options) }.joined(separator: "\n")
    }
    
    public static func formattedDescription(for problem: Problem, options: DiagnosticFormattingOptions = []) -> String {
        let diagnosticFormatter = makeDiagnosticFormatter(options, baseURL: nil)
        return diagnosticFormatter.formattedDescription(for: problem)
    }
    
    public static func formattedDescription(for diagnostic: Diagnostic, options: DiagnosticFormattingOptions = []) -> String {
        let diagnosticFormatter = makeDiagnosticFormatter(options, baseURL: nil)
        return diagnosticFormatter.formattedDescription(for: diagnostic)
    }
}

protocol DiagnosticConsoleFormatter {
    var options: DiagnosticFormattingOptions { get set }
    
    func formattedDescription<Problems>(for problems: Problems) -> String where Problems: Sequence, Problems.Element == Problem
    func formattedDescription(for problem: Problem) -> String
    func formattedDescription(for diagnostic: Diagnostic) -> String
}

extension DiagnosticConsoleFormatter {
    func formattedDescription<Problems>(for problems: Problems) -> String where Problems: Sequence, Problems.Element == Problem {
        return problems.map { formattedDescription(for: $0) }.joined(separator: "\n")
    }
}

// MARK: IDE formatting

struct IDEDiagnosticConsoleFormatter: DiagnosticConsoleFormatter {
    var options: DiagnosticFormattingOptions
    
    func formattedDescription(for problem: Problem) -> String {
        guard let source = problem.diagnostic.source else {
            return formattedDescription(for: problem.diagnostic)
        }
        
        var description = formattedDiagnosticSummary(problem.diagnostic)
        
        // Since solution summaries aren't included in the fixit string we include them in the diagnostic
        // summary so that the solution information isn't dropped.
        
        if !problem.possibleSolutions.isEmpty, description.last?.isPunctuation == false {
            description += "."
        }
        for solution in problem.possibleSolutions {
            description += " \(solution.summary)"
            if description.last?.isPunctuation == false {
                description += "."
            }
        }
        
        // Add explanations and notes
        description += formattedDiagnosticDetails(problem.diagnostic)
        
        // Only one fixit (but multiple related replacements) can be a presented with each diagnostic
        if problem.possibleSolutions.count == 1, let solution = problem.possibleSolutions.first {
            description += solution.replacements.reduce(into: "") { accumulation, replacement in
                let range = replacement.range
                accumulation +=  "\n\(source.path):\(range.lowerBound.line):\(range.lowerBound.column)-\(range.upperBound.line):\(range.upperBound.column): fixit: \(replacement.replacement)"
            }
        }

        return description
    }
    
    public func formattedDescription(for diagnostic: Diagnostic) -> String {
        return formattedDiagnosticSummary(diagnostic) + formattedDiagnosticDetails(diagnostic)
    }
    
    private func formattedDiagnosticSummary(_ diagnostic: Diagnostic) -> String {
        var result = ""

        if let range = diagnostic.range, let url = diagnostic.source {
            result += "\(url.path):\(range.lowerBound.line):\(range.lowerBound.column): "
        } else if let url = diagnostic.source {
            result += "\(url.path): "
        }
        
        result += "\(diagnostic.severity): \(diagnostic.summary)"
        
        return result
    }
    
    private func formattedDiagnosticDetails(_ diagnostic: Diagnostic) -> String {
        var result = ""

        if let explanation = diagnostic.explanation {
            result += "\n\(explanation)"
        }

        if !diagnostic.notes.isEmpty {
            result += "\n"
            result += diagnostic.notes.map { formattedDescription(for: $0) }.joined(separator: "\n")
        }
        
        return result
    }
    
    private func formattedDescription(for note: DiagnosticNote) -> String {
        let location = "\(note.source.path):\(note.range.lowerBound.line):\(note.range.lowerBound.column)"
        return "\(location): note: \(note.message)"
    }
}

// MARK: Default formatting

final class DefaultDiagnosticConsoleFormatter: DiagnosticConsoleFormatter {
    var options: DiagnosticFormattingOptions
    private let baseUrl: URL?
    private var sourceLines: [URL: [String]] = [:]
    
    private static let contextSize = 2
    
    init(
        baseUrl: URL?,
        options: DiagnosticFormattingOptions
    ) {
        self.baseUrl = baseUrl
        self.options = options
    }
    
    func formattedDescription<Problems>(for problems: Problems) -> String where Problems: Sequence, Problems.Element == Problem {
        let sortedProblems = problems.sorted { lhs, rhs in
            guard let lhsSource = lhs.diagnostic.source,
                  let rhsSource = rhs.diagnostic.source
            else { return lhs.diagnostic.source  == nil }
            
            guard let lhsRange = lhs.diagnostic.range,
                  let rhsRange = rhs.diagnostic.range
            else { return lhsSource.path < rhsSource.path }
            
            if lhsSource.path == rhsSource.path {
                return lhsRange.lowerBound < rhsRange.lowerBound
            } else {
                return lhsSource.path < rhsSource.path
            }
        }

        return sortedProblems.map { formattedDescription(for: $0) }.joined(separator: "\n\n")
    }

    func formattedDescription(for problem: Problem) -> String {
        formattedDiagnosticsSummary(for: problem.diagnostic) +
        formattedDiagnosticDetails(for: problem.diagnostic) +
        formattedDiagnosticSource(for: problem.diagnostic, with: problem.possibleSolutions)
    }

    func formattedDescription(for diagnostic: Diagnostic) -> String {
        formattedDiagnosticsSummary(for: diagnostic) +
        formattedDiagnosticDetails(for: diagnostic) +
        formattedDiagnosticSource(for: diagnostic, with: [])
    }
}

extension DefaultDiagnosticConsoleFormatter {
    private func formattedDiagnosticsSummary(for diagnostic: Diagnostic) -> String {
        let ansiAnnotation = diagnostic.severity.ansiAnnotation
        return ansiAnnotation.applied(to: diagnostic.severity.description + ": " + diagnostic.summary)
    }
    
    private func formattedDiagnosticDetails(for diagnostic: Diagnostic) -> String {
        var result = ""
        if let explanation = diagnostic.explanation {
            result.append("\n\(explanation)")
        }
        
        if !diagnostic.notes.isEmpty {
            let formattedNotes = diagnostic.notes
                .map { note in
                    let location = "\(formattedSourcePath(note.source)):\(note.range.lowerBound.line):\(note.range.lowerBound.column)"
                    return "\(location): \(note.message)"
                }
                .joined(separator: "\n")
            result.append("\n\(formattedNotes)")
        }
        
        return result
    }
    
    private func formattedDiagnosticSource(
        for diagnostic: Diagnostic,
        with solutions: [Solution]
    ) -> String {
        var result = ""
        
        guard let url = diagnostic.source
        else { return "" }
        
        guard let diagnosticRange = diagnostic.range
        else { return "\n--> \(formattedSourcePath(url))" }
        
        let sourceLines = readSourceLines(url)

        guard !sourceLines.isEmpty
        else {
            return "\n--> \(formattedSourcePath(url)):\(diagnosticRange.lowerBound.line):\(diagnosticRange.lowerBound.column)-\(diagnosticRange.upperBound.line):\(diagnosticRange.upperBound.column)"
        }
        
        // A range containing the source lines and some surrounding context.
        let sourceRange = Range(
            uncheckedBounds: (
                lower: max(1, diagnosticRange.lowerBound.line - Self.contextSize) - 1,
                upper: min(sourceLines.count, diagnosticRange.upperBound.line + Self.contextSize)
            )
        )
        let maxLinePrefixWidth = String(sourceRange.upperBound).count
        
        var suggestionsPerLocation = [SourceLocation: [String]]()
        for solution in solutions {
            // Solutions that requires multiple or zero replacements
            // will be shown at the beginning of the diagnostic range. 
            let location: SourceLocation
            if solution.replacements.count == 1 {
                location = solution.replacements.first!.range.lowerBound
            } else {
                location = diagnosticRange.lowerBound
            }

            suggestionsPerLocation[location, default: []].append(solution.summary)
        }

        result.append("\n\(String(repeating: " ", count: maxLinePrefixWidth))--> ")
        result.append(        "\(formattedSourcePath(url)):\(diagnosticRange.lowerBound.line):\(diagnosticRange.lowerBound.column)-\(diagnosticRange.upperBound.line):\(diagnosticRange.upperBound.column)"
        )

        for (sourceLineIndex, sourceLine) in sourceLines[sourceRange].enumerated() {
            let lineNumber = sourceLineIndex + sourceRange.lowerBound + 1
            let linePrefix = "\(lineNumber)".padding(toLength: maxLinePrefixWidth, withPad: " ", startingAt: 0)

            let highlightedSource = highlightSource(
                sourceLine: sourceLine,
                lineNumber: lineNumber,
                range: diagnosticRange
            )

            result.append("\n\(linePrefix) | \(highlightedSource)")

            var columnsWithSuggestions = Set<Int>()
            var suggestionsPerColumn = [(Int, [String])]()

            for (location, suggestions) in suggestionsPerLocation {
                if location.line == lineNumber {
                    suggestionsPerColumn.append((location.column, suggestions))
                    columnsWithSuggestions.insert(location.column)
                }
            }

            let suggestionAnsiAnnotation = ANSIAnnotation.sourceSuggestionHighlight
            let suggestionLinePrefix = String(repeating: " ", count: maxLinePrefixWidth) + " |"

            for (columnNumber, columnSuggestions) in suggestionsPerColumn.sorted(by: { $0.0 < $1.0 }) {
                var prefix = suggestionLinePrefix

                for column in 0...columnNumber - 1 {
                    if columnsWithSuggestions.contains(column) {
                        prefix.append("|")
                    } else {
                        prefix.append(" ")
                    }
                }

                for (index, suggestion) in columnSuggestions.enumerated() {
                    // Highlight suggestion and make sure it's displayed on a single line.
                    let singleLineSuggestion = suggestion.split(separator: "\n", omittingEmptySubsequences: true).joined(separator: "")
                    let highlightedSuggestion = suggestionAnsiAnnotation.applied(to: "suggestion: \(singleLineSuggestion)")

                    if index == columnSuggestions.count - 1 {
                        result.append("\n\(prefix)╰─\(highlightedSuggestion)")
                    } else {
                        result.append("\n\(prefix)├─\(highlightedSuggestion)")
                    }
                }
            }
        }
        
        return result
    }

    private func highlightSource(
        sourceLine: String,
        lineNumber: Int,
        range: SourceRange
    ) -> String {
        guard lineNumber >= range.lowerBound.line &&
                lineNumber <= range.upperBound.line,
              !sourceLine.isEmpty
        else { return sourceLine }
        
        var startColumn: Int
        if lineNumber == range.lowerBound.line {
            startColumn = range.lowerBound.column
        } else {
            startColumn = 1
        }
        
        var endColumn: Int
        if lineNumber == range.upperBound.line {
            endColumn = range.upperBound.column
        } else {
            endColumn = sourceLine.count + 1
        }
        
        let columnRange = startColumn..<endColumn
        let startIndex = sourceLine.index(sourceLine.startIndex, offsetBy: columnRange.lowerBound - 1)
        let endIndex = sourceLine.index(startIndex, offsetBy: columnRange.count)
        
        let ansiAnnotation = ANSIAnnotation.sourceHighlight

        var result = ""
        result += sourceLine[sourceLine.startIndex..<startIndex]
        result += ansiAnnotation.applied(to: String(sourceLine[startIndex..<endIndex]))
        result += sourceLine[endIndex..<sourceLine.endIndex]
        
        return result
    }

    private func readSourceLines(_ url: URL) -> [String] {
        if let lines = sourceLines[url] {
            return lines
        }
        
        guard let content = try? String(contentsOf: url)
        else { return [] }
        
        let lines = content.splitByNewlines
        sourceLines[url] = lines
        return lines
    }

    private func formattedSourcePath(_ url: URL) -> String {
        baseUrl.flatMap { url.relative(to: $0) }.map(\.path) ?? url.path
    }
}

private extension DiagnosticSeverity {
    var ansiAnnotation: ANSIAnnotation {
        switch self {
        case .error:
            return .init(color: .red, trait: .bold)
        case .warning:
            return .init(color: .yellow, trait: .bold)
        case .information, .hint:
            return .normal
        }
    }
}
