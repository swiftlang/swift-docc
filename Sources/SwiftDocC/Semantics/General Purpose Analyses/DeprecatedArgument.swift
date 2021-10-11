/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

extension Semantic.Analyses {
    struct DeprecatedArgument<Parent: Semantic & DirectiveConvertible, Converter: DirectiveArgument> {
        let severityIfFound: DiagnosticSeverity?
        let message: String?

        init(severityIfFound: DiagnosticSeverity?, message: String?) {
            self.severityIfFound = severityIfFound
            self.message = message
        }

        static func unused(severityIfFound: DiagnosticSeverity?) -> Self {
            return self.init(severityIfFound: severityIfFound, message: "This parameter is not used.")
        }

        @discardableResult func analyze(_ directive: BlockDirective, arguments: [String: Markdown.DirectiveArgument], problems: inout [Problem]) -> Converter.ArgumentValue? {
            let arguments = directive.arguments(problems: &problems)
            let source = directive.range?.lowerBound.source

            guard let argument = arguments[Converter.argumentName] else { return nil }

            // If we got here, the argument exists, so warn about it
            if let severity = severityIfFound {
                var extraMessage = ""
                if let message = message {
                    extraMessage = ": " + message
                }
                let diagnostic = Diagnostic(source: source, severity: severity, range: directive.range, identifier: "org.swift.docc.DeprecatedArgument.\(Converter.argumentName)", summary: "\(Converter.argumentName.singleQuoted) is deprecated" + extraMessage)
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
            }
            guard let value = Converter.convert(argument.value) else {
                let diagnostic = Diagnostic(source: source, severity: .warning, range: argument.valueRange, identifier: "org.swift.docc.DeprecatedArgument.\(Converter.argumentName).ConversionFailed", summary: "Can't convert \(argument.value.singleQuoted) to type \(Converter.ArgumentValue.self)")
                let solutions = Converter.allowedValues().map { allowedValues -> [Solution] in
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
