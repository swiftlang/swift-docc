/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Writes diagnostic messages to a text output stream.
///
/// By default, this type writes to `stderr`.
public final class DiagnosticConsoleWriter: DiagnosticFormattingConsumer {

    var outputStream: TextOutputStream
    public var formattingOptions: DiagnosticFormattingOptions

    /// Creates a new instance of this class with the provided output stream and filter level.
    /// - Parameter stream: The output stream to which this instance will write.
    /// - Parameter filterLevel: Determines what diagnostics should be printed. This filter level is inclusive, i.e. if a level of ``DiagnosticSeverity/information`` is specified, diagnostics with a severity up to and including `.information` will be printed.
    @available(*, deprecated, message: "Use init(_:formattingOptions:) instead")
    public init(_ stream: TextOutputStream = LogHandle.standardError, filterLevel: DiagnosticSeverity = .warning) {
        outputStream = stream
        formattingOptions = []
    }

    /// Creates a new instance of this class with the provided output stream.
    /// - Parameter stream: The output stream to which this instance will write.
    public init(_ stream: TextOutputStream = LogHandle.standardError, formattingOptions options: DiagnosticFormattingOptions = []) {
        outputStream = stream
        formattingOptions = options
    }

    public func receive(_ problems: [Problem]) {
        let text = Self.formattedDescriptionFor(problems, options: formattingOptions).appending("\n")
        outputStream.write(text)
    }
}

// MARK: Formatted descriptions

extension DiagnosticConsoleWriter {
    
    public static func formattedDescriptionFor<Problems>(_ problems: Problems, options: DiagnosticFormattingOptions = []) -> String where Problems: Sequence, Problems.Element == Problem {
        return problems.map { formattedDescriptionFor($0, options: options) }.joined(separator: "\n")
    }
    
    public static func formattedDescriptionFor(_ problem: Problem, options: DiagnosticFormattingOptions = []) -> String {
        guard let source = problem.diagnostic.source, options.contains(.showFixits) else {
            return formattedDescriptionFor(problem.diagnostic)
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
    
    public static func formattedDescriptionFor(_ diagnostic: Diagnostic, options: DiagnosticFormattingOptions = []) -> String {
        return formattedDiagnosticSummary(diagnostic) + formattedDiagnosticDetails(diagnostic)
    }
    
    private static func formattedDiagnosticSummary(_ diagnostic: Diagnostic) -> String {
        var result = ""

        if let range = diagnostic.range, let url = diagnostic.source {
            result += "\(url.path):\(range.lowerBound.line):\(range.lowerBound.column): "
        } else if let url = diagnostic.source {
            result += "\(url.path): "
        }
        
        result += "\(diagnostic.severity): \(diagnostic.localizedSummary)"
        
        return result
    }
    
    private static func formattedDiagnosticDetails(_ diagnostic: Diagnostic) -> String {
        var result = ""

        if let explanation = diagnostic.localizedExplanation {
            result += "\n\(explanation)"
        }

        if !diagnostic.notes.isEmpty {
            result += "\n"
            result += diagnostic.notes.map { formattedDescriptionFor($0) }.joined(separator: "\n")
        }
        
        return result
    }
    
    private static func formattedDescriptionFor(_ note: DiagnosticNote, options: DiagnosticFormattingOptions = []) -> String {
        let location = "\(note.source.path):\(note.range.lowerBound.line):\(note.range.lowerBound.column)"
        return "\(location): note: \(note.message)"
    }
}
