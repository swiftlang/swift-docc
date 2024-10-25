/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

protocol DirectiveArgument<ArgumentValue> {
    associatedtype ArgumentValue: DirectiveArgumentValueConvertible = String
    /// The expected `BlockDirective` argument's name.
    static var argumentName: String { get }
    
    /// If non-`nil`, the list of allowed values the argument can take on,
    /// suggested to the author as possible solutions
    static func allowedValues() -> [String]?
    
    /// If non-`nil`, a string describing the expected format for the argument value,
    /// shown to the author as part of the diagnostic summary when an invalid value is provided.
    static func expectedFormat() -> String?
}

extension DirectiveArgument {
    static func allowedValues() -> [String]? {
        return nil
    }
    static func expectedFormat() -> String? {
        return nil
    }
    static func convert(_ argument: String) -> ArgumentValue? {
        return ArgumentValue(rawDirectiveArgumentValue: argument)
    }
}

extension DirectiveArgument<Bool> {
    static func allowedValues() -> [String]? {
        return ["true", "false"]
    }
}

extension Semantic.Analyses {
    /**
     Checks to see if a directive has an argument with a particular name and can
     be converted to a specified ``DirectiveArgument`` type.
     */
    struct HasArgument<Parent: Semantic & DirectiveConvertible, Converter: DirectiveArgument> {
        let severityIfNotFound: DiagnosticSeverity?
        public init(severityIfNotFound: DiagnosticSeverity?) {
            self.severityIfNotFound = severityIfNotFound
        }
        
        func analyze(_ directive: BlockDirective, arguments: [String: Markdown.DirectiveArgument], problems: inout [Problem]) -> Converter.ArgumentValue? {
            return ArgumentValueParser<Parent>.init(
                severityIfNotFound: severityIfNotFound,
                argumentName: Converter.argumentName,
                allowedValues: Converter.allowedValues(),
                expectedFormat: Converter.expectedFormat(),
                convert: Converter.convert(_:),
                valueTypeDiagnosticName: String(describing: Converter.ArgumentValue.self)
            ).analyze(directive, arguments: arguments, problems: &problems) as? Converter.ArgumentValue
        }
    }
    
    struct ArgumentValueParser<Parent: Semantic & DirectiveConvertible> {
        let severityIfNotFound: DiagnosticSeverity?
        let argumentName: String
        let allowedValues: [String]?
        let expectedFormat: String?
        let convert: (String) -> (Any?)
        let valueTypeDiagnosticName: String
        
        func analyze(
            _ directive: BlockDirective,
            arguments: [String: Markdown.DirectiveArgument],
            problems: inout [Problem]
        ) -> Any? {
            let arguments = directive.arguments(problems: &problems)
            let source = directive.range?.lowerBound.source
            let diagnosticArgumentName = argumentName.isEmpty ? "unlabeled" : argumentName
            let diagnosticArgumentDescription = if argumentName.isEmpty {
                "an unnamed parameter"
            } else {
                "the \(argumentName.singleQuoted) parameter"
            }
            let diagnosticExplanation = if let expectedFormat {
                """
                \(Parent.directiveName) expects an argument for \(diagnosticArgumentDescription) \
                that's convertible to \(expectedFormat)
                """
            } else {
                """
                \(Parent.directiveName) expects an argument for \(diagnosticArgumentDescription) \
                that's convertible to \(valueTypeDiagnosticName.singleQuoted)
                """
            }
            guard let argument = arguments[argumentName] else {
                if let severity = severityIfNotFound {
                    let diagnostic = Diagnostic(
                        source: source,
                        severity: severity,
                        range: directive.range,
                        identifier: "org.swift.docc.HasArgument.\(diagnosticArgumentName)",
                        summary: "Missing argument for \(diagnosticArgumentName) parameter",
                        explanation: diagnosticExplanation
                    )
                    problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
                }
                return nil
            }
            guard let value = convert(argument.value) else {
                let diagnostic = Diagnostic(
                    source: source,
                    severity: .warning,
                    range: argument.valueRange,
                    identifier: "org.swift.docc.HasArgument.\(diagnosticArgumentName).ConversionFailed",
                    summary: "Cannot convert \(argument.value.singleQuoted) to type \(valueTypeDiagnosticName.singleQuoted)",
                    explanation: diagnosticExplanation
                )
                let solutions = allowedValues.map { allowedValues -> [Solution] in
                    return allowedValues.compactMap { allowedValue -> Solution? in
                        guard let range = argument.valueRange else {
                            return nil
                        }
                        return Solution(summary: "Use allowed value \(allowedValue.singleQuoted)", replacements: [Replacement(range: range, replacement: allowedValue)])
                    }
                }
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: solutions ?? []))
                return nil
            }
            return value
        }
    }
}

