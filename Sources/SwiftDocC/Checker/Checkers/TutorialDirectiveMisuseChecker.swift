/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

public struct TutorialDirectiveMisuseChecker: Checker {
    public var problems = [Problem]()

    private var sourceFile: URL?

    public init(sourceFile: URL?) {
        self.sourceFile = sourceFile
    }

    public mutating func visitBlockDirective(_ blockDirective: BlockDirective) {
        guard let blockRange = blockDirective.range else { return }
        
        let diagnostic: Diagnostic
        let solutions: [Solution]

        switch blockDirective.name {
        case ImageMedia.directiveName:
            diagnostic = Diagnostic(
                source: sourceFile,
                severity: .warning,
                range: blockRange,
                identifier: "org.swift.docc.TutorialDirectiveMisuse",
                summary: #"Directive 'Image' is not supported in on Articles."#,
                explanation: #""@\#(blockDirective.name)" directive is used only on Tutorials and will be ignored on Articles."#
            )
            
            let arguments = blockDirective.arguments()
            let source = arguments["source"]?.value ?? ""
            let altText = arguments["alt"]?.value ?? ""
            solutions = [
                Solution(
                    summary: "Use the Markdown image syntax instead.",
                    replacements: [Replacement(range: blockRange, replacement: "![\(altText)](\(source))")]
                ),
            ]
        default:
            diagnostic = Diagnostic(
                source: sourceFile,
                severity: .warning,
                range: blockRange,
                identifier: "org.swift.docc.TutorialDirectiveMisuse",
                summary: #""@\#(blockDirective.name)" directive is not support on normal markdown file."#,
                explanation: #""@\#(blockDirective.name)" directive is used only on Tutorials and will be ignored on Articles."#
            )
            solutions = []
        }
        problems.append(Problem(diagnostic: diagnostic, possibleSolutions: solutions))
    }
}
