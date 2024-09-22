/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
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

    /// Creates a new instance of this class with the provided output stream.
    /// - Parameters:
    ///   - stream: The output stream to which this instance will write.
    ///   - options: The formatting options for the diagnostics.
    ///   - baseURL: A url to be used as a base url when formatting diagnostic source path.
    ///   - highlight: Whether or not to highlight the default diagnostic formatting output.
    public convenience init(
        _ stream: TextOutputStream = LogHandle.standardError,
        formattingOptions options: DiagnosticFormattingOptions = [],
        baseURL: URL? = nil,
        highlight: Bool? = nil
    ) {
        self.init(stream, formattingOptions: options, baseURL: baseURL, highlight: highlight, fileManager: FileManager.default)
    }
    
    package init(
        _ stream: TextOutputStream = LogHandle.standardError,
        formattingOptions options: DiagnosticFormattingOptions = [],
        baseURL: URL? = nil,
        highlight: Bool? = nil,
        fileManager: FileManagerProtocol = FileManager.default
    ) {
        outputStream = stream
        formattingOptions = options
        diagnosticFormatter = Self.makeDiagnosticFormatter(
            options,
            baseURL: baseURL,
            highlight: highlight ?? TerminalHelper.isConnectedToTerminal,
            fileManager: fileManager
        )
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
    
    public func flush() throws {
        if formattingOptions.contains(.formatConsoleOutputForTools) {
            // For tools, the console writer writes each diagnostic as they are received.
        } else {
            let text = self.diagnosticFormatter.formattedDescription(for: problems)
            outputStream.write(text)
            outputStream.write("\n")
        }
        problems = [] // `flush()` is called more than once. Don't emit the same problems again.
        self.diagnosticFormatter.finalize()
    }
    
    // This is deprecated but still necessary to implement.
    @available(*, deprecated, renamed: "flush()", message: "Use 'flush()' instead. This deprecated API will be removed after 6.0 is released")
    public func finalize() throws {
        try flush()
    }
    
    private static func makeDiagnosticFormatter(
        _ options: DiagnosticFormattingOptions,
        baseURL: URL?,
        highlight: Bool,
        fileManager: FileManagerProtocol
    ) -> DiagnosticConsoleFormatter {
        if options.contains(.formatConsoleOutputForTools) {
            return IDEDiagnosticConsoleFormatter(options: options)
        } else {
            return DefaultDiagnosticConsoleFormatter(baseUrl: baseURL, highlight: highlight, options: options, fileManager: fileManager)
        }
    }
}

// MARK: Formatted descriptions

extension DiagnosticConsoleWriter {
    public static func formattedDescription(for problems: some Sequence<Problem>, options: DiagnosticFormattingOptions = []) -> String {
        formattedDescription(for: problems, options: options, fileManager: FileManager.default)
    }
    package static func formattedDescription(for problems: some Sequence<Problem>, options: DiagnosticFormattingOptions = [], fileManager: FileManagerProtocol) -> String {
        return problems.map { formattedDescription(for: $0, options: options, fileManager: fileManager) }.joined(separator: "\n")
    }
    
    public static func formattedDescription(for problem: Problem, options: DiagnosticFormattingOptions = []) -> String {
        formattedDescription(for: problem, options: options, fileManager: FileManager.default)
    }
    package static func formattedDescription(for problem: Problem, options: DiagnosticFormattingOptions = [], fileManager: FileManagerProtocol = FileManager.default) -> String {
        let diagnosticFormatter = makeDiagnosticFormatter(options, baseURL: nil, highlight: TerminalHelper.isConnectedToTerminal, fileManager: fileManager)
        return diagnosticFormatter.formattedDescription(for: problem)
    }
    
    public static func formattedDescription(for diagnostic: Diagnostic, options: DiagnosticFormattingOptions = []) -> String {
        formattedDescription(for: diagnostic, options: options, fileManager: FileManager.default)
    }
    package static func formattedDescription(for diagnostic: Diagnostic, options: DiagnosticFormattingOptions = [], fileManager: FileManagerProtocol) -> String {
        let diagnosticFormatter = makeDiagnosticFormatter(options, baseURL: nil, highlight: TerminalHelper.isConnectedToTerminal, fileManager: fileManager)
        return diagnosticFormatter.formattedDescription(for: diagnostic)
    }
}

protocol DiagnosticConsoleFormatter {
    var options: DiagnosticFormattingOptions { get set }
    
    func formattedDescription(for problems: some Sequence<Problem>) -> String
    func formattedDescription(for problem: Problem) -> String
    func formattedDescription(for diagnostic: Diagnostic) -> String
    func finalize()
}

extension DiagnosticConsoleFormatter {
    func formattedDescription(for problems: some Sequence<Problem>) -> String {
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

    func finalize() {
        // Nothing to do after all diagnostics have been formatted.
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
    private let highlight: Bool
    private var sourceLines: [URL: [String]] = [:]
    private var fileManager: FileManagerProtocol

    /// The number of additional lines from the source file that should be displayed both before and after the diagnostic source line.
    private static let contextSize = 2
    
    init(
        baseUrl: URL?,
        highlight: Bool,
        options: DiagnosticFormattingOptions,
        fileManager: FileManagerProtocol
    ) {
        self.baseUrl = baseUrl
        self.highlight = highlight
        self.options = options
        self.fileManager = fileManager
    }
    
    func formattedDescription(for problems: some Sequence<Problem>) -> String {
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
        formattedDescription(for: Problem(diagnostic: diagnostic))
    }

    func finalize() {
        // Since the `sourceLines` could potentially be big if there were diagnostics in many large files,
        // we remove the cached lines in a clean up step after all diagnostics have been formatted.
        sourceLines = [:]
    }
}

extension DefaultDiagnosticConsoleFormatter {
    private func formattedDiagnosticsSummary(for diagnostic: Diagnostic) -> String {
        let summary =  diagnostic.severity.description + ": " + diagnostic.summary
        if highlight {
            let ansiAnnotation = diagnostic.severity.ansiAnnotation
            return ansiAnnotation.applied(to: summary)
        } else {
            return summary
        }
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
        else {
            // If the replacement operation involves adding new files,
            // emit the file content as an addition instead of a replacement.
            //
            // Example:
            // --> /path/to/new/file.md
            // Summary
            // suggestion:
            // 0 + Addition file and
            // 1 + multiline file content.
            var addition = ""
            solutions.forEach { solution in
                addition.append("\n" + solution.summary)
                solution.replacements.forEach { replacement in
                    let solutionFragments = replacement.replacement.split(separator: "\n")
                    addition += "\nsuggestion:\n" + solutionFragments.enumerated().map {
                        "\($0.offset) + \($0.element)"
                    }.joined(separator: "\n")
                }
            }
            return "\n--> \(formattedSourcePath(url))\(addition)"
        }
        
        let sourceLines = readSourceLines(url)

        guard sourceLines.indices.contains(diagnosticRange.lowerBound.line - 1), sourceLines.indices.contains(diagnosticRange.upperBound.line - 1) else {
            return "\n--> \(formattedSourcePath(url)):\(max(1, diagnosticRange.lowerBound.line)):\(max(1, diagnosticRange.lowerBound.column))-\(max(1, diagnosticRange.upperBound.line)):\(max(1, diagnosticRange.upperBound.column))"
        }
        
        // A range containing the source lines and some surrounding context.
        let sourceLinesToDisplay = Range(
            uncheckedBounds: (
                lower: diagnosticRange.lowerBound.line - Self.contextSize - 1,
                upper: diagnosticRange.upperBound.line + Self.contextSize
            )
        ).clamped(to: sourceLines.indices)
        let maxLinePrefixWidth = String(sourceLinesToDisplay.upperBound).count
        
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

        // Constructs the header for the diagnostic output.
        // This header is aligned with the line prefix and includes the file path and the range of the diagnostic.\
        //
        // Example:
        //   --> /path/to/file.md:1:10-2:20
        result.append("\n\(String(repeating: " ", count: maxLinePrefixWidth))--> ")
        result.append(        "\(formattedSourcePath(url)):\(max(1, diagnosticRange.lowerBound.line)):\(max(1, diagnosticRange.lowerBound.column))-\(max(1, diagnosticRange.upperBound.line)):\(max(1, diagnosticRange.upperBound.column))")

        for (sourceLineIndex, sourceLine) in sourceLines[sourceLinesToDisplay].enumerated() {
            let lineNumber = sourceLineIndex + sourceLinesToDisplay.lowerBound + 1
            let linePrefix = "\(lineNumber)".padding(toLength: maxLinePrefixWidth, withPad: " ", startingAt: 0)

            let highlightedSource = highlightSource(
                sourceLine: sourceLine,
                lineNumber: lineNumber,
                range: diagnosticRange, 
                _diagnostic: diagnostic
            )
            
            let separator: String
            if lineNumber >= diagnosticRange.lowerBound.line && lineNumber <= diagnosticRange.upperBound.line {
                separator = "+"
            } else {
                separator = "|"
            }

            // Adds to the header, a formatted source line containing the line number as prefix and a source line.
            // A source line is contained in the diagnostic range will be highlighted.
            //
            // Example:
            // 9  | A line outside the diagnostic range.
            // 10 + A line inside the diagnostic range.
            result.append("\n\(linePrefix) \(separator) \(highlightedSource)".removingTrailingWhitespace())

            var suggestionsPerColumn = [Int: [String]]()

            for (location, suggestions) in suggestionsPerLocation where location.line == lineNumber {
                suggestionsPerColumn[location.column] = suggestions
            }

            let sortedColumns = suggestionsPerColumn.keys.sorted(by: >)

            guard let firstColumn = sortedColumns.first else { continue }

            let suggestionLinePrefix = String(repeating: " ", count: maxLinePrefixWidth) + " |"

            // Constructs a prefix containing vertical separator at each column containing a suggestion.
            // Suggestions are shown on different lines, this allows to visually connect a suggestion shown several lines below
            // with the source code column.
            //
            // Example:
            // 9  | A line outside the diagnostic range.
            // 10 + A line inside the diagnostic range.
            //    |   │    ╰─suggestion: A suggestion.
            //    |   ╰─ suggestion: Another suggestion.
            var longestPrefix = [Character](repeating: " ", count: firstColumn + 1)
            for column in sortedColumns {
                longestPrefix[column] = "│"
            }

            for columnNumber in sortedColumns {
                let columnSuggestions = suggestionsPerColumn[columnNumber, default: []]
                let prefix = suggestionLinePrefix + String(longestPrefix.prefix(columnNumber))

                for (index, suggestion) in columnSuggestions.enumerated() {
                    // Highlight suggestion and make sure it's displayed on a single line.
                    let singleLineSuggestion = suggestion.split(separator: "\n", omittingEmptySubsequences: true).joined(separator: "")
                    let highlightedSuggestion = highlightSuggestion("suggestion: \(singleLineSuggestion)")

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
    
    private func highlightSuggestion(
        _ suggestion: String
    ) -> String {
        guard highlight
        else { return suggestion }
        
        let suggestionAnsiAnnotation = ANSIAnnotation.sourceSuggestionHighlight
        return suggestionAnsiAnnotation.applied(to: suggestion)
    }

    private func highlightSource(
        sourceLine: String,
        lineNumber: Int,
        range: SourceRange,
        _diagnostic: Diagnostic // used in a debug assertion to identify diagnostics with incorrect source ranges
    ) -> String {
        guard highlight,
              lineNumber >= range.lowerBound.line && lineNumber <= range.upperBound.line,
              !sourceLine.isEmpty
        else {
            return sourceLine
        }
        
        guard range.lowerBound.line == range.upperBound.line else {
            // When highlighting multiple lines, highlight the full line
            return ANSIAnnotation.sourceHighlight.applied(to: sourceLine)
        }

        let sourceLineUTF8 = sourceLine.utf8
        
        let highlightStart = max(0, range.lowerBound.column - 1)
        let highlightEnd = range.upperBound.column - 1
        
        assert(highlightStart <= sourceLineUTF8.count, {
            """
            Received diagnostic with incorrect source range; (\(range.lowerBound.column) ..< \(range.upperBound.column)) extends beyond the text on line \(lineNumber) (\(sourceLineUTF8.count) characters)
             █\(sourceLine)
             █\(String(repeating: " ", count: range.lowerBound.column))\(String(repeating: "~", count: range.upperBound.column - range.lowerBound.column))
            Use this diagnostic information to reproduce the issue and correct the diagnostic range where it's emitted.
             ID      : \(_diagnostic.identifier)
             SUMMARY : \(_diagnostic.summary)
             SOURCE  : \(_diagnostic.source?.path ?? _diagnostic.range?.source?.path ?? "<nil>")
            """
        }())
        
        guard let before = String(sourceLineUTF8.prefix(highlightStart)),
              let highlighted = String(sourceLineUTF8.dropFirst(highlightStart).prefix(highlightEnd - highlightStart)),
              let after = String(sourceLineUTF8.dropFirst(highlightEnd))
        else {
            return sourceLine
        }
        
        return "\(before)\(ANSIAnnotation.sourceHighlight.applied(to: highlighted))\(after)"
    }

    private func readSourceLines(_ url: URL) -> [String] {
        if let lines = sourceLines[url] {
            return lines
        }

        // TODO: Add support for also getting the source lines from the symbol graph files.
        guard let data = fileManager.contents(atPath: url.path),
              let content = String(data: data, encoding: .utf8)
        else { 
            return []
        }
        
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
            return .init(color: .default, trait: .bold)
        }
    }
}
